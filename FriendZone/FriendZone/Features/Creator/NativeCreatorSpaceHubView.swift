import SwiftUI

struct NativeCreatorSpaceHubView: View {
    let userFlags: SettingsUserRoleFlags
    var onClose: (() -> Void)? = nil

    @EnvironmentObject private var session: AppSessionStore
    @State private var activeTab: CreatorSpaceTab = .profile
    @State private var showCreateSheet = false
    @State private var profileDraft = CreatorProfileDraft(
        displayName: "",
        bio: "",
        instagram: "",
        website: "",
        city: ""
    )
    @State private var events: [CreatorEventItem] = []
    @State private var venues: [CreatorVenueItem] = []
    @State private var offers: [CreatorOfferItem] = []
    @State private var selectedEventDashboardItem: CreatorEventItem?
    @State private var selectedOfferDashboardItem: CreatorOfferItem?
    @State private var isSavingProfile = false
    @State private var didSaveProfile = false
    @State private var saveErrorMessage: String?
    @State private var isShowingPublicProfile = false
    @State private var isLoadingDashboard = false
    @State private var dashboardErrorMessage: String?

    private var availableTabs: [CreatorSpaceTab] {
        var tabs: [CreatorSpaceTab] = [.profile]
        if userFlags.isEventCreator {
            tabs.append(.events)
        }
        if userFlags.isVenueOwner {
            tabs.append(.venues)
            tabs.append(.offers)
        }
        return tabs
    }

    private var rolePills: [RolePill] {
        var pills: [RolePill] = []
        if userFlags.isEventCreator {
            pills.append(RolePill(title: "Event Creator", emoji: "🎉", tint: FriendZoneTheme.Colors.primary))
        }
        if userFlags.isVenueOwner {
            pills.append(RolePill(title: "Venue Owner", emoji: "🏢", tint: Color(hex: "#2563EB")))
        }
        return pills
    }

    private var canCreateOnCurrentTab: Bool {
        activeTab == .events || activeTab == .venues || activeTab == .offers
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    FriendZoneModuleHeader(
                        leadingText: "Creator ",
                        highlightText: "Space",
                        subtitle: "Manage your creator dashboard"
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if !rolePills.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(rolePills) { pill in
                                    HStack(spacing: 6) {
                                        Text(pill.emoji)
                                            .font(.system(size: 12))
                                        Text(pill.title)
                                            .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                                    }
                                    .foregroundColor(pill.tint)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(pill.tint.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }

                    publicProfileButton
                        .padding(.top, 10)

                    tabBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    tabContent
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 120)

                    if let dashboardErrorMessage {
                        Text(dashboardErrorMessage)
                            .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.error)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .background(FriendZoneTheme.Colors.background)

            if canCreateOnCurrentTab {
                Button {
                    showCreateSheet = true
                    FriendZoneHaptics.selection()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#0F172A"), Color(hex: "#1F2937")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.24), radius: 16, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 24)
                .padding(.bottom, 26)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onClose()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            creationSheet
        }
        .sheet(item: $selectedEventDashboardItem) { event in
            NavigationStack {
                CreatorEventDashboardView(event: event) { updated in
                    if let index = events.firstIndex(where: { $0.id == updated.id }) {
                        events[index] = updated
                    }
                    selectedEventDashboardItem = updated
                }
            }
        }
        .sheet(item: $selectedOfferDashboardItem) { offer in
            NavigationStack {
                CreatorOfferDashboardView(offer: offer) { updated in
                    if let index = offers.firstIndex(where: { $0.id == updated.id }) {
                        offers[index] = updated
                    }
                    selectedOfferDashboardItem = updated
                }
            }
        }
        .onAppear {
            if !availableTabs.contains(activeTab), let first = availableTabs.first {
                activeTab = first
            }
            hydrateProfileDraftIfNeeded()
            Task { await loadCreatorDashboardIfNeeded() }
        }
        .sheet(isPresented: $isShowingPublicProfile) {
            NavigationStack {
                PublicProfileView(
                    profile: publicProfileData,
                    leadingText: "Public ",
                    highlightText: "profile",
                    subtitle: nil
                ) {
                    isShowingPublicProfile = false
                }
            }
            .background(FriendZoneTheme.Colors.background)
        }
    }

    private var publicProfileButton: some View {
        HStack {
            Spacer()
            Button {
                isShowingPublicProfile = true
                FriendZoneHaptics.selection()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("View public profile")
                        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                }
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(availableTabs) { tab in
                let isActive = activeTab == tab
                Button {
                    activeTab = tab
                    FriendZoneHaptics.selection()
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.emoji)
                            .font(.system(size: 14))
                        Text(tab.title)
                            .font(FriendZoneTheme.Typography.system(13, weight: isActive ? .bold : .semibold))
                    }
                    .foregroundColor(isActive ? Color(hex: "#0E7490") : FriendZoneTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        isActive
                            ? Color(hex: "#0E7490").opacity(0.12)
                            : Color.white.opacity(0.78)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .profile:
            profileTab
        case .events:
            eventsTab
        case .venues:
            venuesTab
        case .offers:
            offersTab
        }
    }

    private var profileTab: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(hex: "#0F172A"), Color(hex: "#0E7490")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 110)
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Text(profileInitial)
                                    .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                                    .foregroundColor(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profileDraft.displayName.isEmpty ? "Creator" : profileDraft.displayName)
                                .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(profileDraft.city.isEmpty ? "City not set" : profileDraft.city)
                                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }

                HStack(spacing: 4) {
                    profileStatCard(number: "\(events.count)", label: "Events")
                    profileStatCard(number: "\(venues.count)", label: "Venues")
                    profileStatCard(number: "\(offers.count)", label: "Offers")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(FriendZoneTheme.Colors.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Edit Brand Profile")
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                creatorTextField("Display Name", text: $profileDraft.displayName)
                creatorTextField("City", text: $profileDraft.city)
                creatorTextField("Instagram", text: $profileDraft.instagram, prefix: "@")
                creatorTextField("Website", text: $profileDraft.website)
                creatorTextEditor("Bio", text: $profileDraft.bio)

                if didSaveProfile {
                    Text("Changes saved")
                        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(FriendZoneTheme.Colors.success.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(FriendZoneTheme.Colors.error.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button {
                    saveProfile()
                } label: {
                    Text(isSavingProfile ? "Saving..." : "Save Changes")
                        .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(hex: "#0F172A"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSavingProfile)
                .opacity(isSavingProfile ? 0.7 : 1)
            }
            .padding(14)
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
            }
        }
    }

    private var eventsTab: some View {
        Group {
            if isLoadingDashboard && events.isEmpty {
                dashboardLoadingState("Loading events…")
            } else if events.isEmpty {
                emptyState(
                    emoji: "🎉",
                    title: "No events yet",
                    description: "Create your first event and start building your community."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(events) { event in
                        Button {
                            selectedEventDashboardItem = event
                            FriendZoneHaptics.selection()
                        } label: {
                            CreatorEventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var venuesTab: some View {
        Group {
            if isLoadingDashboard && venues.isEmpty {
                dashboardLoadingState("Loading venues…")
            } else if venues.isEmpty {
                emptyState(
                    emoji: "🏢",
                    title: "No venues yet",
                    description: "Register your venue to start creating hangout offers."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(venues) { venue in
                        CreatorVenueCard(venue: venue)
                    }
                }
            }
        }
    }

    private var offersTab: some View {
        Group {
            if isLoadingDashboard && offers.isEmpty {
                dashboardLoadingState("Loading offers…")
            } else if offers.isEmpty {
                emptyState(
                    emoji: "🎁",
                    title: "No offers yet",
                    description: "Create an offer to attract people to your venue."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(offers) { offer in
                        Button {
                            selectedOfferDashboardItem = offer
                            FriendZoneHaptics.selection()
                        } label: {
                            CreatorOfferCard(offer: offer)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var creationSheet: some View {
        switch activeTab {
        case .events:
            CreatorCreateEventSheet { item in
                events.insert(item, at: 0)
            }
        case .venues:
            CreatorCreateVenueSheet { item in
                venues.insert(item, at: 0)
            }
        case .offers:
            CreatorCreateOfferSheet(venues: venues) { item in
                offers.insert(item, at: 0)
            }
        case .profile:
            EmptyView()
        }
    }

    private func profileStatCard(number: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(number)
                .font(FriendZoneTheme.Typography.system(20, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
            Text(label.uppercased())
                .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func creatorTextField(_ title: String, text: Binding<String>, prefix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            HStack(spacing: 0) {
                if let prefix {
                    Text(prefix)
                        .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .padding(.leading, 10)
                }

                TextField(title, text: text)
                    .font(FriendZoneTheme.Typography.system(14, weight: .medium))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 10)
                    .frame(height: 42)
            }
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func creatorTextEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            TextEditor(text: text)
                .font(FriendZoneTheme.Typography.system(14, weight: .medium))
                .frame(minHeight: 92)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func emptyState(emoji: String, title: String, description: String) -> some View {
        VStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 46))
            Text(title)
                .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(description)
                .font(FriendZoneTheme.Typography.system(14, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
    }

    private func dashboardLoadingState(_ label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(label)
                .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
    }

    private var profileInitial: String {
        let trimmed = profileDraft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? Character("C")).uppercased()
    }

    private func saveProfile() {
        isSavingProfile = true
        didSaveProfile = false
        saveErrorMessage = nil
        let submission = ProfileUpdateSubmission(
            displayName: profileDraft.displayName,
            city: profileDraft.city,
            bio: profileDraft.bio,
            instagramUsername: profileDraft.instagram
        )
        Task {
            do {
                try await session.updateProfile(submission)
                await MainActor.run {
                    isSavingProfile = false
                    didSaveProfile = true
                    hydrateProfileDraftIfNeeded(force: true)
                }
            } catch {
                await MainActor.run {
                    isSavingProfile = false
                    saveErrorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func loadCreatorDashboardIfNeeded() async {
        guard !isLoadingDashboard else { return }
        isLoadingDashboard = true
        defer { isLoadingDashboard = false }

        dashboardErrorMessage = nil

        async let eventsLoad: Void = loadCreatorEvents()
        async let venuesLoad: Void = loadCreatorVenues()
        async let offersLoad: Void = loadCreatorOffers()
        _ = await (eventsLoad, venuesLoad, offersLoad)
    }

    @MainActor
    private func loadCreatorEvents() async {
        guard userFlags.isEventCreator else { return }
        do {
            let feed = try await session.fetchMyCreatorEvents()
            events = feed.compactMap(mapCreatorEvent)
        } catch {
            dashboardErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadCreatorVenues() async {
        guard userFlags.isVenueOwner else { return }
        do {
            let feed = try await session.fetchMyCreatorVenues()
            venues = feed.map(mapCreatorVenue)
        } catch {
            dashboardErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadCreatorOffers() async {
        guard userFlags.isVenueOwner else { return }
        do {
            let feed = try await session.fetchMyCreatorOffers()
            offers = feed.compactMap(mapCreatorOffer)
        } catch {
            dashboardErrorMessage = error.localizedDescription
        }
    }

    private func mapCreatorEvent(_ item: CreatorEventFeedItem) -> CreatorEventItem? {
        guard let startAt = parseServerDate(item.startAt) else { return nil }
        return CreatorEventItem(
            id: item.id,
            title: item.title,
            category: item.category ?? "event",
            status: mapCreatorEventStatus(item.status),
            venueName: item.venueName ?? "Venue",
            startAt: startAt,
            endAt: parseServerDate(item.endAt ?? item.startAt) ?? startAt.addingTimeInterval(2 * 60 * 60),
            capacity: item.capacity ?? 0,
            groupsCount: item.hangoutsCount ?? 0
        )
    }

    private func mapCreatorVenue(_ item: CreatorVenueFeedItem) -> CreatorVenueItem {
        CreatorVenueItem(
            id: item.id,
            name: item.name,
            category: item.category,
            status: mapCreatorVenueStatus(item.status),
            city: item.city,
            address: item.address,
            totalHangouts: item.totalHangouts ?? 0,
            totalOffers: item.totalOffers ?? 0,
            totalPeopleReached: item.totalPeopleReached ?? 0,
            isVerified: item.isVerified ?? false
        )
    }

    private func mapCreatorOffer(_ item: CreatorOfferFeedItem) -> CreatorOfferItem? {
        guard let validUntil = parseServerDate(item.validUntil) else { return nil }
        return CreatorOfferItem(
            id: item.id,
            title: item.title,
            perk: item.perk,
            status: mapCreatorOfferStatus(item.status),
            venueName: item.venueName ?? "Venue",
            validUntil: validUntil,
            recurrence: item.recurrenceDisplay ?? "none",
            claimsUsed: item.claimsUsed ?? 0,
            capacity: item.capacity
        )
    }

    private func mapCreatorEventStatus(_ raw: String) -> CreatorEventStatus {
        switch raw.lowercased() {
        case "live":
            return .live
        case "ended":
            return .ended
        case "cancelled":
            return .cancelled
        default:
            return .upcoming
        }
    }

    private func mapCreatorVenueStatus(_ raw: String) -> CreatorVenueStatus {
        switch raw.lowercased() {
        case "active":
            return .active
        case "pending":
            return .pendingVerification
        default:
            return .inactive
        }
    }

    private func mapCreatorOfferStatus(_ raw: String) -> CreatorOfferStatus {
        switch raw.lowercased() {
        case "active":
            return .active
        case "paused":
            return .paused
        case "draft":
            return .draft
        default:
            return .expired
        }
    }

    private func parseServerDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    private func hydrateProfileDraftIfNeeded(force: Bool = false) {
        guard force || profileDraft.displayName.isEmpty else { return }
        let user = session.currentUser
        let profile = session.currentProfile
        let displayNameParts = [user?.firstName, user?.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = displayNameParts.isEmpty ? (user?.username ?? profileDraft.displayName) : displayNameParts.joined(separator: " ")

        profileDraft = CreatorProfileDraft(
            displayName: displayName,
            bio: profile?.bio ?? "",
            instagram: profile?.instagramUsername ?? "",
            website: profileDraft.website,
            city: profile?.cityName ?? ""
        )
    }

    private var publicProfileData: PublicProfileData {
        let base = PublicProfileData(draft: profileDraft)
        return PublicProfileData(
            id: base.id,
            userID: session.currentUser?.id,
            displayName: profileDraft.displayName,
            username: session.currentUser?.username,
            bio: profileDraft.bio,
            instagram: profileDraft.instagram,
            website: profileDraft.website,
            city: profileDraft.city,
            avatarURL: session.currentProfile?.avatarImageUrl,
            followersCount: session.currentProfile?.followersCount,
            hostRating: session.currentProfile?.hostRating
        )
    }
}

private enum CreatorSpaceTab: String, Identifiable {
    case profile
    case events
    case venues
    case offers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Profile"
        case .events: return "Events"
        case .venues: return "Venues"
        case .offers: return "Offers"
        }
    }

    var emoji: String {
        switch self {
        case .profile: return "👤"
        case .events: return "🎉"
        case .venues: return "🏢"
        case .offers: return "🎁"
        }
    }
}

private struct RolePill: Identifiable {
    let id = UUID()
    let title: String
    let emoji: String
    let tint: Color
}

private enum CreatorEventStatus: String, CaseIterable {
    case upcoming
    case live
    case ended
    case cancelled

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .live: return "Live"
        case .ended: return "Ended"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .upcoming: return Color(hex: "#3B82F6")
        case .live: return FriendZoneTheme.Colors.error
        case .ended: return FriendZoneTheme.Colors.textTertiary
        case .cancelled: return FriendZoneTheme.Colors.error.opacity(0.6)
        }
    }
}

private enum CreatorVenueStatus: String, CaseIterable {
    case active
    case inactive
    case pendingVerification

    var title: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .pendingVerification: return "Pending"
        }
    }

    var color: Color {
        switch self {
        case .active: return FriendZoneTheme.Colors.success
        case .inactive: return FriendZoneTheme.Colors.textTertiary
        case .pendingVerification: return Color(hex: "#F59E0B")
        }
    }
}

private enum CreatorOfferStatus: String, CaseIterable {
    case active
    case paused
    case draft
    case expired

    var title: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .draft: return "Draft"
        case .expired: return "Expired"
        }
    }

    var color: Color {
        switch self {
        case .active: return FriendZoneTheme.Colors.success
        case .paused: return Color(hex: "#F59E0B")
        case .draft: return FriendZoneTheme.Colors.textTertiary
        case .expired: return FriendZoneTheme.Colors.error.opacity(0.6)
        }
    }
}

private struct CreatorEventItem: Identifiable {
    let id: Int
    var title: String
    var category: String
    var status: CreatorEventStatus
    var venueName: String
    var startAt: Date
    var endAt: Date
    var capacity: Int
    var groupsCount: Int

    static let sample: [CreatorEventItem] = [
        CreatorEventItem(
            id: 5001,
            title: "Midnight Neo-Soul Jam",
            category: "music",
            status: .live,
            venueName: "Neon Hall",
            startAt: Date().addingTimeInterval(60 * 50),
            endAt: Date().addingTimeInterval(60 * 60 * 3),
            capacity: 80,
            groupsCount: 8
        ),
        CreatorEventItem(
            id: 5002,
            title: "Street Art Walk",
            category: "culture",
            status: .upcoming,
            venueName: "East Side Gallery",
            startAt: Date().addingTimeInterval(60 * 60 * 28),
            endAt: Date().addingTimeInterval(60 * 60 * 31),
            capacity: 40,
            groupsCount: 5
        )
    ]
}

private struct CreatorVenueItem: Identifiable {
    let id: Int
    var name: String
    var category: String
    var status: CreatorVenueStatus
    var city: String
    var address: String
    var totalHangouts: Int
    var totalOffers: Int
    var totalPeopleReached: Int
    var isVerified: Bool

    static let sample: [CreatorVenueItem] = [
        CreatorVenueItem(
            id: 7001,
            name: "Mitte Bean Lab",
            category: "cafe",
            status: .active,
            city: "Berlin",
            address: "Rosenthaler Str. 21",
            totalHangouts: 22,
            totalOffers: 5,
            totalPeopleReached: 318,
            isVerified: true
        ),
        CreatorVenueItem(
            id: 7002,
            name: "Skyline Terrace",
            category: "bar",
            status: .pendingVerification,
            city: "Berlin",
            address: "Alexanderplatz 5",
            totalHangouts: 0,
            totalOffers: 0,
            totalPeopleReached: 0,
            isVerified: false
        )
    ]
}

private struct CreatorOfferItem: Identifiable {
    let id: Int
    var title: String
    var perk: String
    var status: CreatorOfferStatus
    var venueName: String
    var validUntil: Date
    var recurrence: String
    var claimsUsed: Int
    var capacity: Int?

    static let sample: [CreatorOfferItem] = [
        CreatorOfferItem(
            id: 9001,
            title: "2x1 Matcha Before 6PM",
            perk: "2x1",
            status: .active,
            venueName: "Mitte Bean Lab",
            validUntil: Date().addingTimeInterval(60 * 60 * 8),
            recurrence: "daily",
            claimsUsed: 11,
            capacity: 40
        ),
        CreatorOfferItem(
            id: 9002,
            title: "Rooftop Entry + Drink",
            perk: "Fast lane",
            status: .paused,
            venueName: "Skyline Terrace",
            validUntil: Date().addingTimeInterval(60 * 60 * 30),
            recurrence: "weekend",
            claimsUsed: 7,
            capacity: 20
        )
    ]
}

private struct CreatorEventCard: View {
    let event: CreatorEventItem

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(hex: "#111827"), Color(hex: "#374151")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 92)
            .overlay {
                Text("EVENT")
                    .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.82))
                    .tracking(1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(event.status.color)
                            .frame(width: 8, height: 8)
                        Text(event.status.title.uppercased())
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        Text(event.category.capitalized)
                            .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 8)

                    Text(timeText(event.startAt))
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }

                Text(event.title)
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(dateText(event.startAt))
                    Text(event.venueName)
                }
                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                HStack {
                    HStack(spacing: 10) {
                        Text("\(event.groupsCount) groups")
                        Text("\(event.capacity) spots")
                    }
                    .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Open dashboard")
                        Image(systemName: "chevron.right")
                    }
                    .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                    .foregroundColor(Color(hex: "#0E7490"))
                }
                .padding(.top, 2)
            }
            .padding(12)
        }
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
        }
    }
}

private struct CreatorVenueCard: View {
    let venue: CreatorVenueItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(venue.status.color)
                        .frame(width: 8, height: 8)
                    Text(venue.status.title.uppercased())
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Text(venue.category.capitalized)
                        .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                    if venue.isVerified {
                        Text("✅ Verified")
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.success)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(FriendZoneTheme.Colors.success.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 8)

                Text("\(venue.totalPeopleReached)")
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
            }

            Text(venue.name)
                .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 3) {
                Text(venue.address)
                Text(venue.city)
            }
            .font(FriendZoneTheme.Typography.system(12, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            HStack(spacing: 10) {
                Text("\(venue.totalHangouts) hangouts")
                Text("\(venue.totalOffers) offers")
            }
            .font(FriendZoneTheme.Typography.system(12, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .padding(.top, 2)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
        }
    }
}

private struct CreatorOfferCard: View {
    let offer: CreatorOfferItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(offer.status.color)
                        .frame(width: 8, height: 8)
                    Text(offer.status.title.uppercased())
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Text(offer.perk)
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(Color(hex: "#0E7490"))
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Color(hex: "#0E7490").opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8)

                Text("Until \(shortDate(offer.validUntil))")
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
            }

            Text(offer.title)
                .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            HStack(spacing: 8) {
                Text(offer.venueName)
                if offer.recurrence.lowercased() != "none" {
                    Text(offer.recurrence.capitalized)
                }
            }
            .font(FriendZoneTheme.Typography.system(12, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            HStack {
                HStack(spacing: 10) {
                    Text("\(offer.claimsUsed) claims")
                    if let capacity = offer.capacity {
                        Text("\(max(0, capacity - offer.claimsUsed)) left")
                    }
                }
                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                Spacer()

                HStack(spacing: 4) {
                    Text("Open dashboard")
                    Image(systemName: "chevron.right")
                }
                .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                .foregroundColor(Color(hex: "#0E7490"))
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
        }
    }
}

private struct CreatorEventDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSessionStore

    @State private var draft: CreatorEventItem
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSave: (CreatorEventItem) -> Void

    init(event: CreatorEventItem, onSave: @escaping (CreatorEventItem) -> Void) {
        _draft = State(initialValue: event)
        self.onSave = onSave
    }

    private var estimatedAttendance: Int {
        min(draft.capacity, max(0, draft.groupsCount * 4))
    }

    private var attendanceRatio: Double {
        guard draft.capacity > 0 else { return 0 }
        return min(1, Double(estimatedAttendance) / Double(draft.capacity))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                FriendZoneModuleHeader(
                    leadingText: "Event ",
                    highlightText: "Dashboard",
                    subtitle: "Manage event state and performance"
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.title)
                                .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            Text("\(draft.venueName) • \(dateText(draft.startAt))")
                                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Text(draft.status.title.uppercased())
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(draft.status.color)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(draft.status.color.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 8) {
                        dashboardMetric(title: "Groups", value: "\(draft.groupsCount)")
                        dashboardMetric(title: "Capacity", value: "\(draft.capacity)")
                        dashboardMetric(title: "Attendance", value: "\(estimatedAttendance)")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Fill rate")
                            Spacer()
                            Text("\(Int(attendanceRatio * 100))%")
                        }
                        .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                        GeometryReader { proxy in
                            let width = max(0, min(proxy.size.width, proxy.size.width * attendanceRatio))
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(FriendZoneTheme.Colors.surfaceMuted)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: "#0E7490"))
                                    .frame(width: width)
                            }
                        }
                        .frame(height: 10)
                    }
                }
                .padding(14)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Controls")
                        .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    formField("Status") {
                        Text(draft.status.title)
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    }

                    formField("Start date") {
                        DatePicker(
                            "",
                            selection: $draft.startAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    formField("Groups count") {
                        Stepper(value: $draft.groupsCount, in: 0 ... 200) {
                            Text("\(draft.groupsCount)")
                                .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                        }
                    }

                    formField("Capacity") {
                        Stepper(value: $draft.capacity, in: 1 ... 2000) {
                            Text("\(draft.capacity)")
                                .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                        }
                    }

                    HStack(spacing: 8) {
                        if draft.status == .live || draft.status == .upcoming {
                            quickActionButton("Cancel", tint: FriendZoneTheme.Colors.error) {
                                Task { await cancelEvent() }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.error)
                    }
                }
                .padding(14)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                }

                Button(isSaving ? "Saving..." : "Save Event Changes") {
                    Task { await saveEvent() }
                }
                .buttonStyle(.plain)
                .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "#0F172A"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 26)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Event Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await saveEvent() }
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .disabled(isSaving)
            }
        }
    }

    private func dashboardMetric(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func quickActionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func saveEvent() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            let duration = max(60, draft.endAt.timeIntervalSince(draft.startAt))
            let updated = try await session.updateCreatorEvent(
                id: draft.id,
                title: draft.title,
                startAt: draft.startAt,
                endAt: draft.startAt.addingTimeInterval(duration),
                capacity: draft.capacity,
                category: draft.category
            )
            draft.status = mapEventStatus(updated.status)
            onSave(
                CreatorEventItem(
                    id: updated.id,
                    title: updated.title,
                    category: updated.category ?? draft.category,
                    status: mapEventStatus(updated.status),
                    venueName: updated.venueName ?? draft.venueName,
                    startAt: draft.startAt,
                    endAt: draft.startAt.addingTimeInterval(duration),
                    capacity: updated.capacity ?? draft.capacity,
                    groupsCount: updated.hangoutsCount ?? draft.groupsCount
                )
            )
            FriendZoneHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func cancelEvent() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            let updated = try await session.cancelCreatorEvent(id: draft.id)
            draft.status = mapEventStatus(updated.status)
            onSave(
                CreatorEventItem(
                    id: updated.id,
                    title: updated.title,
                    category: updated.category ?? draft.category,
                    status: mapEventStatus(updated.status),
                    venueName: updated.venueName ?? draft.venueName,
                    startAt: draft.startAt,
                    endAt: draft.endAt,
                    capacity: updated.capacity ?? draft.capacity,
                    groupsCount: updated.hangoutsCount ?? draft.groupsCount
                )
            )
            FriendZoneHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mapEventStatus(_ raw: String) -> CreatorEventStatus {
        switch raw.lowercased() {
        case "live":
            return .live
        case "ended":
            return .ended
        case "cancelled":
            return .cancelled
        default:
            return .upcoming
        }
    }
}

private struct CreatorOfferDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSessionStore

    @State private var draft: CreatorOfferItem
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSave: (CreatorOfferItem) -> Void

    init(offer: CreatorOfferItem, onSave: @escaping (CreatorOfferItem) -> Void) {
        _draft = State(initialValue: offer)
        self.onSave = onSave
    }

    private var claimsLeftText: String {
        guard let capacity = draft.capacity else { return "Unlimited" }
        return "\(max(0, capacity - draft.claimsUsed))"
    }

    private var usageRatio: Double {
        guard let capacity = draft.capacity, capacity > 0 else { return 0 }
        return min(1, Double(draft.claimsUsed) / Double(capacity))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                FriendZoneModuleHeader(
                    leadingText: "Offer ",
                    highlightText: "Dashboard",
                    subtitle: "Manage publishing and redemptions"
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.title)
                                .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            Text("\(draft.venueName) • until \(shortDate(draft.validUntil))")
                                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Text(draft.status.title.uppercased())
                            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                            .foregroundColor(draft.status.color)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(draft.status.color.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 8) {
                        dashboardMetric(title: "Claims", value: "\(draft.claimsUsed)")
                        dashboardMetric(title: "Left", value: claimsLeftText)
                        dashboardMetric(title: "Perk", value: draft.perk)
                    }

                    if draft.capacity != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Usage")
                                Spacer()
                                Text("\(Int(usageRatio * 100))%")
                            }
                            .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                            GeometryReader { proxy in
                                let width = max(0, min(proxy.size.width, proxy.size.width * usageRatio))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(FriendZoneTheme.Colors.surfaceMuted)
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(hex: "#0E7490"))
                                        .frame(width: width)
                                }
                            }
                            .frame(height: 10)
                        }
                    }
                }
                .padding(14)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Controls")
                        .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    formField("Status") {
                        Picker("Status", selection: $draft.status) {
                            ForEach(CreatorOfferStatus.allCases, id: \.rawValue) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    formField("Valid until") {
                        DatePicker(
                            "",
                            selection: $draft.validUntil,
                            displayedComponents: [.date]
                        )
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    formField("Recurrence") {
                        Picker("Recurrence", selection: $draft.recurrence) {
                            Text("One-time").tag("none")
                            Text("Daily").tag("daily")
                            Text("Weekend").tag("weekend")
                        }
                        .pickerStyle(.menu)
                    }

                    formField("Claims used") {
                        Stepper(value: $draft.claimsUsed, in: 0 ... 2000) {
                            Text("\(draft.claimsUsed)")
                                .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                        }
                    }

                    Toggle(
                        "Limit claims",
                        isOn: Binding(
                            get: { draft.capacity != nil },
                            set: { shouldLimit in
                                if shouldLimit {
                                    draft.capacity = max(draft.claimsUsed + 10, 20)
                                } else {
                                    draft.capacity = nil
                                }
                            }
                        )
                    )
                    .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                    .tint(FriendZoneTheme.Colors.primary)

                    if draft.capacity != nil {
                        formField("Claims capacity") {
                            Stepper(
                                value: Binding(
                                    get: { max(draft.capacity ?? 0, draft.claimsUsed) },
                                    set: { newValue in
                                        draft.capacity = max(newValue, draft.claimsUsed)
                                    }
                                ),
                                in: max(draft.claimsUsed, 1) ... 2000
                            ) {
                                Text("\(draft.capacity ?? draft.claimsUsed)")
                                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        if draft.status == .active {
                            quickActionButton("Pause", tint: Color(hex: "#D97706")) {
                                Task { await pauseOffer() }
                            }
                        }
                        if draft.status == .paused || draft.status == .draft {
                            quickActionButton("Publish", tint: FriendZoneTheme.Colors.success) {
                                Task { await resumeOffer() }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.error)
                    }
                }
                .padding(14)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                }

                Button(isSaving ? "Saving..." : "Save Offer Changes") {
                    Task { await saveOffer() }
                }
                .buttonStyle(.plain)
                .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "#0F172A"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 26)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Offer Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await saveOffer() }
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .disabled(isSaving)
            }
        }
    }

    private func dashboardMetric(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(FriendZoneTheme.Typography.system(16, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(10, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func quickActionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func saveOffer() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            let updated = try await session.updateCreatorOffer(
                id: draft.id,
                title: draft.title,
                perk: draft.perk,
                validUntil: draft.validUntil,
                recurrence: draft.recurrence.lowercased(),
                capacity: draft.capacity
            )
            let mapped = CreatorOfferItem(
                id: updated.id,
                title: updated.title,
                perk: updated.perk,
                status: mapOfferStatus(updated.status),
                venueName: updated.venueName ?? draft.venueName,
                validUntil: draft.validUntil,
                recurrence: updated.recurrenceDisplay ?? draft.recurrence,
                claimsUsed: updated.claimsUsed ?? draft.claimsUsed,
                capacity: updated.capacity
            )
            draft = mapped
            onSave(mapped)
            FriendZoneHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func pauseOffer() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            let updated = try await session.pauseCreatorOffer(id: draft.id)
            let mapped = CreatorOfferItem(
                id: updated.id,
                title: updated.title,
                perk: updated.perk,
                status: mapOfferStatus(updated.status),
                venueName: updated.venueName ?? draft.venueName,
                validUntil: draft.validUntil,
                recurrence: updated.recurrenceDisplay ?? draft.recurrence,
                claimsUsed: updated.claimsUsed ?? draft.claimsUsed,
                capacity: updated.capacity
            )
            draft = mapped
            onSave(mapped)
            FriendZoneHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func resumeOffer() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            let updated = try await session.resumeCreatorOffer(id: draft.id)
            let mapped = CreatorOfferItem(
                id: updated.id,
                title: updated.title,
                perk: updated.perk,
                status: mapOfferStatus(updated.status),
                venueName: updated.venueName ?? draft.venueName,
                validUntil: draft.validUntil,
                recurrence: updated.recurrenceDisplay ?? draft.recurrence,
                claimsUsed: updated.claimsUsed ?? draft.claimsUsed,
                capacity: updated.capacity
            )
            draft = mapped
            onSave(mapped)
            FriendZoneHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mapOfferStatus(_ raw: String) -> CreatorOfferStatus {
        switch raw.lowercased() {
        case "active":
            return .active
        case "paused":
            return .paused
        case "draft":
            return .draft
        default:
            return .expired
        }
    }
}

private struct CreatorCreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSessionStore

    let onCreate: (CreatorEventItem) -> Void

    @State private var title = ""
    @State private var category = "music"
    @State private var venueName = ""
    @State private var startAt = Date().addingTimeInterval(60 * 60 * 24)
    @State private var endAt = Date().addingTimeInterval(60 * 60 * 26)
    @State private var capacity = 50
    @State private var description = ""
    @State private var errorMessage = ""
    @State private var isSubmitting = false

    private let categories = ["music", "sports", "tech", "art", "food", "party", "networking", "outdoor", "community", "other"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Event")
                        .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    if !errorMessage.isEmpty {
                        formError(errorMessage)
                    }

                    formField("Title *") {
                        TextField("Event name", text: $title)
                    }

                    formField("Category *") {
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { value in
                                Text(value.capitalized).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    formField("Venue *") {
                        TextField("Venue name", text: $venueName)
                    }

                    HStack(spacing: 10) {
                        formField("Starts *") {
                            DatePicker("", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        formField("Ends *") {
                            DatePicker("", selection: $endAt, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    formField("Capacity *") {
                        Stepper(value: $capacity, in: 1 ... 500) {
                            Text("\(capacity)")
                                .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                        }
                    }

                    formField("Description") {
                        TextEditor(text: $description)
                            .frame(minHeight: 92)
                    }
                }
                .padding(16)
            }
            .background(FriendZoneTheme.Colors.background)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(isSubmitting ? "Creating..." : "Create Event") {
                        Task { await create() }
                    }
                    .buttonStyle(.plain)
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(FriendZoneTheme.Colors.surface.opacity(0.98))
            }
        }
    }

    @MainActor
    private func create() async {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            errorMessage = "Title, venue and schedule are required."
            return
        }
        if endAt <= startAt {
            errorMessage = "End time must be after start time."
            return
        }
        guard !(session.currentProfile?.cityName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Set your city in profile before creating events."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let created = try await session.createCreatorEvent(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                venueName: venueName.trimmingCharacters(in: .whitespacesAndNewlines),
                venueAddress: "",
                startAt: startAt,
                endAt: endAt,
                capacity: capacity,
                category: category
            )
            let item = CreatorEventItem(
                id: created.id,
                title: created.title,
                category: created.category ?? category,
                status: .upcoming,
                venueName: created.venueName ?? venueName.trimmingCharacters(in: .whitespacesAndNewlines),
                startAt: startAt,
                endAt: endAt,
                capacity: created.capacity ?? capacity,
                groupsCount: created.hangoutsCount ?? 0
            )
            onCreate(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CreatorCreateVenueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSessionStore
    let onCreate: (CreatorVenueItem) -> Void

    @State private var name = ""
    @State private var address = ""
    @State private var city = ""
    @State private var category = "bar"
    @State private var errorMessage = ""
    @State private var isSubmitting = false

    private let categories = ["bar", "cafe", "restaurant", "club", "coworking", "park", "gym", "gallery", "theater", "other"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Venue")
                        .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    if !errorMessage.isEmpty {
                        formError(errorMessage)
                    }

                    requestStatusBox

                    formField("Category *") {
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { value in
                                Text(value.capitalized).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    formField("Venue Name *") {
                        TextField("Venue name", text: $name)
                    }

                    formField("Address *") {
                        TextField("Full address", text: $address)
                    }

                    formField("City *") {
                        TextField("City", text: $city)
                    }
                }
                .padding(16)
            }
            .background(FriendZoneTheme.Colors.background)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(isSubmitting ? "Submitting..." : "Submit Venue Request") {
                        Task { await create() }
                    }
                    .buttonStyle(.plain)
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(FriendZoneTheme.Colors.surface.opacity(0.98))
            }
        }
    }

    private var requestStatusBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pending review")
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(Color(hex: "#92400E"))
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Color(hex: "#F59E0B").opacity(0.16))
                .clipShape(Capsule())

            Text("After submit, our team reviews ownership before activating this venue.")
                .font(FriendZoneTheme.Typography.system(12, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            Text("Until place search is integrated, the app creates a manual venue reference from your typed address.")
                .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    @MainActor
    private func create() async {
        errorMessage = ""
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            errorMessage = "Name, address and city are required."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let created = try await session.createCreatorVenue(
                name: name,
                category: category,
                address: address,
                city: city
            )
            let item = CreatorVenueItem(
                id: created.id,
                name: created.name,
                category: created.category,
                status: mapVenueStatus(created.status),
                city: created.city,
                address: created.address,
                totalHangouts: created.totalHangouts ?? 0,
                totalOffers: created.totalOffers ?? 0,
                totalPeopleReached: created.totalPeopleReached ?? 0,
                isVerified: created.isVerified ?? false
            )
            onCreate(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mapVenueStatus(_ raw: String) -> CreatorVenueStatus {
        switch raw.lowercased() {
        case "active":
            return .active
        case "pending":
            return .pendingVerification
        default:
            return .inactive
        }
    }
}

private struct CreatorCreateOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSessionStore

    let venues: [CreatorVenueItem]
    let onCreate: (CreatorOfferItem) -> Void

    @State private var title = ""
    @State private var perk = ""
    @State private var selectedVenueID: Int?
    @State private var validFrom = Date()
    @State private var validUntil = Date().addingTimeInterval(60 * 60 * 24 * 7)
    @State private var recurrence = "none"
    @State private var capacity: Int?
    @State private var description = ""
    @State private var autoCreateHangout = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false

    private let recurrenceOptions = ["none", "daily", "weekend"]
    private var selectableVenues: [CreatorVenueItem] {
        venues.filter { $0.status == .active }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Offer")
                        .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    if !errorMessage.isEmpty {
                        formError(errorMessage)
                    }

                    if selectableVenues.isEmpty {
                        Text("You need at least one approved venue before creating offers.")
                            .font(FriendZoneTheme.Typography.system(14, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .padding(12)
                            .background(FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        formField("Title *") {
                            TextField("Happy hour special", text: $title)
                        }
                        formField("Perk *") {
                            TextField("2x1 cocktails", text: $perk)
                        }
                        formField("Venue *") {
                            Picker("Venue", selection: $selectedVenueID) {
                                Text("Select venue...").tag(nil as Int?)
                                ForEach(selectableVenues) { venue in
                                    Text(venue.name).tag(venue.id as Int?)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack(spacing: 10) {
                            formField("Valid from *") {
                                DatePicker("", selection: $validFrom, displayedComponents: [.date])
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            formField("Valid until *") {
                                DatePicker("", selection: $validUntil, displayedComponents: [.date])
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        formField("Recurrence") {
                            Picker("Recurrence", selection: $recurrence) {
                                ForEach(recurrenceOptions, id: \.self) { value in
                                    Text(value == "none" ? "One-time" : value.capitalized).tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        formField("Capacity (optional)") {
                            Stepper(value: Binding(get: {
                                capacity ?? 1
                            }, set: { newValue in
                                capacity = newValue
                            }), in: 1 ... 500) {
                                Text(capacity == nil ? "Unlimited" : "\(capacity ?? 0)")
                                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                            }
                        }

                        formField("Description") {
                            TextEditor(text: $description)
                                .frame(minHeight: 78)
                        }

                        Toggle("Auto-create a hangout when published", isOn: $autoCreateHangout)
                            .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                            .tint(FriendZoneTheme.Colors.primary)
                    }
                }
                .padding(16)
            }
            .background(FriendZoneTheme.Colors.background)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(FriendZoneTheme.Typography.system(15, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(isSubmitting ? "Creating..." : "Create Offer") {
                        Task { await create() }
                    }
                    .buttonStyle(.plain)
                    .font(FriendZoneTheme.Typography.system(15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(selectableVenues.isEmpty || isSubmitting)
                    .opacity((selectableVenues.isEmpty || isSubmitting) ? 0.6 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(FriendZoneTheme.Colors.surface.opacity(0.98))
            }
        }
    }

    @MainActor
    private func create() async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !perk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let selectedVenueID,
              let selectedVenue = selectableVenues.first(where: { $0.id == selectedVenueID })
        else {
            errorMessage = "Title, perk and venue are required."
            return
        }

        if validUntil < validFrom {
            errorMessage = "Valid until must be after valid from."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let created = try await session.createCreatorOffer(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                perk: perk.trimmingCharacters(in: .whitespacesAndNewlines),
                venueID: selectedVenueID,
                validFrom: validFrom,
                validUntil: validUntil,
                recurrence: recurrence,
                capacity: capacity,
                autoCreateHangout: autoCreateHangout,
                terms: description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let item = CreatorOfferItem(
                id: created.id,
                title: created.title,
                perk: created.perk,
                status: autoCreateHangout ? .active : mapCreatedOfferStatus(created.status),
                venueName: created.venueName ?? selectedVenue.name,
                validUntil: validUntil,
                recurrence: created.recurrenceDisplay ?? recurrence,
                claimsUsed: created.claimsUsed ?? 0,
                capacity: created.capacity
            )
            onCreate(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mapCreatedOfferStatus(_ raw: String) -> CreatorOfferStatus {
        switch raw.lowercased() {
        case "active":
            return .active
        case "paused":
            return .paused
        case "draft":
            return .draft
        default:
            return .expired
        }
    }
}

private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(label.uppercased())
            .font(FriendZoneTheme.Typography.system(10, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

        content()
            .font(FriendZoneTheme.Typography.system(14, weight: .medium))
            .padding(.horizontal, 10)
            .frame(minHeight: 42, alignment: .leading)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private func formError(_ text: String) -> some View {
    Text(text)
        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
        .foregroundColor(FriendZoneTheme.Colors.error)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FriendZoneTheme.Colors.error.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(FriendZoneTheme.Colors.error.opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
}

private func dateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d"
    return formatter.string(from: date)
}

private func timeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}

private func shortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
}

#if DEBUG
struct NativeCreatorSpaceHubView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NativeCreatorSpaceHubView(
                userFlags: SettingsUserRoleFlags(
                    isEventCreator: true,
                    isVenueOwner: true,
                    isStaff: false
                )
            )
        }
    }
}
#endif
