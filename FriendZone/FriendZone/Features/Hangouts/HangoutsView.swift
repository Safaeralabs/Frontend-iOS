import SwiftUI
import Combine
import UIKit
import PhotosUI
import MapKit

struct HangoutsView: View {
    @EnvironmentObject private var session: AppSessionStore
    @Environment(\.scenePhase) private var scenePhase
    var usesExternalBackdrop: Bool = false
    var onRequestOpenMaps: (() -> Void)? = nil

    @StateObject private var viewModel = HangoutsViewModel()
    @State private var now = Date()
    @State private var isPresentingCreate = false
    @State private var pendingHangoutSource: HangoutSourceType = .hangout
    @State private var pendingHangoutSourceLabel: String?
    @State private var pendingHangoutSourceEventID: Int?
    @State private var pendingHangoutSourceOfferID: Int?
    @State private var isPresentingAdvancedFilters = false
    @State private var isPresentingProfile = false
    @State private var isPresentingSettings = false
    @State private var isPresentingCreatorSpace = false
    @State private var isPresentingNotifications = false
    @State private var isPresentingPlans = false
    @State private var selectedEventDetail: DiscoveryEventItem?
    @State private var selectedOfferDetail: DiscoveryOfferItem?
    @State private var publicProfileRequest: PublicProfileRequest?
    @State private var selectedMode: DiscoveryMode = .hangouts
    @State private var selectedMenuHangout: HangoutItem?
    @State private var isShowingHangoutMenu = false
    @State private var isShowingReportAcknowledgement = false
    @State private var backendEvents: [DiscoveryEventItem] = []
    @State private var backendOffers: [DiscoveryOfferItem] = []
    @State private var discoveryErrorMessage: String?
    @State private var shouldRefreshHangoutsOnAppear = false
    @State private var isPresentingTravelMode = false
    @State private var isRefreshingDiscovery = false
    @State private var unreadNotificationCount = 0
    @State private var selectedHangoutDetail: HangoutItem?
    @StateObject private var creatorContext = SettingsCreatorContextViewModel()

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let calendar = Calendar.current

    private enum DiscoveryMode: String, CaseIterable, Identifiable {
        case hangouts
        case events
        case offers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hangouts: return "Hangouts"
            case .events: return "Events"
            case .offers: return "Offers"
            }
        }
    }

    struct DiscoveryEventItem: Identifiable {
        let id: Int
        let title: String
        let venue: String
        let startAt: Date
        let groups: Int
        let category: String
        let creatorProfile: CreatorProfileDraft
        let photoMoments: [EventPhotoMoment]
    }

    struct EventPhotoMoment: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let symbol: String
        let palette: [Color]
        var imageURL: String? = nil
    }

    struct DiscoveryOfferItem: Identifiable {
        let id: Int
        let title: String
        let venue: String
        let perk: String
        let validUntil: Date
        let spotsLeft: Int
        let venueProfile: CreatorProfileDraft
    }

    var body: some View {
        rootContent
        .background(usesExternalBackdrop ? Color.clear : FriendZoneTheme.Colors.background)
        .task {
            await viewModel.loadIfNeeded()
            await creatorContext.loadIfNeeded()
            await loadDiscoveryContent()
            await loadBackendHangouts()
            await loadUnreadNotificationCount()
        }
        .onChange(of: session.currentProfile?.activeCityPlaceId) { _ in
            Task {
                await loadDiscoveryContent()
                await loadBackendHangouts()
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await loadUnreadNotificationCount() }
        }
        .onChange(of: isPresentingCreate) { isPresented in
            guard !isPresented, shouldRefreshHangoutsOnAppear else { return }
            shouldRefreshHangoutsOnAppear = false
            Task { await loadBackendHangouts() }
        }
        .onReceive(minuteTicker) { value in
            now = value
        }
        .fullScreenCover(isPresented: $isPresentingCreate) {
            createHangoutCover
        }
        .fullScreenCover(isPresented: $isPresentingProfile) {
            profileCover
        }
        .fullScreenCover(isPresented: $isPresentingSettings, onDismiss: {
            Task { await creatorContext.refresh() }
        }) {
            settingsCover
        }
        .fullScreenCover(isPresented: $isPresentingCreatorSpace) {
            creatorSpaceCover
        }
        .fullScreenCover(isPresented: $isPresentingNotifications, onDismiss: {
            Task { await loadUnreadNotificationCount() }
        }) {
            notificationsCover
        }
        .fullScreenCover(isPresented: $isPresentingPlans) {
            plansCover
        }
        .fullScreenCover(item: $selectedEventDetail) { event in
            NavigationStack {
                NativeEventDetailView(
                    event: event,
                    creatorProfile: event.creatorProfile,
                    onClose: { selectedEventDetail = nil },
                    onJoinSoloSuccess: {
                        selectedEventDetail = nil
                    },
                    onCreateHangout: {
                        selectedEventDetail = nil
                        pendingHangoutSource = .event
                        pendingHangoutSourceLabel = event.title
                        pendingHangoutSourceEventID = event.id
                        pendingHangoutSourceOfferID = nil
                        isPresentingCreate = true
                        FriendZoneHaptics.selection()
                    },
                    onShowCreatorProfile: {
                        publicProfileRequest = PublicProfileRequest(
                            profile: PublicProfileData(draft: event.creatorProfile),
                            leadingText: "Event ",
                            highlightText: "creator",
                            subtitle: nil
                        )
                    }
                )
            }
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
        }
        .fullScreenCover(item: $selectedOfferDetail) { offer in
            NavigationStack {
                NativeOfferDetailView(
                    offer: offer,
                    venueProfile: offer.venueProfile,
                    onClose: { selectedOfferDetail = nil },
                    onJoinSolo: {
                        selectedOfferDetail = nil
                        FriendZoneHaptics.success()
                    },
                    onCreateHangout: {
                        selectedOfferDetail = nil
                        pendingHangoutSource = .offer
                        pendingHangoutSourceLabel = offer.title
                        pendingHangoutSourceEventID = nil
                        pendingHangoutSourceOfferID = offer.id
                        isPresentingCreate = true
                        FriendZoneHaptics.selection()
                    },
                    onShowVenueProfile: {
                        publicProfileRequest = PublicProfileRequest(
                            profile: PublicProfileData(draft: offer.venueProfile),
                            leadingText: "Venue ",
                            highlightText: "profile",
                            subtitle: nil
                        )
                    }
                )
            }
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
        }
        .sheet(item: $selectedHangoutDetail) { hangout in
            discoverHangoutDetailSheet(hangout)
        }
        .sheet(item: $publicProfileRequest) { request in
            NavigationStack {
                PublicProfileView(
                    profile: request.profile,
                    leadingText: request.leadingText,
                    highlightText: request.highlightText,
                    subtitle: request.subtitle
                ) {
                    publicProfileRequest = nil
                }
            }
            .background(FriendZoneTheme.Colors.background)
        }
        .sheet(isPresented: $isPresentingAdvancedFilters) {
            HangoutsAdvancedFiltersSheet(
                filters: $viewModel.advancedFilters,
                onClose: { isPresentingAdvancedFilters = false },
                onReset: { viewModel.clearAdvancedFilters() }
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Hangout actions",
            isPresented: $isShowingHangoutMenu,
            titleVisibility: .visible
        ) {
            Button("Report Hangout", role: .destructive) {
                selectedMenuHangout = nil
                isShowingReportAcknowledgement = true
                FriendZoneHaptics.lightImpact()
            }
            Button("Cancel", role: .cancel) {
                selectedMenuHangout = nil
            }
        } message: {
            if let title = selectedMenuHangout?.title {
                Text("What do you want to do with \"\(title)\"?")
            }
        }
        .alert("Report sent", isPresented: $isShowingReportAcknowledgement) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks. We will review this hangout.")
        }
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: selectedMode)
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: viewModel.selectedDay)
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: viewModel.advancedFilters)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard let onRequestOpenMaps else { return }
                    let deltaX = value.translation.width
                    let deltaY = value.translation.height
                    let isHorizontal = abs(deltaX) > abs(deltaY) * 1.2
                    if isHorizontal, deltaX < -45 {
                        onRequestOpenMaps()
                    }
                }
        )
        .ignoresSafeArea(.container, edges: [.bottom])
    }

    private var discoveryEvents: [DiscoveryEventItem] {
        backendEvents
    }

    private var discoveryOffers: [DiscoveryOfferItem] {
        backendOffers
    }

    private var hasUnreadNotifications: Bool {
        unreadNotificationCount > 0
    }

    private func loadDiscoveryContent() async {
        await MainActor.run {
            discoveryErrorMessage = nil
        }
        async let eventsLoad: Void = loadEvents()
        async let offersLoad: Void = loadOffers()
        _ = await (eventsLoad, offersLoad)
    }

    @MainActor
    private func loadUnreadNotificationCount() async {
        guard session.currentUser != nil || session.currentProfile != nil else {
            unreadNotificationCount = 0
            return
        }

        do {
            unreadNotificationCount = try await session.fetchUnreadNotificationCount()
        } catch {
            // Keep the last known value if the unread-count endpoint fails.
        }
    }

    private var rootContent: some View {
        ZStack(alignment: .bottomTrailing) {
            backdrop

            VStack(spacing: 0) {
                topIcons
                header
                modeSwitch
                dayPicker
                ZStack(alignment: .top) {
                    content

                    if selectedMode == .hangouts {
                        discoveryHangoutsTopBlend
                    }
                }
            }

            if selectedMode == .hangouts {
                createFAB
            }
        }
    }

    private var discoveryHangoutsTopBlend: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#F3F4FA").opacity(0.52), location: 0),
                        .init(color: Color(hex: "#F3F4FA").opacity(0.22), location: 0.38),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 24)
            .allowsHitTesting(false)
    }

    private var createHangoutCover: some View {
        CreateHangoutView(
            onCancel: { isPresentingCreate = false },
            onCreated: { draft in
                viewModel.addCreatedHangout(from: draft)
                shouldRefreshHangoutsOnAppear = true
            },
            initialDraft: CreateHangoutDraft(
                cityName: session.activeCityName ?? "",
                cityPlaceID: session.activeCityPlaceId ?? "",
                sourceType: pendingHangoutSource,
                sourceLabel: pendingHangoutSourceLabel,
                sourceEventID: pendingHangoutSourceEventID,
                sourceOfferID: pendingHangoutSourceOfferID
            )
        )
        .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
    }

    private var profileCover: some View {
        NavigationStack {
            NativeProfileHubView(
                onClose: { isPresentingProfile = false }
            )
        }
        .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
    }

    private var settingsCover: some View {
        NavigationStack {
            NativeSettingsHubView(
                onClose: { isPresentingSettings = false }
            )
        }
        .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
    }

    private var creatorSpaceCover: some View {
        NavigationStack {
            NativeCreatorSpaceHubView(
                userFlags: creatorContext.userFlags,
                onClose: { isPresentingCreatorSpace = false }
            )
        }
        .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
    }

    private var notificationsCover: some View {
        NavigationStack {
            NativeNotificationsHubView(
                onClose: { isPresentingNotifications = false },
                onUnreadCountChange: { unreadNotificationCount = $0 }
            )
        }
        .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
    }

    private var plansCover: some View {
        NavigationStack {
            NativePlansHubView(
                onClose: { isPresentingPlans = false }
            )
        }
        .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
    }

    private func loadEvents() async {
        do {
            let items = try await session.fetchUpcomingEvents(cityPlaceId: session.activeCityPlaceId)
            let mapped = items.compactMap(mapDiscoveryEvent)
            await MainActor.run {
                backendEvents = mapped.sorted { $0.startAt < $1.startAt }
            }
        } catch {
            await MainActor.run {
                backendEvents = []
                discoveryErrorMessage = error.localizedDescription
            }
        }
    }

    private func loadOffers() async {
        do {
            let items = try await session.fetchActiveOffers(cityPlaceId: session.activeCityPlaceId)
            let mapped = items.compactMap(mapDiscoveryOffer)
            await MainActor.run {
                backendOffers = mapped.sorted { $0.validUntil < $1.validUntil }
            }
        } catch {
            await MainActor.run {
                backendOffers = []
                discoveryErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func refreshSelectedDiscoveryMode() async {
        guard !isRefreshingDiscovery else { return }
        isRefreshingDiscovery = true
        discoveryErrorMessage = nil
        FriendZoneHaptics.selection()
        defer { isRefreshingDiscovery = false }

        switch selectedMode {
        case .hangouts:
            await loadBackendHangouts()
        case .events:
            await loadEvents()
        case .offers:
            await loadOffers()
        }
    }

    private func mapDiscoveryEvent(_ item: DiscoveryEventFeedItem) -> DiscoveryEventItem? {
        guard let startAt = parseServerDate(item.startAt) else { return nil }
        let venue = item.venueName ?? item.city ?? "Event venue"
        let displayName = item.creatorDisplayName ?? item.creatorUsername ?? "Event creator"
        return DiscoveryEventItem(
            id: item.id,
            title: item.title,
            venue: venue,
            startAt: startAt,
            groups: max(item.hangoutsCount ?? 0, 1),
            category: item.category ?? "Event",
            creatorProfile: CreatorProfileDraft(
                userID: item.creator,
                displayName: displayName,
                username: item.creatorUsername,
                bio: "\(venue) · \(item.category ?? "Event")",
                instagram: item.creatorUsername ?? "",
                website: "",
                city: item.city ?? "Berlin",
                avatarURL: item.creatorAvatarUrl
            ),
            photoMoments: item.primaryImageUrl == nil ? [] : [
                EventPhotoMoment(
                    id: item.id,
                    title: "Event moment",
                    subtitle: venue,
                    symbol: "photo",
                    palette: [Color(hex: "#171717"), Color(hex: "#525252"), Color(hex: "#A3A3A3")]
                )
            ]
        )
    }

    private func mapDiscoveryOffer(_ item: DiscoveryOfferFeedItem) -> DiscoveryOfferItem? {
        guard let validUntil = parseServerDate(item.validUntil) else { return nil }
        return DiscoveryOfferItem(
            id: item.id,
            title: item.title,
            venue: item.venueName ?? "Venue",
            perk: item.perk,
            validUntil: validUntil,
            spotsLeft: max(item.spotsRemaining ?? 0, 0),
            venueProfile: CreatorProfileDraft(
                userID: item.owner,
                displayName: item.venueName ?? (item.ownerUsername ?? "Venue"),
                username: item.ownerUsername,
                bio: item.description ?? "Venue offer available through FriendZone.",
                instagram: item.ownerUsername ?? "",
                website: "",
                city: "Berlin",
            )
        )
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

    @MainActor
    private func loadBackendHangouts() async {
        do {
            let items = try await session.fetchHangouts(
                cityPlaceId: session.activeCityPlaceId
            )
            let currentUserID = currentSessionUserID
            let mapped = items.compactMap(mapHangoutFeed)

            let requestedIDs = Set(
                items.compactMap { item in
                    let hasRequested = item.joinRequests.contains { request in
                        request.user == currentUserID &&
                        ["pending", "waitlisted"].contains(request.status.lowercased())
                    }
                    return hasRequested ? item.id : nil
                }
            )

            viewModel.replaceHangouts(
                mapped.sorted { $0.startAt < $1.startAt },
                requestedIDs: requestedIDs
            )
        } catch {
            if viewModel.allHangouts.isEmpty {
                viewModel.replaceHangouts([], requestedIDs: [])
            }
        }
    }

    private func mapHangoutFeed(_ item: HangoutFeedItem) -> HangoutItem? {
        guard
            let startAt = parseServerDate(item.startAt),
            let endAt = parseServerDate(item.endAt)
        else {
            return nil
        }

        let currentUserID = currentSessionUserID
        let isJoined = item.participants.contains {
            $0.user == currentUserID && $0.status.lowercased() == "approved"
        }
        let participantNames = item.participants
            .filter { $0.status.lowercased() == "approved" && $0.user != item.host }
            .map(\.username)

        return HangoutItem(
            id: item.id,
            sourceType: mapSourceType(item.sourceType),
            title: item.title,
            description: item.description,
            vibe: mapVibe(item.vibe),
            cityName: item.cityName,
            locationName: item.locationName,
            locationAddress: item.locationAddress,
            latitude: item.lat,
            longitude: item.lng,
            hostUserID: item.host,
            hostName: item.host == currentUserID ? "you" : item.hostUsername,
            startAt: startAt,
            endAt: endAt,
            capacity: item.capacity,
            isCapacityUnlimited: item.isCapacityUnlimited,
            approvedCount: item.approvedParticipantsCount ?? max(1, participantNames.count + 1),
            isJoined: isJoined || item.host == currentUserID,
            participantNames: participantNames,
            coverImageData: nil,
            coverImageURL: item.coverImageUrl,
            coverSeed: item.id,
            distanceKm: 1.2,
            priceTier: .free,
            visibility: item.visibility.flatMap(HangoutVisibilityOption.init(backendRawValue:)),
            inviteCode: item.inviteCode,
            inviteCodeHint: item.inviteCodeHint,
            allowWaitlist: item.allowWaitlist,
            genderPreference: item.genderPreference.flatMap(HangoutGenderPreference.init(backendRawValue:)),
            audienceTags: item.audienceTags,
            languages: item.languages,
            isTimeFlexible: item.isTimeFlexible,
            sourceEventID: item.sourceEventId,
            sourceOfferID: item.sourceOfferId
        )
    }

    private var currentSessionUserID: Int? {
        session.currentUser?.id ?? session.currentProfile?.user?.id
    }

    private func mapSourceType(_ raw: String) -> HangoutSourceType {
        switch raw.lowercased() {
        case "event":
            return .event
        case "offer":
            return .offer
        default:
            return .hangout
        }
    }

    private func mapVibe(_ raw: String) -> HangoutVibe {
        switch raw.lowercased() {
        case "drinks":
            return .drinks
        case "sporty", "outdoors":
            return .sporty
        case "food":
            return .foodie
        case "creative", "culture", "board games":
            return .activity
        case "deep talks":
            return .deepTalk
        default:
            return .chill
        }
    }

    private var backdrop: some View {
        ZStack {
            if usesExternalBackdrop {
                Rectangle()
                    .fill(Color(hex: "#F3F4FA").opacity(0.94))
                .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(Color(hex: "#F3F4FA"))
                    .ignoresSafeArea()
            }
        }
    }

    private var topIcons: some View {
        HStack {
            Button {
                isPresentingProfile = true
            } label: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Text(userInitials)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    }
                    .frame(width: 32, height: 32)
                    .padding(4)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                if creatorContext.userFlags.hasCreatorRole {
                    Button {
                        isPresentingCreatorSpace = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                            .frame(width: 40, height: 40)
                            .background(FriendZoneTheme.Colors.primarySoft)
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(FriendZoneTheme.Colors.primarySoftBorder, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isPresentingPlans = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.82))
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
        .padding(.top, FriendZoneTheme.Chrome.topOffset)
        .padding(.bottom, 6)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Text(session.isTravelModeActive ? "✈️" : "☀️")
                    .font(.system(size: 11))
                Text("\((session.activeCityName ?? "—").uppercased()) • \(clockLabel(now))")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1.1)
            }

            Button {
                isPresentingNotifications = true
            } label: {
                HStack(spacing: 7) {
                    if isRefreshingDiscovery {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(FriendZoneTheme.Colors.primary)
                        Text("Refreshing")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    } else {
                        liveUpdatesIndicator
                        Text("Live updates")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.lg, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, FriendZoneTheme.Chrome.sectionGap)
    }

    private var liveUpdatesIndicator: some View {
        Group {
            if hasUnreadNotifications {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.35) / 1.35
                    let wave = 0.5 - 0.5 * cos(cycle * .pi * 2)

                    ZStack {
                        Circle()
                            .fill(FriendZoneTheme.Colors.error.opacity(0.16 + 0.14 * wave))
                            .frame(width: 18, height: 18)
                            .scaleEffect(1.0 + 0.38 * wave)

                        Circle()
                            .fill(FriendZoneTheme.Colors.error)
                            .frame(width: 7, height: 7)
                            .scaleEffect(0.94 + 0.18 * wave)
                    }
                    .frame(width: 18, height: 18)
                }
            } else {
                Circle()
                    .fill(FriendZoneTheme.Colors.primary)
                    .frame(width: 6, height: 6)
                    .overlay {
                        Circle()
                            .stroke(FriendZoneTheme.Colors.primary.opacity(0.32), lineWidth: 6)
                    }
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            ForEach(DiscoveryMode.allCases) { mode in
                let isActive = mode == selectedMode
                Button {
                    selectedMode = mode
                    FriendZoneHaptics.selection()
                } label: {
                    Text(mode.title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            isActive
                                ? LinearGradient(
                                    colors: [FriendZoneTheme.Colors.primary.opacity(0.15), FriendZoneTheme.Colors.primaryAccent.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(colors: [Color.white.opacity(0.72), Color.white.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    isActive ? FriendZoneTheme.Colors.primarySoftBorder : FriendZoneTheme.Colors.borderSubtle,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FriendZoneTheme.Chrome.horizontalInset)
        .padding(.bottom, FriendZoneTheme.Chrome.sectionGap)
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(viewModel.weekDays, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: viewModel.selectedDay)
                    let isToday = calendar.isDateInToday(day)
                    let hasItems = hasItems(for: day)
                    Button {
                        viewModel.selectedDay = day
                        FriendZoneHaptics.selection()
                    } label: {
                        VStack(spacing: 3) {
                            Text(isToday ? "TODAY" : dayLabel(day))
                                .font(FriendZoneTheme.Typography.system(isToday ? 9 : 10, weight: .semibold))
                                .tracking(0.5)

                            Text(dateNumber(day))
                                .font(FriendZoneTheme.Typography.system(19, weight: .bold))

                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.7) : FriendZoneTheme.Colors.primary)
                                .frame(width: 4, height: 4)
                                .opacity(hasItems ? 1 : 0)
                        }
                        .foregroundColor(
                            isSelected
                                ? .white
                                : (isToday ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                        )
                        .frame(width: 46, height: 72)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [
                                            FriendZoneTheme.Colors.primary,
                                            FriendZoneTheme.Colors.primary.opacity(0.82)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                            } else if isToday {
                                Capsule()
                                    .fill(FriendZoneTheme.Colors.primarySoft)
                            } else {
                                Capsule()
                                    .fill(FriendZoneTheme.Colors.surface)
                            }
                        }
                        .shadow(
                            color: isSelected ? FriendZoneTheme.Colors.primary.opacity(0.28) : .clear,
                            radius: 10, x: 0, y: 4
                        )
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FriendZoneTheme.Spacing.md)
            .padding(.vertical, 4)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        HangoutCardSkeleton()
                    }
                }
                .padding(.horizontal, FriendZoneTheme.Spacing.md)
                .padding(.bottom, 28)
            }
        } else {
            switch selectedMode {
            case .hangouts:
                hangoutsContent
            case .events:
                eventsContent
            case .offers:
                offersContent
            }
        }
    }

    private var hangoutsContent: some View {
        let dayItems = viewModel.hangouts(on: viewModel.selectedDay)
        let listItems = dayItems.isEmpty ? Array(viewModel.futureHangouts.prefix(5)) : dayItems

        return Group {
            if viewModel.futureHangouts.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: FriendZoneTheme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(FriendZoneTheme.Colors.primarySoft)
                                .frame(width: 64, height: 64)
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.primary)
                        }

                        Text("No hangouts in your city yet")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                        Button("Create Hangout") {
                            pendingHangoutSource = .hangout
                            pendingHangoutSourceLabel = nil
                            pendingHangoutSourceEventID = nil
                            pendingHangoutSourceOfferID = nil
                            isPresentingCreate = true
                            FriendZoneHaptics.selection()
                        }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(FriendZoneTheme.Spacing.md)
                    .padding(.top, 48)
                }
                .refreshable {
                    await refreshSelectedDiscoveryMode()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(listItems) { hangout in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    selectedHangoutDetail = hangout
                                    FriendZoneHaptics.lightImpact()
                                } label: {
                                    hangoutSwappedCard(hangout)
                                }
                                .buttonStyle(HangoutCardButtonStyle())

                                Button {
                                    selectedMenuHangout = hangout
                                    isShowingHangoutMenu = true
                                    FriendZoneHaptics.selection()
                                } label: {
                                    Image(systemName: "ellipsis.vertical")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                        .frame(width: 22, height: 22)
                                        .background(Color.black.opacity(0.02))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, HangoutCardMetrics.contentPadding)
                                .padding(.top, HangoutCardMetrics.contentPadding + 2)
                                .zIndex(2)
                            }
                        }
                    }
                    .padding(.horizontal, FriendZoneTheme.Spacing.md)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await refreshSelectedDiscoveryMode()
                }
            }
        }
    }

    private var eventsContent: some View {
        let dayItems = discoveryEvents.filter { calendar.isDate($0.startAt, inSameDayAs: viewModel.selectedDay) }
        let listItems = dayItems.isEmpty ? Array(discoveryEvents.prefix(5)) : dayItems

        return Group {
            if listItems.isEmpty {
                ScrollView(showsIndicators: false) {
                    discoveryEmptyState(
                        icon: "music.note.list",
                        title: "No events available",
                        description: discoveryErrorMessage ?? "There are no live event results from the backend right now."
                    )
                    .padding(.top, 48)
                }
                .refreshable {
                    await refreshSelectedDiscoveryMode()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(listItems) { event in
                            Button {
                                selectedEventDetail = event
                                FriendZoneHaptics.selection()
                            } label: {
                                HangoutCardView(hangout: eventAsHangoutTicket(event), now: now)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, FriendZoneTheme.Spacing.md)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await refreshSelectedDiscoveryMode()
                }
            }
        }
    }

    private var offersContent: some View {
        let dayItems = discoveryOffers.filter { calendar.isDate($0.validUntil, inSameDayAs: viewModel.selectedDay) }
        let listItems = dayItems.isEmpty ? discoveryOffers : dayItems

        return Group {
            if listItems.isEmpty {
                ScrollView(showsIndicators: false) {
                    discoveryEmptyState(
                        icon: "ticket",
                        title: "No offers available",
                        description: discoveryErrorMessage ?? "There are no live offer results from the backend right now."
                    )
                    .padding(.top, 48)
                }
                .refreshable {
                    await refreshSelectedDiscoveryMode()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendZoneTheme.Spacing.sm) {
                        ForEach(listItems) { offer in
                            Button {
                                selectedOfferDetail = offer
                                FriendZoneHaptics.selection()
                            } label: {
                                DiscoveryOfferVoucherCardView(offer: offer)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, FriendZoneTheme.Spacing.md)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await refreshSelectedDiscoveryMode()
                }
            }
        }
    }

    private func discoveryEmptyState(icon: String, title: String, description: String) -> some View {
        VStack(spacing: FriendZoneTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(FriendZoneTheme.Colors.primarySoft)
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
            }

            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(description)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(FriendZoneTheme.Spacing.md)
    }

    private func hangoutSwappedCard(_ hangout: HangoutItem) -> some View {
        DiscoverHangoutCardView(hangout: hangout)
    }

    private func discoverHangoutDetailSheet(_ hangout: HangoutItem) -> some View {
        HangoutDetailView(
            hangout: hangout,
            joinStatus: viewModel.joinStatus(for: hangout),
            onRequestJoin: {
                viewModel.requestJoin(for: hangout)
                FriendZoneHaptics.success()
            },
            onCancelRequest: {
                viewModel.cancelJoinRequest(for: hangout)
                FriendZoneHaptics.selection()
            },
            onClose: {
                selectedHangoutDetail = nil
                FriendZoneHaptics.selection()
            },
            closeButtonSystemName: "chevron.down"
        )
        .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func offerCard(_ offer: DiscoveryOfferItem) -> some View {
        DiscoveryOfferVoucherCardView(offer: offer)
    }

    private func offerCouponCode(_ offer: DiscoveryOfferItem) -> String {
        let title = offer.title.uppercased()
        if title.contains("2X1") { return "2x1" }
        if title.contains("ROOFTOP") { return "VIP" }
        if title.contains("RAMEN") { return "LATE" }
        return "DEAL"
    }

    private func sourceTagTitle(for sourceType: HangoutSourceType) -> String? {
        switch sourceType {
        case .hangout:
            return nil
        case .event:
            return "FROM EVENT"
        case .offer:
            return "FROM OFFER"
        }
    }

    private func sourceTagTint(for sourceType: HangoutSourceType) -> Color {
        switch sourceType {
        case .hangout:
            return FriendZoneTheme.Colors.textSecondary
        case .event:
            return Color(hex: "#0E7490")
        case .offer:
            return Color(hex: "#B45309")
        }
    }

    private func accentColor(for hangout: HangoutItem) -> Color {
        switch hangout.vibe {
        case .chill:
            return Color(hex: "#667EEA")
        case .drinks:
            return Color(hex: "#F59E0B")
        case .deepTalk:
            return Color(hex: "#8B5CF6")
        case .activity:
            return Color(hex: "#10B981")
        case .foodie:
            return Color(hex: "#EF4444")
        case .sporty:
            return Color(hex: "#0EA5E9")
        }
    }

    private func eventAsHangoutTicket(_ event: DiscoveryEventItem) -> HangoutItem {
        let capacity = max(event.groups + 4, 8)
        let approved = min(max(1, event.groups), capacity)
        let vibe = vibeForEventCategory(event.category)

        return HangoutItem(
            id: 9000 + event.id,
            sourceType: .event,
            title: event.title,
            description: "Event ticket for \(event.venue).",
            vibe: vibe,
            cityName: "Berlin",
            locationName: nil,
            hostUserID: nil,
            hostName: "Event host",
            startAt: event.startAt,
            endAt: event.startAt.addingTimeInterval(2 * 60 * 60),
            capacity: capacity,
            approvedCount: approved,
            isJoined: false,
            participantNames: [],
            coverImageData: nil,
            coverSeed: event.id % 10,
            distanceKm: 1.8,
            priceTier: .budget
        )
    }

    private func vibeForEventCategory(_ category: String) -> HangoutVibe {
        switch category.lowercased() {
        case "music", "party":
            return .drinks
        case "culture", "networking":
            return .deepTalk
        case "sports", "outdoor":
            return .sporty
        case "food":
            return .foodie
        case "tech":
            return .activity
        default:
            return .chill
        }
    }

    private var createFAB: some View {
        Button {
            pendingHangoutSource = .hangout
            pendingHangoutSourceLabel = nil
            pendingHangoutSourceEventID = nil
            pendingHangoutSourceOfferID = nil
            isPresentingCreate = true
            FriendZoneHaptics.selection()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(FriendZoneTheme.Colors.primary)
                .clipShape(Circle())
                .shadow(color: FriendZoneTheme.Colors.primary.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 96)
    }

    private func hasItems(for day: Date) -> Bool {
        switch selectedMode {
        case .hangouts:
            return viewModel.hasHangouts(on: day)
        case .events:
            return discoveryEvents.contains(where: { calendar.isDate($0.startAt, inSameDayAs: day) })
        case .offers:
            return discoveryOffers.contains(where: { calendar.isDate($0.validUntil, inSameDayAs: day) })
        }
    }

    private var userInitials: String {
        if let first = session.currentProfile?.user?.firstName?.prefix(1), !first.isEmpty {
            return first.uppercased()
        }
        if let first = session.currentUser?.firstName?.prefix(1), !first.isEmpty {
            return first.uppercased()
        }
        return String(session.currentUser?.username.prefix(1).uppercased() ?? "?")
    }

    private func clockLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func dayLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: value).uppercased()
    }

    private func eventDayLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func dateNumber(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: value)
    }
}

struct NativeEventDetailView: View {
    @EnvironmentObject private var session: AppSessionStore
    let event: HangoutsView.DiscoveryEventItem
    let creatorProfile: CreatorProfileDraft
    let onClose: () -> Void
    let onJoinSoloSuccess: () -> Void
    let onCreateHangout: () -> Void
    let onShowCreatorProfile: () -> Void
    @State private var isShowingTicketPreview = false
    @State private var selectedHeroPage = 0
    @State private var detail: EventDetailFeedItem?
    @State private var isJoiningSolo = false
    @State private var joinFeedbackMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                FriendZoneModuleHeader(
                    leadingText: "Event ",
                    highlightText: "Details"
                )

                VStack(spacing: 14) {
                    eventHeroPager
                    creatorSection
                    infoBlock(
                        title: "ABOUT THIS EVENT",
                        body: eventAboutText
                    )
                    infoBlock(
                        title: "WHAT TO EXPECT",
                        body: eventExpectText
                    )
                    DetailActionsRow(
                        onJoinSolo: {
                            Task { await joinSolo() }
                        },
                        onCreateHangout: onCreateHangout,
                        isJoinSoloLoading: isJoiningSolo,
                        onPreviewTicket: {
                            isShowingTicketPreview = true
                        }
                    )

                    if let joinFeedbackMessage {
                        Text(joinFeedbackMessage)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
        .sheet(isPresented: $isShowingTicketPreview) {
            TicketPreviewSheet(ticket: TicketModel.from(event: event))
        }
    }

    private var eventHeroPager: some View {
        VStack(spacing: 10) {
            TabView(selection: $selectedHeroPage) {
                TicketFrontView(
                    ticket: TicketModel.from(event: event),
                    showActions: false,
                    isExporting: false,
                    onShowCode: {},
                    onDownloadPDF: {}
                )
                .padding(.horizontal, 1)
                .tag(0)

                ForEach(Array(heroMoments.enumerated()), id: \.element.id) { index, moment in
                    EventPhotoTicketView(event: event, moment: moment)
                        .tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 214)

            if !heroMoments.isEmpty {
                HStack(spacing: 8) {
                    Text(selectedHeroPage == 0 ? "Ticket" : "Event photos")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                    Spacer()

                    Text("Swipe left")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)

                    HStack(spacing: 5) {
                        ForEach(0..<(heroMoments.count + 1), id: \.self) { page in
                            Capsule()
                                .fill(page == selectedHeroPage ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderSubtle)
                                .frame(width: page == selectedHeroPage ? 18 : 6, height: 6)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var heroMoments: [HangoutsView.EventPhotoMoment] {
        if let detail {
            let detailMoments = detail.photos
                .sorted {
                    ($0.sortOrder ?? Int.max, $0.id) < ($1.sortOrder ?? Int.max, $1.id)
                }
                .filter { ($0.imageUrl ?? "").isEmpty == false }
                .map { photo in
                    HangoutsView.EventPhotoMoment(
                        id: photo.id,
                        title: detail.title,
                        subtitle: detail.venueName ?? event.venue,
                        symbol: "photo",
                        palette: [Color(hex: "#171717"), Color(hex: "#404040"), Color(hex: "#A3A3A3")],
                        imageURL: photo.imageUrl
                    )
                }
            if !detailMoments.isEmpty {
                return detailMoments
            }
        }
        return event.photoMoments
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.category.uppercased())
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(Color(hex: "#0E7490"))
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(Color(hex: "#0E7490").opacity(0.10))
                    .clipShape(Capsule())

                Spacer()

                Text("\(event.groups) groups")
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            Text(event.title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text("by \(event.venue)")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                eventMetaChip(icon: "calendar", text: eventDateLabel(event.startAt))
                eventMetaChip(icon: "clock.fill", text: eventTimeLabel(event.startAt))
            }
        }
        .padding(14)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#0E7490").opacity(0.22), lineWidth: 1)
        }
    }

    private var creatorSection: some View {
        Button {
            onShowCreatorProfile()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(FriendZoneTheme.Colors.primarySoft)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(creatorProfile.initial)
                            .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Event creator")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.8)
                    Text(detail?.organizerName ?? detail?.creatorDisplayName ?? creatorProfile.displayName)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            .padding(12)
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func infoBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.9)

            Text(body)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineSpacing(1.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func eventMetaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
        }
        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func eventDateLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }

    private func eventTimeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private var eventAboutText: String {
        if let description = detail?.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return description
        }
        return "A curated \(event.category.lowercased()) experience at \(event.venue), designed for people who want to meet through shared vibes and real conversation."
    }

    private var eventExpectText: String {
        var parts: [String] = []
        if let address = detail?.venueAddress, !address.isEmpty {
            parts.append("Venue: \(address).")
        }
        if let participants = detail?.totalParticipants {
            parts.append("\(participants) people already connected around this event.")
        }
        if let spots = detail?.spotsRemaining {
            parts.append(spots > 0 ? "\(spots) spots still available for solo joins and side hangouts." : "Capacity is currently full.")
        }
        if let tags = detail?.tags, !tags.isEmpty {
            parts.append("Tags: \(tags.prefix(4).joined(separator: ", ")).")
        }
        if parts.isEmpty {
            return "Live social energy, curated spaces, and active mini-groups. You can join nearby hangouts related to this event before and after it starts."
        }
        return parts.joined(separator: " ")
    }

    @MainActor
    private func loadDetail() async {
        guard detail == nil else { return }
        do {
            detail = try await session.fetchEventDetail(id: event.id)
        } catch {
            // Keep minimal discovery payload as fallback.
        }
    }

    @MainActor
    private func joinSolo() async {
        guard !isJoiningSolo else { return }
        isJoiningSolo = true
        defer { isJoiningSolo = false }

        do {
            try await session.joinEventSolo(id: event.id)
            joinFeedbackMessage = "Solo join confirmed."
            FriendZoneHaptics.success()
            onJoinSoloSuccess()
        } catch {
            joinFeedbackMessage = error.localizedDescription
        }
    }
}

private struct EventPhotoTicketView: View {
    let event: HangoutsView.DiscoveryEventItem
    let moment: HangoutsView.EventPhotoMoment

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backgroundLayer

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 168, height: 168)
                .blur(radius: 2)
                .offset(x: 68, y: -44)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("EVENT MOMENT")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.82))
                        .tracking(0.8)

                    Spacer()

                    Image(systemName: moment.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                }

                Spacer(minLength: 0)

                Text(moment.title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(moment.subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.84))
                    .lineLimit(2)

                HStack {
                    Label(event.venue, systemImage: "mappin.and.ellipse")
                    Spacer()
                    Label(event.category, systemImage: "ticket.fill")
                }
                .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.92))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 184)
        .mask(TicketSilhouetteMask())
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.20), lineWidth: FriendZoneTheme.BorderWidth.thin)
                .mask(TicketSilhouetteMask())
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let imageURL = moment.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    LinearGradient(
                        colors: moment.palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        } else {
            LinearGradient(
                colors: moment.palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct DiscoveryOfferVoucherCardView: View {
    let offer: HangoutsView.DiscoveryOfferItem
    var animateEntrance: Bool = true

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("VOUCHER")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .foregroundColor(Color(hex: "#B45309"))
                        .padding(.horizontal, 8)
                        .frame(height: 18)
                        .background(Color(hex: "#F59E0B").opacity(0.14))
                        .clipShape(Capsule())

                    Text(offer.venue)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                    Spacer()
                }

                Text(offer.title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(offer.perk)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)

                Text("Valid until \(dayLabel)")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                ForEach(0 ..< 14, id: \.self) { _ in
                    Circle()
                        .fill(Color(hex: "#F59E0B").opacity(0.32))
                        .frame(width: 2.2, height: 2.2)
                }
            }
            .frame(width: 3)
            .padding(.horizontal, 8)

            VStack(spacing: 6) {
                Text(couponCode)
                    .font(FriendZoneTheme.Typography.system(18, weight: .heavy))
                    .foregroundColor(Color(hex: "#B45309"))

                Text("COUPON")
                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(0.6)

                Text(offer.spotsLeft > 0 ? "\(offer.spotsLeft) LEFT" : "FULL")
                    .font(FriendZoneTheme.Typography.system(9, weight: .bold))
                    .foregroundColor(offer.spotsLeft > 0 ? Color(hex: "#B45309") : FriendZoneTheme.Colors.error)
            }
            .frame(width: 74)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFF8E6"), FriendZoneTheme.Colors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [6, 4]))
                .foregroundColor(Color(hex: "#F59E0B").opacity(0.58))
        }
        .overlay {
            GeometryReader { proxy in
                let r: CGFloat = 9
                let y = proxy.size.height * 0.5
                ZStack {
                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: 0, y: y)
                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: proxy.size.width, y: y)
                }
            }
        }
        .opacity(animateEntrance ? (hasAppeared ? 1 : 0) : 1)
        .offset(y: animateEntrance ? (hasAppeared ? 0 : 12) : 0)
        .onAppear {
            guard animateEntrance, !hasAppeared else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                hasAppeared = true
            }
        }
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: offer.validUntil)
    }

    private var couponCode: String {
        let title = offer.title.uppercased()
        if title.contains("2X1") { return "2x1" }
        if title.contains("ROOFTOP") { return "VIP" }
        if title.contains("RAMEN") { return "LATE" }
        return "DEAL"
    }
}

struct NativeOfferDetailView: View {
    @EnvironmentObject private var session: AppSessionStore
    let offer: HangoutsView.DiscoveryOfferItem
    let venueProfile: CreatorProfileDraft
    let onClose: () -> Void
    let onJoinSolo: () -> Void
    let onCreateHangout: () -> Void
    let onShowVenueProfile: () -> Void
    @State private var isShowingTicketPreview = false
    @State private var detail: OfferDetailFeedItem?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                FriendZoneModuleHeader(
                    leadingText: "Offer ",
                    highlightText: "Details"
                )

                VStack(spacing: 14) {
                    DiscoveryOfferVoucherCardView(offer: offer, animateEntrance: false)
                    venueSection
                    infoBlock(
                        title: "PERK",
                        body: detail?.perk ?? offer.perk
                    )
                    infoBlock(
                        title: "HOW TO REDEEM",
                        body: redeemText
                    )
                    infoBlock(
                        title: "TERMS",
                        body: termsText
                    )
                    DetailActionsRow(
                        onJoinSolo: onJoinSolo,
                        onCreateHangout: onCreateHangout,
                        isJoinSoloLoading: false,
                        onPreviewTicket: {
                            isShowingTicketPreview = true
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Offer")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
        .sheet(isPresented: $isShowingTicketPreview) {
            TicketPreviewSheet(ticket: TicketModel.from(offer: offer))
        }
    }

    private var offerCouponCode: String {
        let title = offer.title.uppercased()
        if title.contains("2X1") { return "2x1" }
        if title.contains("ROOFTOP") { return "VIP" }
        if title.contains("RAMEN") { return "LATE" }
        return "DEAL"
    }

    private var venueSection: some View {
        Button {
            onShowVenueProfile()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(FriendZoneTheme.Colors.primarySoft)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(venueProfile.initial)
                            .font(FriendZoneTheme.Typography.system(18, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Venue")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.8)
                    Text(detail?.venueName ?? detail?.venueDetail?.name ?? venueProfile.displayName)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            .padding(12)
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func infoBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.9)

            Text(body)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineSpacing(1.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func offerMetaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func eventDateLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }

    private func eventTimeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private var redeemText: String {
        let venueName = detail?.venueName ?? detail?.venueDetail?.name ?? offer.venue
        if let description = detail?.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return "\(description) Redeem directly at \(venueName)."
        }
        return "Show this voucher code at \(venueName). Subject to availability and venue terms."
    }

    private var termsText: String {
        if let terms = detail?.terms?.trimmingCharacters(in: .whitespacesAndNewlines), !terms.isEmpty {
            return terms
        }
        return "One redeem per person. Non-transferable. Valid until \(eventDateLabel(offer.validUntil)) at \(eventTimeLabel(offer.validUntil))."
    }

    @MainActor
    private func loadDetail() async {
        guard detail == nil else { return }
        do {
            detail = try await session.fetchOfferDetail(id: offer.id)
        } catch {
            // Keep minimal discovery payload as fallback.
        }
    }
}

private struct DetailActionsRow: View {
    let onJoinSolo: () -> Void
    let onCreateHangout: () -> Void
    var isJoinSoloLoading: Bool = false
    let onPreviewTicket: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onJoinSolo) {
                Text(isJoinSoloLoading ? "Joining..." : "Join Solo")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(FriendZoneTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isJoinSoloLoading)

            Button(action: onCreateHangout) {
                Text("Create Hangout")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if let onPreviewTicket {
                Button(action: onPreviewTicket) {
                    Text("Preview ticket")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.primary, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HangoutCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct HangoutCardView: View {
    let hangout: HangoutItem
    let now: Date
    var animateEntrance: Bool = true
    var compactHostInfo: Bool = false
    var previewCompactLayout: Bool = false

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            leftContent
                .padding(.leading, horizontalContentPadding)
                .padding(.trailing, rightContentPadding)
                .padding(.vertical, verticalContentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)

            perforationStrip
                .padding(.vertical, previewCompactLayout ? 10 : 12)

            rightStub
                .frame(width: previewCompactLayout ? 82 : HangoutCardMetrics.stubWidth)
                .padding(.leading, previewCompactLayout ? 7 : 8)
                .padding(.trailing, horizontalContentPadding)
                .padding(.vertical, verticalContentPadding)
        }
        .frame(maxWidth: .infinity, minHeight: previewCompactLayout ? 178 : HangoutCardMetrics.minHeight)
        .background(FriendZoneTheme.Colors.surface)
        .mask(ticketClipMask)
        .overlay {
            RoundedRectangle(cornerRadius: HangoutCardMetrics.cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: FriendZoneTheme.BorderWidth.thin)
                .mask(ticketClipMask)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        .opacity(animateEntrance ? (hasAppeared ? 1 : 0) : 1)
        .offset(y: animateEntrance ? (hasAppeared ? 0 : 14) : 0)
        .onAppear {
            guard animateEntrance, !hasAppeared else { return }
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86).delay(Double(hangout.id % 5) * 0.025)) {
                hasAppeared = true
            }
        }
    }

    private var leftContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ticketTopLabel
                .padding(.bottom, previewCompactLayout ? 6 : 8)

            if let coverUIImage {
                coverStrip(coverUIImage)
                    .padding(.bottom, previewCompactLayout ? 8 : 10)
            }

            Text(hangout.title)
                .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 15 : FriendZoneTheme.Typography.sizeBase, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.bottom, previewCompactLayout ? 4 : 5)

            if !hangout.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(hangout.description)
                    .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 10 : 11, weight: .regular))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.bottom, previewCompactLayout ? 7 : 9)
            } else {
                Spacer()
                    .frame(height: previewCompactLayout ? 2 : 4)
            }

            cityVenueRow
                .padding(.bottom, previewCompactLayout ? 7 : 9)

            hostInfoRow
                .padding(.bottom, previewCompactLayout ? 4 : (compactHostInfo ? 5 : 7))

            footerRow
        }
    }

    private func coverStrip(_ image: Image) -> some View {
        ZStack {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(height: previewCompactLayout ? 52 : 58)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var cityVenueRow: some View {
        HStack(spacing: 5) {
            Image(systemName: hangout.hasUnlockedLocation ? "mappin.and.ellipse" : "lock.circle")
                .font(.system(size: previewCompactLayout ? 9 : 10, weight: .bold))
                .foregroundColor(hangout.hasUnlockedLocation ? FriendZoneTheme.Colors.textTertiary : FriendZoneTheme.Colors.primary)

            Text(hangout.publicLocationDisplay)
                .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 9 : 10, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private var ticketTopLabel: some View {
        Text(ticketTopTitle)
            .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 9 : 10, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            .tracking(0.8)
    }

    private var perforationStrip: some View {
        VStack(spacing: 4) {
            ForEach(0 ..< 18, id: \.self) { _ in
                Circle()
                    .fill(FriendZoneTheme.Colors.borderSubtle.opacity(0.95))
                    .frame(width: 2.5, height: 2.5)
            }
        }
        .frame(width: 3)
    }

    private var rightStub: some View {
        VStack(spacing: previewCompactLayout ? 6 : 7) {
            Text(timeRemainingText(from: now, to: hangout.startAt) ?? "SOON")
                .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 16 : 17, weight: .heavy))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .padding(.horizontal, previewCompactLayout ? 7 : 8)
                .frame(height: previewCompactLayout ? 24 : 26)
                .background(accentColor.opacity(0.14))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(accentColor.opacity(0.28), lineWidth: 1)
                }

            Text(timeLabel(hangout.startAt))
                .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 10 : 11, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(shortDateLabel(hangout.startAt))
                .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 8 : 9, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(hangout.isFull ? "Full" : "\(hangout.spotsLeft) Left")
                .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 8 : 9, weight: .bold))
                .foregroundColor(hangout.isFull ? FriendZoneTheme.Colors.error : accentColor)
                .padding(.top, previewCompactLayout ? 1 : 2)

            Text(ticketCode)
                .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 7 : 8, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var ticketClipMask: some View {
        RoundedRectangle(cornerRadius: HangoutCardMetrics.cornerRadius, style: .continuous)
            .fill(Color.white)
            .overlay {
                ticketPunchHoles
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private var ticketPunchHoles: some View {
        GeometryReader { proxy in
            let sideRadius = HangoutCardMetrics.edgeScallopRadius
            let centerRadius = HangoutCardMetrics.notchRadius
            let centerX = proxy.size.width * 0.5
            let topInset: CGFloat = 14
            let bottomInset: CGFloat = 14
            let usableHeight = max(0, proxy.size.height - topInset - bottomInset)
            let step = usableHeight / CGFloat(max(1, HangoutCardMetrics.edgeScallopCount - 1))

            ZStack {
                ForEach(0 ..< HangoutCardMetrics.edgeScallopCount, id: \.self) { index in
                    let y = topInset + CGFloat(index) * step

                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: 0, y: y)

                    Circle()
                        .fill(FriendZoneTheme.Colors.background)
                        .frame(width: sideRadius * 2, height: sideRadius * 2)
                        .position(x: proxy.size.width, y: y)
                }

                Circle()
                    .fill(FriendZoneTheme.Colors.background)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: 0)

                Circle()
                    .fill(FriendZoneTheme.Colors.background)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .position(x: centerX, y: proxy.size.height)
            }
        }
    }

    @ViewBuilder
    private var hostInfoRow: some View {
        if previewCompactLayout {
            HStack(spacing: 4) {
                Text(hangout.hostName.lowercased() == "you" ? "👑" : "🎯")
                Text("by \(hangout.hostName)")
                    .lineLimit(1)
            }
            .font(FriendZoneTheme.Typography.system(9, weight: .semibold))
            .foregroundColor(hangout.hostName.lowercased() == "you" ? accentColor : FriendZoneTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(accentColor.opacity(0.38))
                    .frame(width: 2)

                HStack(spacing: compactHostInfo ? 3 : 4) {
                    Text(hangout.hostName.lowercased() == "you" ? "👑" : "🎯")
                    Text("Hosted by \(hangout.hostName)")
                }
                .font(FriendZoneTheme.Typography.system(compactHostInfo ? 10 : 11, weight: .semibold))
                .foregroundColor(hangout.hostName.lowercased() == "you" ? accentColor : FriendZoneTheme.Colors.textSecondary)
                .padding(.horizontal, compactHostInfo ? 6 : 7)
                .padding(.vertical, compactHostInfo ? 2 : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.sm, style: .continuous))
        }
    }

    private var footerRow: some View {
        HStack(alignment: .center) {
            participantRow

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
    }

    private var participantRow: some View {
        Group {
            if hangout.participantNames.isEmpty {
                Text("No participants so far")
                    .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 8 : 9, weight: .regular))
                    .italic()
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            } else {
                HStack(spacing: -8) {
                    ForEach(Array(hangout.participantNames.prefix(3).enumerated()), id: \.offset) { _, name in
                        participantAvatar(name)
                    }
                    if hangout.participantNames.count > 3 {
                        Text("+\(hangout.participantNames.count - 3)")
                            .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 8 : 9, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            .frame(width: previewCompactLayout ? 24 : 26, height: previewCompactLayout ? 24 : 26)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(FriendZoneTheme.Colors.surface, lineWidth: 2)
                            }
                    }
                }
            }
        }
    }

    private func participantAvatar(_ name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(FriendZoneTheme.Typography.system(previewCompactLayout ? 8 : FriendZoneTheme.Typography.size2XS, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textInverse)
            .frame(width: previewCompactLayout ? 24 : 26, height: previewCompactLayout ? 24 : 26)
            .background(
                LinearGradient(
                    colors: [accentColor, FriendZoneTheme.Colors.primaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .overlay {
                Circle().stroke(FriendZoneTheme.Colors.surface, lineWidth: 2)
            }
    }

    private var horizontalContentPadding: CGFloat {
        previewCompactLayout ? 9 : HangoutCardMetrics.contentPadding
    }

    private var verticalContentPadding: CGFloat {
        previewCompactLayout ? 9 : HangoutCardMetrics.contentPadding
    }

    private var rightContentPadding: CGFloat {
        previewCompactLayout ? 8 : 9
    }

    private func timeRemainingText(from now: Date, to date: Date) -> String? {
        let diff = Int(date.timeIntervalSince(now))
        if diff <= 0 { return nil }
        let minutes = diff / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func shortDateLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: value).uppercased()
    }

    private var cityCode: String {
        let normalized = hangout.cityName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let knownCodes: [String: String] = [
            "munich": "MUC",
            "munchen": "MUC",
            "münchen": "MUC",
            "berlin": "BER",
            "madrid": "MAD",
            "barcelona": "BCN",
            "paris": "PAR",
            "london": "LON",
            "lisbon": "LIS",
            "rome": "ROM",
            "amsterdam": "AMS",
            "new york": "NYC",
            "los angeles": "LAX",
            "miami": "MIA"
        ]
        if let code = knownCodes[normalized] {
            return code
        }
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        if compact.isEmpty {
            return "CITY"
        }
        return String(compact.prefix(3)).uppercased()
    }

    private var coverUIImage: Image? {
        guard let data = hangout.coverImageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private var ticketCode: String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: hangout.startAt)
        let day = String(format: "%02d", components.day ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let year = String(components.year ?? 0)
        return "\(cityCode)-\(day)-\(month)-\(hangout.id)-\(year)"
    }

    private var ticketTopTitle: String {
        switch hangout.sourceType {
        case .hangout:
            return "HANGOUT"
        case .event:
            return "EVENT"
        case .offer:
            return "OFFER"
        }
    }

    private var accentColor: Color {
        switch hangout.vibe {
        case .chill: return Color(hex: "#667EEA")
        case .drinks: return Color(hex: "#F59E0B")
        case .deepTalk: return Color(hex: "#8B5CF6")
        case .activity: return Color(hex: "#10B981")
        case .foodie: return Color(hex: "#EF4444")
        case .sporty: return Color(hex: "#0EA5E9")
        }
    }

}

private struct HangoutCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(width: 150, height: 16)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(height: 14)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(height: 11)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FriendZoneTheme.Colors.surfaceMuted)
                .frame(width: 120, height: 22)
        }
        .padding(11)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FriendZoneTheme.Radius.xl, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: FriendZoneTheme.BorderWidth.thin)
        }
    }
}

private struct PublicProfileRequest: Identifiable {
    let id = UUID()
    let profile: PublicProfileData
    let leadingText: String
    let highlightText: String
    let subtitle: String?
}

private enum HangoutCardMetrics {
    static let contentPadding: CGFloat = 11
    static let cornerRadius: CGFloat = 16
    static let minHeight: CGFloat = 184
    static let stubWidth: CGFloat = 88
    static let notchRadius: CGFloat = 10
    static let edgeScallopRadius: CGFloat = 5.2
    static let edgeScallopCount: Int = 9
}

private struct NativeProfileView: View {
    let onClose: () -> Void
    @State private var showPastHangouts = true
    @State private var showCity = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)
                        .overlay {
                            Text("S")
                                .font(FriendZoneTheme.Typography.system(32, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        }

                    Text("safaeralabs")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text(showCity ? "Berlin, DE" : "City hidden")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    profileStatCard(title: "Attended", value: "37")
                    profileStatCard(title: "Hosted", value: "12")
                    profileStatCard(title: "Rating", value: "4.9")
                }

                VStack(spacing: 10) {
                    NavigationLink {
                        NativeEditProfileView()
                    } label: {
                        profileRowLabel(
                            icon: "pencil.circle.fill",
                            title: "Edit profile",
                            subtitle: "Name, bio, city and preferences"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativeMessagesView()
                    } label: {
                        profileRowLabel(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Messages",
                            subtitle: "Recent conversations and requests"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativeSettingsView(onClose: onClose)
                    } label: {
                        profileRowLabel(
                            icon: "gearshape.fill",
                            title: "Settings",
                            subtitle: "Privacy, account and notifications"
                        )
                    }
                    .buttonStyle(.plain)

                    profileToggleRow(
                        icon: "clock.arrow.circlepath",
                        title: "Show past hangouts",
                        subtitle: "Display history on your profile",
                        isOn: $showPastHangouts
                    )

                    profileToggleRow(
                        icon: "mappin.circle.fill",
                        title: "Show city",
                        subtitle: "Visible to people in matches and hangouts",
                        isOn: $showCity
                    )
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private func profileStatCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func profileRowLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func profileToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(FriendZoneTheme.Colors.primary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativeSettingsView: View {
    let onClose: () -> Void
    @State private var pushNotifications = true
    @State private var reminderNotifications = true
    @State private var soundEffects = true
    @State private var haptics = true
    @State private var privateAccount = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                settingsSection(
                    title: "Notifications",
                    rows: [
                        .toggle("Push notifications", "New matches and join requests", $pushNotifications),
                        .toggle("Reminders", "Upcoming hangouts and events", $reminderNotifications)
                    ]
                )

                settingsSection(
                    title: "Experience",
                    rows: [
                        .toggle("Sound effects", "UI interaction sounds", $soundEffects),
                        .toggle("Haptics", "Subtle vibration feedback", $haptics)
                    ]
                )

                settingsSection(
                    title: "Privacy",
                    rows: [
                        .toggle("Private account", "Only accepted people can see details", $privateAccount)
                    ]
                )

                VStack(spacing: 10) {
                    NavigationLink {
                        NativeHelpView()
                    } label: {
                        settingsNavRow(
                            icon: "questionmark.circle.fill",
                            title: "Help Center",
                            subtitle: "FAQs and how FriendZone works"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativePrivacyView()
                    } label: {
                        settingsNavRow(
                            icon: "lock.shield.fill",
                            title: "Privacy Policy",
                            subtitle: "How we store and process your data"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NativeTermsView()
                    } label: {
                        settingsNavRow(
                            icon: "doc.text.fill",
                            title: "Terms of Service",
                            subtitle: "Rules and legal terms"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                } label: {
                    Text("Log out")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(FriendZoneTheme.Colors.error)
            }
            .padding(16)
            .padding(.bottom, 22)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private func settingsSection(title: String, rows: [SettingsRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            Text(row.subtitle)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: row.binding)
                            .labelsHidden()
                            .tint(FriendZoneTheme.Colors.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if row.id != rows.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
        }
    }

    private func settingsNavRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativeNotificationsView: View {
    let onClose: () -> Void

    private let items: [NotificationItem] = [
        .init(id: 1, icon: "person.2.fill", tone: .primary, title: "New match forming", detail: "3 people are in for Coffee and Co-Work", time: "2m"),
        .init(id: 2, icon: "checkmark.seal.fill", tone: .success, title: "Join request approved", detail: "You are accepted in Street Photo Walk", time: "14m"),
        .init(id: 3, icon: "bell.badge.fill", tone: .warning, title: "Hangout starts soon", detail: "Sunset Rooftop Drinks starts in 30 min", time: "31m")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(toneColor(item.tone))
                            .frame(width: 34, height: 34)
                            .background(toneColor(item.tone).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                            Text(item.detail)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        }

                        Spacer()

                        Text(item.time)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    }
                    .padding(12)
                    .background(FriendZoneTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 22)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private func toneColor(_ tone: NotificationTone) -> Color {
        switch tone {
        case .primary: return FriendZoneTheme.Colors.primary
        case .success: return FriendZoneTheme.Colors.success
        case .warning: return FriendZoneTheme.Colors.warning
        }
    }
}

private enum NotificationTone {
    case primary
    case success
    case warning
}

private struct NotificationItem: Identifiable {
    let id: Int
    let icon: String
    let tone: NotificationTone
    let title: String
    let detail: String
    let time: String
}

private struct NativeProfileHubView: View {
    let onClose: () -> Void

    @EnvironmentObject private var session: AppSessionStore
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarUploadError: String?
    @State private var isPresentingCompletionSheet = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                FriendZoneModuleHeader(
                    leadingText: "Your social ",
                    highlightText: "passport"
                )
                .padding(.top, FriendZoneTheme.Chrome.topOffset)

                VStack(spacing: 14) {
                    profileCard
                    completionCard
                    sectionCard(title: "NUMBERS", subtitle: "Your live profile counters") {
                        statsGrid
                    }
                    sectionCard(title: "SHORTCUTS", subtitle: "Jump into the things you use most") {
                        quickActions
                    }
                    if !profileIntentions.isEmpty {
                        chipsSection(title: profileIntentionsTitle, items: profileIntentions)
                    }
                    if !profileAvailability.isEmpty {
                        chipsSection(title: "AVAILABILITY", items: profileAvailability)
                    }
                    chipsSection(title: "VIBES", items: profileVibes)
                    interestChipsSection(title: "INTERESTS", items: profileInterests)
                    chipsSection(title: "LANGUAGES", items: profileLanguages)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
        .sheet(isPresented: $isPresentingCompletionSheet) {
            NativeProfileCompletionSheet()
                .environmentObject(session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedAvatarItem) { item in
            guard let item else { return }
            Task {
                await uploadAvatar(from: item)
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                PhotosPicker(selection: $selectedAvatarItem, matching: .images, photoLibrary: .shared()) {
                    ZStack(alignment: .bottomTrailing) {
                        avatarCircle

                        Circle()
                            .fill(FriendZoneTheme.Colors.surface)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: isUploadingAvatar ? "arrow.triangle.2.circlepath" : "camera.fill")
                                    .font(.system(size: 13, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.primary)
                            }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    Text("SOCIAL PASSPORT")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(1.1)

                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                        if session.currentProfile?.verifiedProfile == true {
                            profileMetaChip("✔︎ Verified")
                        }
                    }

                    Text("@\(username)")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    profileMetaChip("📍 \(cityLabel)")
                    if let genderChip {
                        profileMetaChip(genderChip)
                    }
                    if let groupSizeChip {
                        profileMetaChip(groupSizeChip)
                    }
                    if let completionScore = session.currentProfile?.completionScore {
                        profileMetaChip("✨ \(completionScore)%")
                    }
                }
            }

            Text(profileBio)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 8) {
                NavigationLink {
                    NativeEditProfileView()
                } label: {
                    Text("✏️ Edit Profile")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1.2)
                        }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NativeSettingsHubView(onClose: onClose)
                } label: {
                    Text("⚙️ Settings")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.white.opacity(0.72))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }

            if let instagramHandle {
                HStack(spacing: 8) {
                    profileMetaChip("📸 @\(instagramHandle)")
                    if let nativeLanguageChip {
                        profileMetaChip(nativeLanguageChip)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let nativeLanguageChip {
                HStack(spacing: 8) {
                    profileMetaChip(nativeLanguageChip)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let avatarUploadError {
                Text(avatarUploadError)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    FriendZoneTheme.Colors.primarySoft.opacity(0.72),
                    Color(hex: "#FFF1E8")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private var completionCard: some View {
        Button {
            isPresentingCompletionSheet = true
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FriendZoneTheme.Colors.primary.opacity(0.14))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text("✨")
                            .font(.system(size: 18))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Complete Your Profile")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("\(completionValue) ready · \(completionCaption)")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.white, FriendZoneTheme.Colors.primarySoft.opacity(0.55)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
            .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        }
        .buttonStyle(.plain)
    }

    private var statsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            NavigationLink {
                NativePlansHubView(onClose: onClose)
            } label: {
                profileStatCard("🎉", attendedCount, "ATTENDED", interactive: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                NativePlansHubView(onClose: onClose)
            } label: {
                profileStatCard("🎯", hostedCount, "HOSTED", interactive: true)
            }
            .buttonStyle(.plain)

            profileStatCard("⭐", ratingValue, "RATING", interactive: false)

            NavigationLink {
                NativePlaceholderHubView(
                    title: "Followers",
                    message: "Your followers list will appear here."
                )
            } label: {
                profileStatCard("👥", followersCount, "FOLLOWERS", interactive: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                NativePlaceholderHubView(
                    title: "Following",
                    message: "Accounts you follow will appear here."
                )
            } label: {
                profileStatCard("🤝", followingCount, "FOLLOWING", interactive: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var quickActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                NavigationLink {
                    NativeMessagesView()
                } label: {
                    shortcutCard(
                        icon: "bubble.left.and.bubble.right.fill",
                        tint: FriendZoneTheme.Colors.primary,
                        title: "Messages",
                        subtitle: "Chats and requests"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NativePlansHubView(onClose: onClose)
                } label: {
                    shortcutCard(
                        icon: "calendar",
                        tint: Color(hex: "#F97316"),
                        title: "My Plans",
                        subtitle: "Upcoming and hosting"
                    )
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                NativeNotificationsHubView(onClose: onClose)
            } label: {
                shortcutWideCard(
                    icon: "bell.fill",
                    tint: Color(hex: "#10B981"),
                    title: "Notifications",
                    subtitle: "Unread updates, reminders and invites"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func profileMetaChip(_ title: String) -> some View {
        Text(title)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(FriendZoneTheme.Colors.surfaceMuted)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
    }

    private func profileStatCard(_ emoji: String, _ value: String, _ label: String, interactive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(emoji)
                    .font(.system(size: 18))
                Spacer()
                if interactive {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
            }

            HStack(spacing: 7) {
                Text(emoji)
                Text(value)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
            }
            Text(label)
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .tracking(0.6)
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.white, FriendZoneTheme.Colors.surfaceMuted],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func profileRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .padding(12)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func shortcutCard(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(14)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func shortcutWideCard(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .padding(14)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private func chipsSection(title: String, items: [String]) -> some View {
        tagSection(
            rawTitle: title,
            items: items,
            minimumWidth: title == "LANGUAGES" ? 110 : 90
        ) { item in
            Text(item)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 34)
        }
    }

    private func interestChipsSection(title: String, items: [String]) -> some View {
        tagSection(
            rawTitle: title,
            items: items,
            minimumWidth: 118
        ) { item in
            HStack(spacing: 6) {
                Text(interestEmoji(for: item))
                    .font(.system(size: 11))
                Text(item)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
        }
    }

    private func tagSection<Chip: View>(
        rawTitle: String,
        items: [String],
        minimumWidth: CGFloat,
        @ViewBuilder chip: @escaping (String) -> Chip
    ) -> some View {
        let tint = tagSectionTint(for: rawTitle)
        let icon = tagSectionIcon(for: rawTitle)
        let title = tagSectionDisplayTitle(for: rawTitle)
        let subtitle = tagSectionSubtitle(for: rawTitle)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(icon)
                            .font(.system(size: 16))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }

                Spacer()

                Text("\(items.count)")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                    .foregroundColor(tint)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(tint.opacity(0.12))
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    chip(item)
                        .background(
                            LinearGradient(
                                colors: [Color.white, tint.opacity(0.09)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(tint.opacity(0.22), lineWidth: 1)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white, tint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private func interestEmoji(for interest: String) -> String {
        let normalized = interest.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let emojiMap: [String: String] = [
            "coffee": "☕",
            "startups": "🚀",
            "music": "🎵",
            "food": "🍜",
            "photography": "📷",
            "walking": "🚶",
            "fitness": "💪",
            "movies": "🎬",
            "gaming": "🎮",
            "travel": "✈️",
            "art": "🎨",
            "reading": "📚",
            "tech": "💻",
            "nature": "🌿"
        ]
        return emojiMap[normalized] ?? "✨"
    }

    private func tagSectionDisplayTitle(for rawTitle: String) -> String {
        switch rawTitle {
        case "HANGOUT STYLE":
            return "How You Like To Meet"
        case "AVAILABILITY":
            return "When You're Around"
        case "VIBES":
            return "Your Energy"
        case "INTERESTS":
            return "Things You're Into"
        case "LANGUAGES":
            return "How You Speak"
        default:
            return rawTitle.capitalized
        }
    }

    private func tagSectionSubtitle(for rawTitle: String) -> String {
        switch rawTitle {
        case "HANGOUT STYLE":
            return "The kind of social rhythm you naturally enjoy."
        case "AVAILABILITY":
            return "Helpful timing signals for better matching."
        case "VIBES":
            return "The mood people can expect around you."
        case "INTERESTS":
            return "Topics and activities that usually pull you in."
        case "LANGUAGES":
            return "The languages you can comfortably hang out in."
        default:
            return ""
        }
    }

    private func tagSectionIcon(for rawTitle: String) -> String {
        switch rawTitle {
        case "HANGOUT STYLE":
            return "🪩"
        case "AVAILABILITY":
            return "🕓"
        case "VIBES":
            return "✨"
        case "INTERESTS":
            return "🎯"
        case "LANGUAGES":
            return "🌍"
        default:
            return "•"
        }
    }

    private func tagSectionTint(for rawTitle: String) -> Color {
        switch rawTitle {
        case "HANGOUT STYLE":
            return Color(hex: "#F97316")
        case "AVAILABILITY":
            return Color(hex: "#10B981")
        case "VIBES":
            return Color(hex: "#EC4899")
        case "INTERESTS":
            return Color(hex: "#0EA5E9")
        case "LANGUAGES":
            return Color(hex: "#6D28D9")
        default:
            return FriendZoneTheme.Colors.primary
        }
    }

    private var displayName: String {
        let user = session.currentUser
        let parts = [user?.firstName, user?.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? (user?.username.capitalized ?? "FriendZone") : parts.joined(separator: " ")
    }

    private var username: String {
        session.currentUser?.username ?? "friendzone"
    }

    private var cityLabel: String {
        session.currentProfile?.cityName ?? "City not set"
    }

    private var completionValue: String {
        if let score = session.currentProfile?.completionScore {
            return "\(score)%"
        }
        return "--"
    }

    private var completionCaption: String {
        let missingCount = session.currentProfile?.completionMissingFields?.count ?? 0
        if missingCount > 0 {
            return "\(missingCount) pieces left"
        }
        return "Looking good"
    }

    private var profileBio: String {
        session.currentProfile?.bio?.isEmpty == false ? session.currentProfile?.bio ?? "" : "Complete your profile to help others understand your vibe."
    }

    private var profileInitial: String {
        String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).first ?? Character("F")).uppercased()
    }

    private var profileVibes: [String] {
        let values = session.currentProfile?.vibes ?? []
        return values.isEmpty ? ["☕ Chill", "✨ Curious"] : values.map { "\(emojiForVibe($0)) \($0.capitalized)" }
    }

    private var profileInterests: [String] {
        let values = session.currentProfile?.interests ?? []
        return values.isEmpty ? ["Coffee", "Music", "Walking"] : values.map(\.capitalized)
    }

    private var profileLanguages: [String] {
        let native = session.currentProfile?.nativeLanguage?.lowercased()
        let values = session.currentProfile?.spokenLanguages ?? []
        var labels: [String] = []

        if let native, !native.isEmpty {
            labels.append("⭐ \(flagEmoji(for: native)) \(native.uppercased()) native")
        }

        for value in values {
            let normalized = value.lowercased()
            guard normalized != native else { continue }
            labels.append("\(flagEmoji(for: normalized)) \(normalized.uppercased())")
        }

        return labels.isEmpty ? ["🌍 Add languages"] : labels
    }

    private var profileIntentionsTitle: String {
        let values = Set((session.currentProfile?.interestedIn ?? []).map { $0.lowercased() })
        return values.isSubset(of: ["structured", "spontaneous"]) ? "HANGOUT STYLE" : "LOOKING FOR"
    }

    private var profileIntentions: [String] {
        (session.currentProfile?.interestedIn ?? []).map(intentChipLabel(for:))
    }

    private var profileAvailability: [String] {
        (session.currentProfile?.availabilitySchedule ?? []).map(availabilityChipLabel(for:))
    }

    private var instagramHandle: String? {
        let raw = session.currentProfile?.instagramUsername?.trimmingCharacters(in: CharacterSet(charactersIn: "@").union(.whitespacesAndNewlines))
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    private var nativeLanguageChip: String? {
        guard let code = session.currentProfile?.nativeLanguage?.lowercased(), !code.isEmpty else { return nil }
        return "🗣️ Native \(flagEmoji(for: code)) \(code.uppercased())"
    }

    private var genderChip: String? {
        guard let raw = session.currentProfile?.gender?.lowercased(), !raw.isEmpty else { return nil }
        switch raw {
        case "male":
            return "🕺 Male"
        case "female":
            return "💃 Female"
        case "non_binary":
            return "⚡ Non-binary"
        default:
            return "✨ \(raw.replacingOccurrences(of: "_", with: " ").capitalized)"
        }
    }

    private var groupSizeChip: String? {
        guard let raw = session.currentProfile?.preferredGroupSize?.lowercased(), !raw.isEmpty else { return nil }
        switch raw {
        case "solo":
            return "👥 One-on-one"
        case "small":
            return "🫶 Small group"
        case "medium":
            return "🎈 Medium group"
        case "large":
            return "🎉 Big group"
        case "any":
            return "🌍 Any size"
        default:
            return "✨ \(raw.replacingOccurrences(of: "_", with: " ").capitalized)"
        }
    }

    private var attendedCount: String {
        "\(session.currentProfile?.hangoutsAttended ?? 0)"
    }

    private var hostedCount: String {
        "\(session.currentProfile?.hangoutsHosted ?? 0)"
    }

    private var followersCount: String {
        "\(session.currentProfile?.followersCount ?? 0)"
    }

    private var followingCount: String {
        "\(session.currentProfile?.followingCount ?? 0)"
    }

    private var ratingValue: String {
        guard let rating = session.currentProfile?.hostRating else { return "-" }
        return String(format: "%.1f", rating)
    }

    private func emojiForVibe(_ value: String) -> String {
        switch value.lowercased() {
        case "chill": return "☕"
        case "drinks": return "🍸"
        case "active", "sporty": return "💪"
        case "deep talk", "deeptalk", "deep_talk": return "🧠"
        case "creative": return "🎨"
        default: return "✨"
        }
    }

    private func intentChipLabel(for raw: String) -> String {
        switch raw.lowercased() {
        case "structured":
            return "📋 Structured"
        case "spontaneous":
            return "🎲 Spontaneous"
        case "friends":
            return "🤝 Friends"
        case "activities":
            return "🗺️ Activities"
        case "networking":
            return "💼 Networking"
        case "dating":
            return "💘 Dating"
        default:
            return "✨ \(raw.replacingOccurrences(of: "_", with: " ").capitalized)"
        }
    }

    private func availabilityChipLabel(for raw: String) -> String {
        switch raw.lowercased() {
        case "mornings":
            return "🌅 Mornings"
        case "afternoons":
            return "☀️ Afternoons"
        case "evenings":
            return "🌆 Evenings"
        case "nights":
            return "🌙 Nights"
        case "weekdays":
            return "🗓️ Weekdays"
        case "weekends":
            return "🎉 Weekends"
        case "flexible":
            return "🌈 Flexible"
        case "spontaneous":
            return "⚡ Spontaneous"
        default:
            return "✨ \(raw.replacingOccurrences(of: "_", with: " ").capitalized)"
        }
    }

    private func flagEmoji(for code: String) -> String {
        switch code.lowercased() {
        case "en":
            return "🇬🇧"
        case "es":
            return "🇪🇸"
        case "de":
            return "🇩🇪"
        case "fr":
            return "🇫🇷"
        case "it":
            return "🇮🇹"
        case "ja":
            return "🇯🇵"
        default:
            return "🌍"
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    .tracking(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white, FriendZoneTheme.Colors.surfaceMuted.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    @ViewBuilder
    private var avatarCircle: some View {
        if let avatarURL = session.currentProfile?.avatarImageUrl, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 92, height: 92)
            .overlay {
                Text(profileInitial)
                    .font(FriendZoneTheme.Typography.system(34, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
            }
    }

    @MainActor
    private func uploadAvatar(from item: PhotosPickerItem) async {
        avatarUploadError = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.82) else {
            avatarUploadError = "Could not process the selected image."
            return
        }

        do {
            try await session.uploadAvatar(jpegData: jpegData)
        } catch {
            avatarUploadError = error.localizedDescription
        }
    }
}

private struct NativeProfileCompletionSheet: View {
    @EnvironmentObject private var session: AppSessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?
    @StateObject private var citySearch = ApplePlaceSearchModel(resultTypes: [.address])
    @State private var isResolvingCity = false
    @State private var cityError = ""
    @State private var selectedCityKey = ""
    @State private var bio = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -24, to: Date()) ?? Date()
    @State private var gender = ""
    @State private var city = ""
    @State private var cityPlaceId = ""
    @State private var spokenLanguages: [String] = []
    @State private var interests: [String] = []
    @State private var isSaving = false
    @State private var saveError: String?

    private let languageOptions = ["en", "es", "de", "fr", "it", "ja"]
    private let interestOptions = [
        "coffee", "food", "cocktails", "tech", "music", "travel",
        "art", "fitness", "movies", "gaming", "nature", "reading"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    completionHeader

                    if missingFields.contains("avatar") {
                        avatarSection
                    }
                    if missingFields.contains("bio") {
                        bioSection
                    }
                    if missingFields.contains("birth_date") {
                        birthDateSection
                    }
                    if missingFields.contains("gender") {
                        genderSection
                    }
                    if missingFields.contains("city") {
                        citySection
                    }
                    if missingFields.contains("languages") {
                        languageSection
                    }
                    if missingFields.contains("interests") {
                        interestsSection
                    }
                    if missingFields.contains("phone_verification") {
                        verificationInfoCard(
                            icon: "📱",
                            title: "Phone Verification",
                            subtitle: "This still depends on a dedicated verification flow. It is not wired in iOS yet."
                        )
                    }
                    if missingFields.contains("email_verification") {
                        verificationInfoCard(
                            icon: "✉️",
                            title: "Email Verification",
                            subtitle: "This depends on account verification state. It is not exposed as an in-app action yet."
                        )
                    }

                    if let saveError {
                        Text(saveError)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isSaving ? "Saving..." : "Save Progress")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .padding(16)
            }
            .background(FriendZoneTheme.Colors.background)
            .navigationTitle("Complete Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            guard let profile = session.currentProfile else { return }
            bio = profile.bio ?? ""
            city = profile.cityName ?? ""
            cityPlaceId = profile.cityPlaceId ?? ""
            spokenLanguages = profile.spokenLanguages ?? []
            interests = profile.interests ?? []
            gender = profile.gender ?? ""
            if let birthDateString = profile.birthDate, let parsed = parseBirthDate(birthDateString) {
                birthDate = parsed
            }
            citySearch.query = city
            selectedCityKey = normalized(city)
            await citySearch.setPreferredCity(profile.cityName)
        }
        .onChange(of: selectedAvatarItem) { item in
            guard let item else { return }
            Task { await uploadAvatar(from: item) }
        }
    }

    private var completionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile at \(completionValue)")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text("\(missingFields.count) pieces still missing. Fill what you can now and we will refresh your score.")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.white, FriendZoneTheme.Colors.primarySoft.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var avatarSection: some View {
        completionSection(title: "Add a Photo", subtitle: "A real avatar helps people trust the profile faster.") {
            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedAvatarItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        Circle()
                            .fill(FriendZoneTheme.Colors.primarySoft)
                            .frame(width: 72, height: 72)
                        Image(systemName: isUploadingAvatar ? "arrow.triangle.2.circlepath" : "camera.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.primary)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isUploadingAvatar ? "Uploading photo..." : "Choose a profile photo")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("You can change it later at any time.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    if let avatarError {
                        Text(avatarError)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(FriendZoneTheme.Colors.error)
                    }
                }
            }
        }
    }

    private var bioSection: some View {
        completionSection(title: "Write a Real Bio", subtitle: "You need at least 50 characters for this one to count.") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $bio)
                    .font(.system(size: 15))
                    .frame(height: 110)
                    .padding(8)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                Text("\(bio.trimmingCharacters(in: .whitespacesAndNewlines).count)/50")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
        }
    }

    private var birthDateSection: some View {
        completionSection(title: "Add Your Birthday", subtitle: "Used only to calculate age and improve trust signals.") {
            DatePicker(
                "",
                selection: $birthDate,
                in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(8)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var genderSection: some View {
        completionSection(title: "Add Gender", subtitle: "Only the profile field, not hangout preferences.") {
            HStack(spacing: 8) {
                ForEach(genderOptions, id: \.value) { option in
                    Button {
                        gender = option.value
                    } label: {
                        Text("\(option.emoji) \(option.label)")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                            .foregroundColor(gender == option.value ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(gender == option.value ? FriendZoneTheme.Colors.primary : Color.white.opacity(0.88))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: gender == option.value ? 0 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var citySection: some View {
        completionSection(title: "Set Your City", subtitle: "Choose a real result so backend gets the canonical city id.") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Search your city...", text: $citySearch.query)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .medium))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                    .onChange(of: citySearch.query) { newValue in
                        city = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if normalized(city) != selectedCityKey {
                            cityPlaceId = ""
                        }
                        if city.isEmpty {
                            selectedCityKey = ""
                        }
                    }

                if isResolvingCity {
                    ProgressView()
                }

                if !citySearch.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(citySearch.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            Button {
                                Task { await applyCitySuggestion(suggestion) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.title)
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if index < citySearch.suggestions.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(Color.white.opacity(0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                    }
                }

                if !city.isEmpty && !cityPlaceId.isEmpty {
                    Text("✔︎ \(city)")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.success)
                }
                if !cityError.isEmpty {
                    Text(cityError)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                }
            }
        }
    }

    private var languageSection: some View {
        completionSection(title: "Pick Languages", subtitle: "At least one spoken language is enough for the score.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                ForEach(languageOptions, id: \.self) { code in
                    let selected = spokenLanguages.contains(code)
                    Button {
                        toggle(code, in: &spokenLanguages)
                    } label: {
                        Text("\(flagEmoji(for: code)) \(code.uppercased())")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                            .foregroundColor(selected ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(selected ? FriendZoneTheme.Colors.primary : Color.white.opacity(0.88))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: selected ? 0 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var interestsSection: some View {
        completionSection(title: "Choose Interests", subtitle: "Pick at least three to unlock this piece of the profile.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                ForEach(interestOptions, id: \.self) { item in
                    let selected = interests.contains(item)
                    Button {
                        toggle(item, in: &interests)
                    } label: {
                        HStack(spacing: 6) {
                            Text(interestEmoji(for: item))
                                .font(.system(size: 11))
                            Text(item.capitalized)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(selected ? FriendZoneTheme.Colors.textInverse : FriendZoneTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selected ? FriendZoneTheme.Colors.primaryAccent : Color.white.opacity(0.88))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: selected ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func verificationInfoCard(icon: String, title: String, subtitle: String) -> some View {
        completionSection(title: title, subtitle: subtitle) {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.system(size: 18))
                Text("Not connected in this build")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func completionSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }

    private var missingFields: [String] {
        session.currentProfile?.completionMissingFields ?? []
    }

    private var completionValue: String {
        if let score = session.currentProfile?.completionScore {
            return "\(score)%"
        }
        return "--"
    }

    private var genderOptions: [(value: String, label: String, emoji: String)] {
        [
            ("male", "Male", "🕺"),
            ("female", "Female", "💃"),
            ("non_binary", "Non-binary", "⚡")
        ]
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil

        do {
            try await session.updateProfile(
                ProfileUpdateSubmission(
                    displayName: displayName,
                    city: city,
                    cityPlaceId: cityPlaceId.isEmpty ? nil : cityPlaceId,
                    bio: bio,
                    instagramUsername: session.currentProfile?.instagramUsername ?? "",
                    birthDate: missingFields.contains("birth_date") ? birthDate : nil,
                    gender: gender.isEmpty ? nil : gender,
                    spokenLanguages: spokenLanguages,
                    interests: interests
                )
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }

    @MainActor
    private func uploadAvatar(from item: PhotosPickerItem) async {
        avatarError = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.82) else {
            avatarError = "Could not process the selected image."
            return
        }

        do {
            try await session.uploadAvatar(jpegData: jpegData)
        } catch {
            avatarError = error.localizedDescription
        }
    }

    @MainActor
    private func applyCitySuggestion(_ suggestion: ApplePlaceSuggestion) async {
        cityError = ""
        isResolvingCity = true
        defer { isResolvingCity = false }

        do {
            let resolved = try await citySearch.resolve(suggestion)
            guard let latitude = resolved.latitude, let longitude = resolved.longitude else {
                city = resolved.cityName ?? suggestion.title
                citySearch.query = city
                cityPlaceId = ""
                selectedCityKey = ""
                cityError = "Pick another result so we can resolve the city correctly."
                return
            }

            let guessed = try await session.guessLocation(
                lat: latitude,
                lng: longitude,
                cityName: resolved.cityName ?? suggestion.title,
                country: resolved.countryCode ?? resolved.countryName
            )
            city = guessed.cityName
            cityPlaceId = guessed.cityPlaceId
            selectedCityKey = normalized(guessed.cityName)
            citySearch.query = guessed.cityName
            citySearch.clearSuggestions()
        } catch {
            cityPlaceId = ""
            selectedCityKey = ""
            cityError = error.localizedDescription
        }
    }

    private var displayName: String {
        let user = session.currentUser
        let parts = [user?.firstName, user?.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? (user?.username ?? "") : parts.joined(separator: " ")
    }

    private func parseBirthDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func toggle(_ value: String, in collection: inout [String]) {
        if collection.contains(value) {
            collection.removeAll { $0 == value }
        } else {
            collection.append(value)
        }
    }

    private func flagEmoji(for code: String) -> String {
        switch code.lowercased() {
        case "en": return "🇬🇧"
        case "es": return "🇪🇸"
        case "de": return "🇩🇪"
        case "fr": return "🇫🇷"
        case "it": return "🇮🇹"
        case "ja": return "🇯🇵"
        default: return "🌍"
        }
    }

    private func interestEmoji(for interest: String) -> String {
        switch interest.lowercased() {
        case "coffee": return "☕"
        case "food": return "🍜"
        case "cocktails": return "🍸"
        case "tech": return "💻"
        case "music": return "🎵"
        case "travel": return "✈️"
        case "art": return "🎨"
        case "fitness": return "💪"
        case "movies": return "🎬"
        case "gaming": return "🎮"
        case "nature": return "🌿"
        case "reading": return "📚"
        default: return "✨"
        }
    }
}

private struct NativeSettingsHubView: View {
    let onClose: () -> Void

    @EnvironmentObject private var session: AppSessionStore
    @State private var pushNotifications = true
    @State private var locationSharing = true
    @State private var showDistance = true
    @State private var privateAccount = true
    @State private var verificationNote = ""
    @State private var verificationStatus: SettingsVerificationState = .none
    @StateObject private var creatorContext = SettingsCreatorContextViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerCard

                VStack(spacing: 16) {
                    settingsSection(title: "Account") {
                        NavigationLink {
                            NativeChangePasswordHubView()
                        } label: {
                            settingsNavRow(icon: "lock.fill", title: "Change password", subtitle: "Update your password", showsChevron: true)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 58)

                        NavigationLink {
                            NativeEmailSettingsHubView()
                        } label: {
                            settingsNavRow(icon: "envelope.fill", title: "Email address", subtitle: "safaeralabs@example.com", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "Verification") {
                        switch verificationStatus {
                        case .verified:
                            settingsStaticRow(icon: "checkmark.seal.fill", title: "Verified account", subtitle: "Your profile has a verification badge")
                        case .pending:
                            settingsStaticRow(icon: "hourglass.circle.fill", title: "Request pending", subtitle: "Your verification request is under review")
                        case .none:
                            VStack(alignment: .leading, spacing: 12) {
                                settingsStaticRow(icon: "sparkles", title: "Get verified", subtitle: "Apply for a verification badge on your profile")
                                TextEditor(text: $verificationNote)
                                    .font(.system(size: 14))
                                    .frame(height: 90)
                                    .padding(10)
                                    .background(FriendZoneTheme.Colors.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                                    }
                                Button {
                                    verificationStatus = .pending
                                } label: {
                                    Text("Request verification")
                                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(FriendZoneTheme.Colors.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                        }
                    }

                    settingsSection(title: "Privacy") {
                        settingsToggleRow(icon: "location.fill", title: "Location sharing", subtitle: "Show your location to nearby users", isOn: $locationSharing)
                        Divider().padding(.leading, 58)
                        settingsToggleRow(icon: "arrow.left.and.right", title: "Show distance", subtitle: "Display distance on profile", isOn: $showDistance)
                        Divider().padding(.leading, 58)
                        settingsToggleRow(icon: "person.crop.circle.badge.xmark", title: "Private account", subtitle: "Only accepted people can see details", isOn: $privateAccount)
                        Divider().padding(.leading, 58)
                        NavigationLink {
                            NativeBlockedUsersHubView()
                        } label: {
                            settingsNavRow(icon: "nosign", title: "Blocked users", subtitle: "Manage blocked accounts", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "Notifications") {
                        settingsToggleRow(icon: "bell.fill", title: "Push notifications", subtitle: "Get updates about hangouts", isOn: $pushNotifications)
                        Divider().padding(.leading, 58)
                        NavigationLink {
                            NativeNotificationPreferencesHubView()
                        } label: {
                            settingsNavRow(icon: "slider.horizontal.3", title: "Notification preferences", subtitle: "Customize what you receive", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "Creator Program") {
                        if creatorContext.userFlags.hasCreatorRole {
                            NavigationLink {
                                NativeCreatorSpaceHubView(userFlags: creatorContext.userFlags)
                            } label: {
                                settingsNavRow(
                                    icon: "building.2.fill",
                                    title: "Creator space",
                                    subtitle: creatorSpaceSubtitle,
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 58)
                        }

                        NavigationLink {
                            NativeBecomeCreatorHubView(userFlags: creatorContext.userFlags) { grantedRole in
                                creatorContext.markRoleGranted(grantedRole)
                            }
                        } label: {
                            settingsNavRow(
                                icon: "rocket.fill",
                                title: creatorContext.userFlags.hasCreatorRole ? "Apply for more roles" : "Become a creator",
                                subtitle: creatorApplySubtitle,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if creatorContext.userFlags.isStaff {
                        settingsSection(title: "Admin") {
                            NavigationLink {
                                NativePlaceholderHubView(
                                    title: "Role Requests",
                                    message: "Review creator role applications."
                                )
                            } label: {
                                settingsNavRow(icon: "person.text.rectangle.fill", title: "Role requests", subtitle: "Review creator applications", showsChevron: true)
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 58)

                            NavigationLink {
                                NativePlaceholderHubView(
                                    title: "Verification Requests",
                                    message: "Review user verification applications."
                                )
                            } label: {
                                settingsNavRow(icon: "checkmark.seal.fill", title: "Verification requests", subtitle: "Review user applications", showsChevron: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    settingsSection(title: "Support") {
                        NavigationLink {
                            NativeHelpView()
                        } label: {
                            settingsNavRow(icon: "questionmark.circle.fill", title: "Help center", subtitle: "Get help and FAQs", showsChevron: true)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 58)

                        NavigationLink {
                            NativeFeedbackHubView()
                        } label: {
                            settingsNavRow(icon: "bubble.left.fill", title: "Send feedback", subtitle: "Help us improve", showsChevron: true)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 58)

                        NavigationLink {
                            NativeReportProblemHubView()
                        } label: {
                            settingsNavRow(icon: "exclamationmark.triangle.fill", title: "Report a problem", subtitle: "Let us know about issues", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "Legal") {
                        NavigationLink {
                            NativeTermsView()
                        } label: {
                            settingsNavRow(icon: "doc.text.fill", title: "Terms of service", subtitle: "Rules and legal terms", showsChevron: true)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 58)

                        NavigationLink {
                            NativePrivacyView()
                        } label: {
                            settingsNavRow(icon: "lock.shield.fill", title: "Privacy policy", subtitle: "How your data is handled", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "About") {
                        VStack(spacing: 4) {
                            Text("FriendZone v1.0.0")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                            Text("Copyright 2025 FriendZone Inc.")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }

                    VStack(spacing: 10) {
                        Button {
                            onClose()
                            Task {
                                await session.logout()
                            }
                        } label: {
                            Text("Log out")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(FriendZoneTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                                }
                        }
                        .buttonStyle(.plain)

                        Button("Delete account") {}
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                            .foregroundColor(FriendZoneTokens.Colors.errorStrong)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(FriendZoneTokens.Colors.error.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(FriendZoneTokens.Colors.error.opacity(0.24), lineWidth: 1.5)
                            }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await creatorContext.loadIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private var creatorSpaceSubtitle: String {
        let managedScopes = [
            creatorContext.userFlags.isEventCreator ? "events" : nil,
            creatorContext.userFlags.isVenueOwner ? "venues & offers" : nil
        ].compactMap { $0 }

        if managedScopes.isEmpty {
            return "Manage your creator dashboard"
        }

        return "Manage your \(managedScopes.joined(separator: ", "))"
    }

    private var creatorApplySubtitle: String {
        if creatorContext.userFlags.isEventCreator, creatorContext.userFlags.isVenueOwner {
            return "You already have all creator roles"
        }
        return "Apply as Event Creator or Venue Owner"
    }

    private var headerCard: some View {
        HStack(spacing: 0) {
            Text("Your ")
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text("settings")
                .foregroundColor(FriendZoneTheme.Colors.primary)
        }
        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XL, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .friendZoneShadow(FriendZoneTheme.Shadows.sm)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.5)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.90))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 2)
            }
            .friendZoneShadow(FriendZoneTheme.Shadows.sm)
        }
    }

    private func settingsNavRow(icon: String, title: String, subtitle: String, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            iconWrap(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
            if showsChevron {
                Text("›")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func settingsStaticRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            iconWrap(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func settingsToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconWrap(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(FriendZoneTheme.Colors.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func iconWrap(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            .frame(width: 34, height: 34)
            .background(FriendZoneTheme.Colors.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
    }
}

private enum SettingsVerificationState {
    case none
    case pending
    case verified
}

private struct SettingsRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let binding: Binding<Bool>

    static func toggle(_ title: String, _ subtitle: String, _ binding: Binding<Bool>) -> SettingsRow {
        SettingsRow(title: title, subtitle: subtitle, binding: binding)
    }
}

private struct NativeEditProfileView: View {
    @EnvironmentObject private var session: AppSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var city = ""
    @State private var instagramUsername = ""
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                readOnlyField("Username", value: "@\(username)")
                inputField("Display name", text: $displayName)
                readOnlyField("City", value: city.isEmpty ? "Set in onboarding" : city)
                inputField("Instagram", text: $instagramUsername)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Bio")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    TextEditor(text: $bio)
                        .font(.system(size: 15))
                        .frame(height: 120)
                        .padding(8)
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                }

                if let saveError {
                    Text(saveError)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await saveProfile() }
                }
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .task {
            let user = session.currentUser
            let profile = session.currentProfile
            username = user?.username ?? ""
            let name = [user?.firstName, user?.lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            displayName = name.isEmpty ? (user?.username ?? "") : name
            bio = profile?.bio ?? ""
            city = profile?.cityName ?? ""
            instagramUsername = profile?.instagramUsername ?? ""
        }
    }

    private func inputField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            TextField("", text: text)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
        }
    }

    private func readOnlyField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            Text(value)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(FriendZoneTheme.Colors.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }
        }
    }

    @MainActor
    private func saveProfile() async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil

        do {
            try await session.updateProfile(
                ProfileUpdateSubmission(
                    displayName: displayName,
                    city: city,
                    bio: bio,
                    instagramUsername: instagramUsername
                )
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }
}

private struct NativeMessagesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Circle()
                .fill(FriendZoneTheme.Colors.primarySoft)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "message")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                }
            Text("No inbox connected yet")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text("This screen is waiting for a dedicated backend inbox endpoint.")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeHelpView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                faqItem("How do I join a hangout?", "Open any card and tap request. The host accepts participants.")
                faqItem("Why is location hidden?", "Location becomes visible only after acceptance for safety.")
                faqItem("How do I report someone?", "Use the menu on cards or inside the map panel.")
                faqItem("Can I hide my profile details?", "Yes. Privacy controls live inside Settings.")
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faqItem(_ title: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(answer)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativePrivacyView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                legalBlock("Data we collect", "Account profile, activity interactions, and device diagnostics for app performance.")
                legalBlock("Location usage", "Used to show nearby hangouts and map results when the backend has real coordinates.")
                legalBlock("Sharing", "We do not sell personal data. Limited sharing happens only to operate core features.")
                legalBlock("Control", "You can request data export and account deletion from Settings.")
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(body)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativeTermsView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                legalBlock("Respectful conduct", "Harassment, hate, and unsafe behavior are not allowed.")
                legalBlock("Real-world safety", "Meet in public places and follow local laws and venue rules.")
                legalBlock("User responsibility", "You are responsible for content and behavior on your account.")
                legalBlock("Enforcement", "Accounts may be restricted for serious or repeated violations.")
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(body)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
        }
        .padding(12)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
    }
}

private struct NativeNotificationsHubView: View {
    @EnvironmentObject private var session: AppSessionStore
    let onClose: () -> Void
    let onUnreadCountChange: ((Int) -> Void)?
    @State private var filter: HubNotificationFilter = .all
    @State private var items: [HubNotificationItem] = []
    @State private var isLoading = true
    @State private var isMarkingAllRead = false
    @State private var errorMessage: String?
    @State private var destination: HubNavigationDestination?

    init(
        onClose: @escaping () -> Void,
        onUnreadCountChange: ((Int) -> Void)? = nil
    ) {
        self.onClose = onClose
        self.onUnreadCountChange = onUnreadCountChange
    }

    var body: some View {
        VStack(spacing: 0) {
            tabs
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(FriendZoneTheme.Colors.surface)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleItems.isEmpty {
                VStack(spacing: 10) {
                    Text("🔔")
                        .font(.system(size: 44))
                    Text(filter == .unread ? "You're all caught up!" : "No notifications yet")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text(filter == .unread ? "No unread notifications." : "We'll notify you when something happens.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(visibleItems) { item in
                            notificationRow(item)
                        }
                    }
                    .background(FriendZoneTheme.Colors.surfaceMuted)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadNotifications()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if unreadCount > 0 {
                    Button("Mark all read") {
                        Task { await markAllRead() }
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .disabled(isMarkingAllRead)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.error)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FriendZoneTheme.Colors.background.opacity(0.96))
            }
        }
        .fullScreenCover(item: $destination) { destination in
            NavigationStack {
                switch destination {
                case let .hangout(id):
                    HubHangoutDestinationView(hangoutID: id) {
                        self.destination = nil
                    }
                case let .event(id):
                    HubEventDestinationView(eventID: id) {
                        self.destination = nil
                    }
                case let .profile(userID):
                    PublicProfileView(
                        profile: PublicProfileData(
                            id: String(userID),
                            userID: userID,
                            displayName: "Profile",
                            bio: "",
                            instagram: "",
                            website: "",
                            city: ""
                        ),
                        leadingText: "Public ",
                        highlightText: "profile",
                        subtitle: nil
                    ) {
                        self.destination = nil
                    }
                }
            }
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
        }
    }

    private var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    private var visibleItems: [HubNotificationItem] {
        switch filter {
        case .all:
            return items
        case .unread:
            return items.filter { !$0.isRead }
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            tabButton(title: "All", isActive: filter == .all, badge: nil) {
                filter = .all
            }
            tabButton(title: "Unread", isActive: filter == .unread, badge: unreadCount == 0 ? nil : "\(unreadCount)") {
                filter = .unread
            }
            Spacer()
        }
    }

    private func tabButton(title: String, isActive: Bool, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if let badge {
                    Text(badge)
                        .font(FriendZoneTheme.Typography.system(11, weight: .bold))
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(isActive ? Color.white.opacity(0.30) : FriendZoneTheme.Colors.error)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(isActive ? .white : FriendZoneTheme.Colors.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(isActive ? FriendZoneTheme.Colors.primary : Color.clear)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isActive ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func notificationRow(_ item: HubNotificationItem) -> some View {
        Button {
            Task { await openNotification(item) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color(hex: item.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: item.colorHex))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: item.isRead ? .medium : .semibold))
                        .foregroundColor(item.isRead ? FriendZoneTheme.Colors.textSecondary : FriendZoneTheme.Colors.textPrimary)
                    Text(item.message)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(item.timeAgo)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }

                Spacer(minLength: 0)

                if !item.isRead {
                    Circle()
                        .fill(FriendZoneTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(item.isRead ? FriendZoneTheme.Colors.surface : Color(hex: "#FAFAFF"))
        }
        .contextMenu {
            Button("Mark read") {
                Task { await markRead(item) }
            }
            .disabled(item.isRead)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let feed = try await session.fetchNotifications()
            items = feed.map(HubNotificationItem.init(feed:))
            reportUnreadCount()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markRead(_ item: HubNotificationItem) async {
        guard !item.isRead else { return }
        do {
            let updated = try await session.markNotificationRead(id: item.id)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = HubNotificationItem(feed: updated)
            }
            reportUnreadCount()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markAllRead() async {
        guard !isMarkingAllRead else { return }
        isMarkingAllRead = true
        defer { isMarkingAllRead = false }
        do {
            _ = try await session.markAllNotificationsRead()
            for index in items.indices {
                items[index].isRead = true
            }
            reportUnreadCount()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openNotification(_ item: HubNotificationItem) async {
        if !item.isRead {
            await markRead(item)
        }
        if let destination = item.destination {
            self.destination = destination
        }
    }

    private func reportUnreadCount() {
        onUnreadCountChange?(items.filter { !$0.isRead }.count)
    }

}

private enum HubNotificationFilter {
    case all
    case unread
}

private struct HubNotificationItem: Identifiable {
    let id: Int
    let title: String
    let message: String
    let timeAgo: String
    let icon: String
    let colorHex: String
    var isRead: Bool
    let destination: HubNavigationDestination?

    init(feed: AppNotificationFeedItem) {
        id = feed.id
        title = feed.title
        message = feed.message
        timeAgo = feed.timeAgo
        icon = Self.icon(for: feed.type)
        colorHex = Self.color(for: feed.type)
        isRead = feed.read
        destination = Self.destination(for: feed)
    }

    private static func icon(for type: String) -> String {
        switch type {
        case "join_approved":
            return "checkmark.seal.fill"
        case "join_rejected", "hangout_cancelled", "kicked":
            return "xmark.octagon.fill"
        case "new_join_request", "match_member_accepted":
            return "person.2.fill"
        case "event_starting_soon":
            return "clock.fill"
        case "ambition_match", "match_converted", "badge_earned":
            return "sparkles"
        case "new_review":
            return "star.fill"
        case "space_available", "waitlisted":
            return "bell.badge.fill"
        default:
            return "bell.fill"
        }
    }

    private static func color(for type: String) -> String {
        switch type {
        case "join_approved":
            return "#10B981"
        case "new_join_request", "match_member_accepted":
            return "#8B5CF6"
        case "event_starting_soon":
            return "#F59E0B"
        case "ambition_match", "match_converted":
            return "#3B82F6"
        case "join_rejected", "hangout_cancelled", "kicked":
            return "#EF4444"
        case "new_review", "badge_earned":
            return "#0EA5E9"
        default:
            return "#667EEA"
        }
    }

    private static func destination(for feed: AppNotificationFeedItem) -> HubNavigationDestination? {
        if let hangoutID = feed.relatedHangoutId {
            return .hangout(hangoutID)
        }
        if let eventID = feed.relatedEventId {
            return .event(eventID)
        }
        if let userID = feed.relatedUserId {
            return .profile(userID)
        }
        return nil
    }
}

private enum HubNavigationDestination: Identifiable, Equatable {
    case hangout(Int)
    case event(Int)
    case profile(Int)

    var id: String {
        switch self {
        case let .hangout(id): return "hangout-\(id)"
        case let .event(id): return "event-\(id)"
        case let .profile(id): return "profile-\(id)"
        }
    }
}

private struct NativePlansHubView: View {
    @EnvironmentObject private var session: AppSessionStore
    let onClose: () -> Void
    @State private var selectedTab: PlansHubTab = .upcoming
    @State private var hangouts: [HangoutItem] = []
    @State private var soloItems: [SoloPlanItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var destination: PlansHubDestination?

    private var now: Date { Date() }

    private var currentSessionUserID: Int? {
        session.currentUser?.id ?? session.currentProfile?.user?.id
    }

    private var upcomingHangouts: [HangoutItem] {
        hangouts
            .filter { $0.endAt > now && ($0.isJoined || $0.isHosted(by: currentSessionUserID)) }
            .sorted { $0.startAt < $1.startAt }
    }

    private var hostingHangouts: [HangoutItem] {
        hangouts
            .filter { $0.endAt > now && $0.isHosted(by: currentSessionUserID) }
            .sorted { $0.startAt < $1.startAt }
    }

    private var pastHangouts: [HangoutItem] {
        hangouts
            .filter { $0.startAt <= now && ($0.isJoined || $0.isHosted(by: currentSessionUserID)) }
            .sorted { $0.startAt > $1.startAt }
    }

    private var upcomingSoloItems: [SoloPlanItem] {
        soloItems.filter { $0.startAt > now }.sorted { $0.startAt < $1.startAt }
    }

    private var pastSoloItems: [SoloPlanItem] {
        soloItems.filter { $0.startAt <= now }.sorted { $0.startAt > $1.startAt }
    }

    private var currentEntries: [PlansHubEntry] {
        switch selectedTab {
        case .upcoming:
            let entries = upcomingHangouts.map { PlansHubEntry.hangout($0) } + upcomingSoloItems.map { PlansHubEntry.solo($0) }
            return entries.sorted(by: { $0.date < $1.date })
        case .hosting:
            return hostingHangouts.map { PlansHubEntry.hangout($0) }.sorted(by: { $0.date < $1.date })
        case .past:
            let entries = pastHangouts.map { PlansHubEntry.hangout($0) } + pastSoloItems.map { PlansHubEntry.solo($0) }
            return entries.sorted(by: { $0.date > $1.date })
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                FriendZoneModuleHeader(
                    leadingText: "My ",
                    highlightText: "Plans"
                )

                VStack(spacing: 14) {
                    tabSwitch
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else if currentEntries.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(currentEntries.enumerated()), id: \.offset) { _, entry in
                                switch entry {
                                case let .hangout(hangout):
                                    hangoutPlanCard(hangout)
                                case let .solo(event):
                                    soloEventCard(event)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPlans()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.error)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FriendZoneTheme.Colors.background.opacity(0.96))
            }
        }
        .fullScreenCover(item: $destination) { destination in
            NavigationStack {
                switch destination {
                case let .hangout(id):
                    HubHangoutDestinationView(hangoutID: id) {
                        self.destination = nil
                    }
                case let .event(id):
                    HubEventDestinationView(eventID: id) {
                        self.destination = nil
                    }
                }
            }
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
        }
    }

    private var tabSwitch: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.78))
                .overlay {
                    Capsule().stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }

            GeometryReader { proxy in
                let innerWidth = max(0, proxy.size.width - 8)
                let tabWidth = innerWidth / 3
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary.opacity(0.16), FriendZoneTheme.Colors.primaryAccent.opacity(0.24)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: tabWidth, height: 34)
                    .overlay {
                        Capsule().stroke(FriendZoneTheme.Colors.primary.opacity(0.25), lineWidth: 1)
                    }
                    .offset(x: 4 + tabWidth * CGFloat(selectedTab.index), y: 4)
                    .animation(FriendZoneTheme.Motion.easeOutExpo, value: selectedTab)
            }

            HStack(spacing: 4) {
                planTabButton(.upcoming, count: upcomingHangouts.count + upcomingSoloItems.count)
                planTabButton(.hosting, count: hostingHangouts.count)
                planTabButton(.past, count: pastHangouts.count + pastSoloItems.count)
            }
            .padding(4)
        }
        .frame(height: 42)
    }

    private func planTabButton(_ tab: PlansHubTab, count: Int) -> some View {
        let active = selectedTab == tab
        return Button {
            selectedTab = tab
            FriendZoneHaptics.selection()
        } label: {
            HStack(spacing: 5) {
                Text(tab.icon)
                    .font(.system(size: 12))
                Text(tab.title)
                if count > 0 {
                    Text("\(count)")
                        .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(active ? Color.white.opacity(0.3) : Color.black.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
            .foregroundColor(active ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [FriendZoneTheme.Colors.primary.opacity(0.10), FriendZoneTheme.Colors.primaryAccent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay {
                    Text(selectedTab.icon)
                        .font(.system(size: 42))
                }
            Text(selectedTab.emptyTitle)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            Text(selectedTab.emptyDescription)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button(selectedTab.emptyButtonTitle) {
                if selectedTab == .hosting {
                    onClose()
                }
            }
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            .foregroundColor(FriendZoneTheme.Colors.textInverse)
            .padding(.horizontal, 26)
            .frame(height: 42)
            .background(
                LinearGradient(
                    colors: [FriendZoneTheme.Colors.primary, FriendZoneTheme.Colors.primaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }

    private func hangoutPlanCard(_ hangout: HangoutItem) -> some View {
        let happening = now >= hangout.startAt && now <= hangout.endAt
        let isPast = selectedTab == .past
        let isHost = hangout.isHosted(by: currentSessionUserID)

        return Button {
            destination = .hangout(hangout.id)
        } label: {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(happening ? FriendZoneTheme.Colors.success : vibeColor(hangout.vibe))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(vibeColor(hangout.vibe))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(vibeEmoji(hangout.vibe))
                                    .font(.system(size: 18))
                            }
                            .opacity(isPast ? 0.70 : 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hangout.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                .lineLimit(1)

                            Text("\(dateLabel(hangout.startAt)) · \(timeLabel(hangout.startAt)) · \(hangout.locationDisplay)")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if happening {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(FriendZoneTheme.Colors.success)
                                    .frame(width: 6, height: 6)
                                Text("NOW")
                            }
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.success)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(FriendZoneTheme.Colors.success.opacity(0.14))
                            .clipShape(Capsule())
                        } else {
                            Text(timeUntil(hangout.startAt, isPast: isPast))
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(isPast ? FriendZoneTheme.Colors.textTertiary : FriendZoneTheme.Colors.primary)
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(isPast ? Color.black.opacity(0.05) : FriendZoneTheme.Colors.primarySoft)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    Divider()
                        .padding(.leading, 18)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: isHost ? "sparkles" : "person.3.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(isHost ? "Hosting" : "Attending")
                        }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                        .foregroundColor(isHost ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background((isHost ? FriendZoneTheme.Colors.primary : Color.black).opacity(isHost ? 0.08 : 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11, weight: .medium))
                            Text("\(hangout.approvedCount)/\(hangout.capacity)")
                        }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .frame(width: 26, height: 26)
                            .background(Color.clear)
                            .clipShape(Circle())
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.top, 7)
                    .padding(.bottom, 10)
                }
            }
            .background(happening ? FriendZoneTheme.Colors.success.opacity(0.04) : FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(happening ? FriendZoneTheme.Colors.success.opacity(0.24) : FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
            .opacity(isPast ? 0.88 : 1)
        }
        .buttonStyle(.plain)
    }

    private func soloEventCard(_ event: SoloPlanItem) -> some View {
        let isPast = selectedTab == .past
        return Button {
            destination = .event(event.eventID)
        } label: {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: "#0E7490"), Color(hex: "#06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: "#0E7490"), Color(hex: "#06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Text("\(dateLabel(event.startAt)) · \(timeLabel(event.startAt)) · \(event.venueName)")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(timeUntil(event.startAt, isPast: isPast))
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                            .foregroundColor(isPast ? FriendZoneTheme.Colors.textTertiary : FriendZoneTheme.Colors.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(isPast ? Color.black.opacity(0.05) : FriendZoneTheme.Colors.primarySoft)
                            .clipShape(Capsule())
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    Divider()
                        .padding(.leading, 18)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("Event · Solo")
                        }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .semibold))
                        .foregroundColor(Color(hex: "#0F4C5C"))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color(hex: "#0E7490").opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(event.creatorName)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                            .frame(width: 26, height: 26)
                            .background(Color.clear)
                            .clipShape(Circle())
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.top, 7)
                    .padding(.bottom, 10)
                }
            }
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
            }
            .opacity(isPast ? 0.88 : 1)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadPlans() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let remoteHangouts = session.fetchHangouts()
            async let remoteSolo = session.fetchMySoloJoins()

            let hangoutFeed = try await remoteHangouts
            let soloFeed = try await remoteSolo

            let currentUserID = currentSessionUserID
            hangouts = hangoutFeed.compactMap {
                HubNavigationMapper.mapHangoutFeed($0, currentUserID: currentUserID)
            }
            soloItems = soloFeed.compactMap(HubNavigationMapper.mapSoloPlanItem)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dateLabel(_ value: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: value)
        if target == today { return "Today" }
        if target == Calendar.current.date(byAdding: .day, value: 1, to: today) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: value)
    }

    private func timeLabel(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }

    private func timeUntil(_ date: Date, isPast: Bool) -> String {
        if isPast {
            return shortDate(date)
        }
        let diff = Int(date.timeIntervalSince(now))
        if diff <= 0 { return shortDate(date) }
        let hours = diff / 3600
        if hours >= 24 { return "In \(hours / 24)d" }
        if hours > 0 { return "In \(hours)h" }
        let minutes = max(1, diff / 60)
        return "In \(minutes)m"
    }

    private func shortDate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: value)
    }

    private func vibeColor(_ vibe: HangoutVibe) -> Color {
        switch vibe {
        case .chill: return Color(hex: "#667EEA")
        case .drinks: return Color(hex: "#FC5C65")
        case .deepTalk: return Color(hex: "#A55EEA")
        case .activity: return Color(hex: "#56AB2F")
        case .foodie: return Color(hex: "#D4A373")
        case .sporty: return Color(hex: "#26DE81")
        }
    }

    private func vibeEmoji(_ vibe: HangoutVibe) -> String {
        switch vibe {
        case .chill: return "😌"
        case .drinks: return "🍸"
        case .deepTalk: return "🗣️"
        case .activity: return "💪"
        case .foodie: return "🍽️"
        case .sporty: return "⚽"
        }
    }
}

private enum PlansHubEntry {
    case hangout(HangoutItem)
    case solo(SoloPlanItem)

    var date: Date {
        switch self {
        case let .hangout(item):
            return item.startAt
        case let .solo(item):
            return item.startAt
        }
    }
}

private struct SoloPlanItem {
    let id: Int
    let eventID: Int
    let title: String
    let startAt: Date
    let venueName: String
    let creatorName: String
}

private enum PlansHubDestination: Identifiable, Equatable {
    case hangout(Int)
    case event(Int)

    var id: String {
        switch self {
        case let .hangout(id): return "hangout-\(id)"
        case let .event(id): return "event-\(id)"
        }
    }
}

private enum PlansHubTab: CaseIterable {
    case upcoming
    case hosting
    case past

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .hosting: return "Hosting"
        case .past: return "Past"
        }
    }

    var icon: String {
        switch self {
        case .upcoming: return "📅"
        case .hosting: return "🎯"
        case .past: return "✨"
        }
    }

    var emptyTitle: String {
        switch self {
        case .upcoming: return "No upcoming plans"
        case .hosting: return "Not hosting anything yet"
        case .past: return "No past hangouts"
        }
    }

    var emptyDescription: String {
        switch self {
        case .upcoming: return "Browse Hangouts and join your next activity."
        case .hosting: return "Create your first hangout and bring people together."
        case .past: return "Join some hangouts to build your history."
        }
    }

    var emptyButtonTitle: String {
        switch self {
        case .hosting:
            return "Create Hangout"
        case .upcoming, .past:
            return "Explore Now"
        }
    }

    var index: Int {
        switch self {
        case .upcoming: return 0
        case .hosting: return 1
        case .past: return 2
        }
    }
}

private struct NativePlaceholderHubView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
            Text(message)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeChangePasswordHubView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var showCurrent = false
    @State private var showNew = false
    @State private var showConfirm = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var didSave = false

    var body: some View {
        Group {
            if didSave {
                VStack(spacing: 12) {
                    Text("✅")
                        .font(.system(size: 56))
                    Text("Password updated")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("Your password was changed successfully.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Button("Back to Settings") {
                        dismiss()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .padding(.horizontal, 24)
                    .frame(height: 42)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 50)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                                .foregroundColor(FriendZoneTheme.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(FriendZoneTheme.Colors.error.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.error.opacity(0.24), lineWidth: 1)
                                }
                        }

                        passwordField(
                            title: "Current Password",
                            placeholder: "Enter current password",
                            text: $current,
                            isVisible: $showCurrent
                        )

                        passwordField(
                            title: "New Password",
                            placeholder: "At least 8 characters",
                            text: $newPassword,
                            isVisible: $showNew
                        )

                        passwordField(
                            title: "Confirm New Password",
                            placeholder: "Repeat new password",
                            text: $confirm,
                            isVisible: $showConfirm
                        )

                        Button {
                            Task {
                                await submit()
                            }
                        } label: {
                            Text(isSaving ? "Saving..." : "Update Password")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(FriendZoneTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.65 : 1)
                    }
                    .padding(16)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func passwordField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                .tracking(0.5)

            HStack(spacing: 0) {
                Group {
                    if isVisible.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Spacer(minLength: 8)

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(FriendZoneTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
            }
        }
    }

    private func submit() async {
        errorMessage = ""
        guard newPassword == confirm else {
            errorMessage = "New passwords do not match."
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "New password must be at least 8 characters."
            return
        }

        isSaving = true
        try? await Task.sleep(nanoseconds: 600_000_000)
        isSaving = false
        didSave = true
    }
}

private struct NativeEmailSettingsHubView: View {
    @State private var currentEmail = "safaeralabs@example.com"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Email")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.5)
                    TextField("", text: $currentEmail)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .disabled(true)
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(FriendZoneTheme.Colors.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                        }
                }

                Text("Email address cannot be changed directly. If you need to update your email, contact support at support@friendzone.app.")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(FriendZoneTheme.Colors.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.primary.opacity(0.14), lineWidth: 1)
                    }
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Email Address")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeBlockedUsersHubView: View {
    @State private var isLoading = true
    @State private var unblockingID: Int?
    @State private var users: [BlockedUserItem] = [
        BlockedUserItem(id: 1, username: "alex99", displayName: "Alex Rivera", accent: Color(hex: "#8B5CF6")),
        BlockedUserItem(id: 2, username: "nightowl", displayName: "Nora Lee", accent: Color(hex: "#06B6D4")),
        BlockedUserItem(id: 3, username: "quietmode", displayName: "Kai Martin", accent: Color(hex: "#F97316"))
    ]

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading blocked users...")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else if users.isEmpty {
                VStack(spacing: 8) {
                    Text("✕")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                    Text("No blocked users")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("Users you block will not be able to see your profile or send you messages.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 0) {
                            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                blockedRow(user)
                                if index < users.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                        .background(FriendZoneTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            guard isLoading else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            isLoading = false
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func blockedRow(_ user: BlockedUserItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(user.accent.opacity(0.14))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(user.displayName.prefix(1)).uppercased())
                        .font(FriendZoneTheme.Typography.system(14, weight: .bold))
                        .foregroundColor(user.accent)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(user.displayName)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text("@\(user.username)")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)
            }
            Spacer()
            Button {
                guard unblockingID == nil else { return }
                unblockingID = user.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    users.removeAll { $0.id == user.id }
                    unblockingID = nil
                }
            } label: {
                Text(unblockingID == user.id ? "..." : "Unblock")
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(FriendZoneTheme.Colors.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(FriendZoneTheme.Colors.primary.opacity(0.30), lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)
            .disabled(unblockingID == user.id)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct NativeNotificationPreferencesHubView: View {
    @EnvironmentObject private var session: AppSessionStore
    @State private var hangoutInvites = true
    @State private var joinRequests = true
    @State private var messages = true
    @State private var eventUpdates = true
    @State private var newFollowers = false
    @State private var reminders = true
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notify me about")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                        .tracking(0.5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    preferenceRow("Hangout Invitations", "When someone invites you to a hangout", isOn: $hangoutInvites)
                    Divider().padding(.leading, 16)
                    preferenceRow("Join Requests", "When someone requests to join your hangout", isOn: $joinRequests)
                    Divider().padding(.leading, 16)
                    preferenceRow("New Messages", "When you receive a message in a hangout chat", isOn: $messages)
                    Divider().padding(.leading, 16)
                    preferenceRow("Event Updates", "Changes to events you're attending", isOn: $eventUpdates)
                    Divider().padding(.leading, 16)
                    preferenceRow("New Followers", "When someone follows your profile", isOn: $newFollowers)
                    Divider().padding(.leading, 16)
                    preferenceRow("Reminders", "Reminders before your upcoming hangouts", isOn: $reminders)
                }
                .background(FriendZoneTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
                }

                Button {
                    Task { await savePreferences() }
                } label: {
                    Text(isSaving ? "Saving..." : "Save Preferences")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || isLoading)

                if didSave {
                    Text("Preferences saved")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
    }

    private func preferenceRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(FriendZoneTheme.Colors.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @MainActor
    private func loadPreferences() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let preferences = try await session.fetchNotificationPreferences()
            hangoutInvites = preferences.notifyJoinApproved || preferences.notifyJoinRejected
            joinRequests = preferences.notifyNewJoinRequest || preferences.notifyHangoutCancelled || preferences.notifyHangoutChanged || preferences.notifySpaceAvailable || preferences.notifyKicked
            messages = preferences.notifyAmbitionMatches || preferences.notifyMatchUpdates
            eventUpdates = preferences.notifySavedEventUpdates || preferences.notifyNewEvents
            newFollowers = preferences.notifyNewReviews || preferences.notifyBadges
            reminders = preferences.notifyEventStartingSoon
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func savePreferences() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        didSave = false
        do {
            _ = try await session.updateNotificationPreferences(
                NotificationPreferencesUpdateRequest(
                    notifyJoinApproved: hangoutInvites,
                    notifyJoinRejected: hangoutInvites,
                    notifyNewJoinRequest: joinRequests,
                    notifyHangoutCancelled: joinRequests,
                    notifyHangoutChanged: joinRequests,
                    notifyKicked: joinRequests,
                    notifySpaceAvailable: joinRequests,
                    notifyAmbitionMatches: messages,
                    notifyMatchUpdates: messages,
                    notifyEventStartingSoon: reminders,
                    notifyNewEvents: eventUpdates,
                    notifySavedEventUpdates: eventUpdates,
                    notifyNewReviews: newFollowers,
                    notifyBadges: newFollowers
                )
            )
            errorMessage = nil
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct NativeFeedbackHubView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category = "General Feedback"
    @State private var feedback = ""
    @State private var sent = false
    @State private var loading = false

    private let categories = ["General Feedback", "Feature Request", "Bug Report", "Other"]

    var body: some View {
        Group {
            if sent {
                VStack(spacing: 12) {
                    Text("✅")
                        .font(.system(size: 56))
                    Text("Thanks for your feedback!")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("We read every message and use it to improve FriendZone.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Back to Settings") {
                        dismiss()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .padding(.horizontal, 24)
                    .frame(height: 42)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            Picker("", selection: $category) {
                                ForEach(categories, id: \.self) { item in
                                    Text(item).tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Message")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            TextEditor(text: $feedback)
                                .font(.system(size: 15))
                                .frame(height: 160)
                                .padding(8)
                                .background(FriendZoneTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                                }
                        }

                        Button {
                            Task {
                                loading = true
                                try? await Task.sleep(nanoseconds: 600_000_000)
                                loading = false
                                sent = true
                            }
                        } label: {
                            Text(loading ? "Sending..." : "Send Feedback")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(FriendZoneTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(loading || feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((loading || feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
                    }
                    .padding(16)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NativeReportProblemHubView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reason = "Other"
    @State private var details = ""
    @State private var sent = false
    @State private var loading = false

    private let reasons = ["Spam", "Fake / Scam", "Harassment / Hate", "Inappropriate content", "Other"]

    var body: some View {
        Group {
            if sent {
                VStack(spacing: 12) {
                    Text("✅")
                        .font(.system(size: 56))
                    Text("Report submitted!")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXL, weight: .bold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    Text("Our moderation team will review this report.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Button("Back") {
                        dismiss()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textInverse)
                    .padding(.horizontal, 24)
                    .frame(height: 42)
                    .background(FriendZoneTheme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Problem Type")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            Picker("", selection: $reason) {
                                ForEach(reasons, id: \.self) { item in
                                    Text(item).tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(FriendZoneTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.size2XS, weight: .bold))
                                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
                                .tracking(0.5)
                            TextEditor(text: $details)
                                .font(.system(size: 15))
                                .frame(height: 160)
                                .padding(8)
                                .background(FriendZoneTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.5)
                                }
                        }

                        Button {
                            Task {
                                loading = true
                                try? await Task.sleep(nanoseconds: 600_000_000)
                                loading = false
                                sent = true
                            }
                        } label: {
                            Text(loading ? "Submitting..." : "Submit Report")
                                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                                .foregroundColor(FriendZoneTheme.Colors.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(FriendZoneTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(loading || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((loading || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
                    }
                    .padding(16)
                }
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle("Report a Problem")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum HubNavigationMapper {
    static func parseServerDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    static func mapHangoutFeed(_ item: HangoutFeedItem, currentUserID: Int?) -> HangoutItem? {
        guard
            let startAt = parseServerDate(item.startAt),
            let endAt = parseServerDate(item.endAt)
        else {
            return nil
        }

        let isJoined = item.participants.contains {
            $0.user == currentUserID && $0.status.lowercased() == "approved"
        }
        let participantNames = item.participants
            .filter { $0.status.lowercased() == "approved" && $0.user != item.host }
            .map(\.username)

        return HangoutItem(
            id: item.id,
            sourceType: mapSourceType(item.sourceType),
            title: item.title,
            description: item.description,
            vibe: mapVibe(item.vibe),
            cityName: item.cityName,
            locationName: item.locationName,
            locationAddress: item.locationAddress,
            latitude: item.lat,
            longitude: item.lng,
            hostUserID: item.host,
            hostName: item.host == currentUserID ? "you" : item.hostUsername,
            startAt: startAt,
            endAt: endAt,
            capacity: item.capacity,
            isCapacityUnlimited: item.isCapacityUnlimited,
            approvedCount: item.approvedParticipantsCount ?? max(1, participantNames.count + 1),
            isJoined: isJoined || item.host == currentUserID,
            participantNames: participantNames,
            coverImageData: nil,
            coverImageURL: item.coverImageUrl,
            coverSeed: item.id,
            distanceKm: 1.2,
            priceTier: .free,
            visibility: item.visibility.flatMap(HangoutVisibilityOption.init(backendRawValue:)),
            inviteCode: item.inviteCode,
            inviteCodeHint: item.inviteCodeHint,
            allowWaitlist: item.allowWaitlist,
            genderPreference: item.genderPreference.flatMap(HangoutGenderPreference.init(backendRawValue:)),
            audienceTags: item.audienceTags,
            languages: item.languages,
            isTimeFlexible: item.isTimeFlexible,
            sourceEventID: item.sourceEventId,
            sourceOfferID: item.sourceOfferId
        )
    }

    static func mapSoloPlanItem(_ item: EventSoloJoinFeedItem) -> SoloPlanItem? {
        guard let startAt = parseServerDate(item.startAt) else { return nil }
        return SoloPlanItem(
            id: item.id,
            eventID: item.eventId,
            title: item.eventTitle,
            startAt: startAt,
            venueName: item.venueName,
            creatorName: item.creatorName
        )
    }

    static func mapEventDetail(_ item: EventDetailFeedItem) -> HangoutsView.DiscoveryEventItem? {
        guard let startAt = parseServerDate(item.startAt) else { return nil }
        let venue = item.venueName ?? item.city ?? "Event venue"
        let displayName = item.creatorDisplayName ?? item.creatorUsername ?? item.organizerName ?? "Event creator"
        let photos = item.photos.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        let photoMoments = photos.map { photo in
            HangoutsView.EventPhotoMoment(
                id: photo.id,
                title: item.title,
                subtitle: venue,
                symbol: "photo",
                palette: [Color(hex: "#171717"), Color(hex: "#525252"), Color(hex: "#A3A3A3")],
                imageURL: photo.imageUrl
            )
        }

        return HangoutsView.DiscoveryEventItem(
            id: item.id,
            title: item.title,
            venue: venue,
            startAt: startAt,
            groups: max(item.totalParticipants ?? 0, 1),
            category: item.categoryDisplay ?? item.category ?? "Event",
            creatorProfile: CreatorProfileDraft(
                userID: item.creator,
                displayName: displayName,
                username: item.creatorUsername,
                bio: item.description ?? "\(venue) · \(item.categoryDisplay ?? item.category ?? "Event")",
                instagram: item.creatorUsername ?? "",
                website: "",
                city: item.city ?? "",
                avatarURL: item.creatorAvatarUrl
            ),
            photoMoments: photoMoments
        )
    }

    static func hangoutJoinStatus(_ item: HangoutFeedItem, currentUserID: Int?) -> HangoutJoinStatus {
        if item.host == currentUserID || item.participants.contains(where: { $0.user == currentUserID && $0.status.lowercased() == "approved" }) {
            return .joined
        }
        if item.joinRequests.contains(where: {
            $0.user == currentUserID && ["pending", "waitlisted"].contains($0.status.lowercased())
        }) {
            return .requested
        }
        return .none
    }

    private static func mapSourceType(_ raw: String) -> HangoutSourceType {
        switch raw.lowercased() {
        case "event":
            return .event
        case "offer":
            return .offer
        default:
            return .hangout
        }
    }

    private static func mapVibe(_ raw: String) -> HangoutVibe {
        switch raw.lowercased() {
        case "drinks":
            return .drinks
        case "sporty", "outdoors":
            return .sporty
        case "food":
            return .foodie
        case "creative", "culture", "board games":
            return .activity
        case "deep talks":
            return .deepTalk
        default:
            return .chill
        }
    }
}

private struct HubEventDestinationView: View {
    @EnvironmentObject private var session: AppSessionStore
    let eventID: Int
    let onClose: () -> Void
    @State private var event: HangoutsView.DiscoveryEventItem?
    @State private var errorMessage: String?
    @State private var isPresentingCreate = false

    var body: some View {
        Group {
            if let event {
                NativeEventDetailView(
                    event: event,
                    creatorProfile: event.creatorProfile,
                    onClose: onClose,
                    onJoinSoloSuccess: onClose,
                    onCreateHangout: {
                        isPresentingCreate = true
                    },
                    onShowCreatorProfile: {}
                )
            } else if let errorMessage {
                hubLoadFailure(message: errorMessage)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await load()
        }
        .fullScreenCover(isPresented: $isPresentingCreate) {
            CreateHangoutView(
                onCancel: { isPresentingCreate = false },
                onCreated: { _ in
                    onClose()
                },
                initialDraft: CreateHangoutDraft(
                    sourceType: .event,
                    sourceLabel: event?.title,
                    sourceEventID: eventID,
                    sourceOfferID: nil
                )
            )
            .background(FriendZoneTheme.Colors.background.ignoresSafeArea())
        }
    }

    @MainActor
    private func load() async {
        guard event == nil else { return }
        do {
            let detail = try await session.fetchEventDetail(id: eventID)
            event = HubNavigationMapper.mapEventDetail(detail)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct HubHangoutDestinationView: View {
    @EnvironmentObject private var session: AppSessionStore
    let hangoutID: Int
    let onClose: () -> Void
    @State private var hangout: HangoutItem?
    @State private var joinStatus: HangoutJoinStatus = .none
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let hangout {
                HangoutDetailView(
                    hangout: hangout,
                    joinStatus: joinStatus,
                    onRequestJoin: { joinStatus = .requested },
                    onCancelRequest: { joinStatus = .none }
                )
            } else if let errorMessage {
                hubLoadFailure(message: errorMessage)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await load()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { onClose() }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

        @MainActor
        private func load() async {
            guard hangout == nil else { return }
            do {
                let detail = try await session.fetchHangoutDetail(id: hangoutID)
                let currentUserID = session.currentUser?.id ?? session.currentProfile?.user?.id
                hangout = HubNavigationMapper.mapHangoutFeed(detail, currentUserID: currentUserID)
                joinStatus = HubNavigationMapper.hangoutJoinStatus(detail, currentUserID: currentUserID)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
}

@ViewBuilder
private func hubLoadFailure(message: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.error)
        Text("Could not open destination")
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeLG, weight: .bold))
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
        Text(message)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FriendZoneTheme.Colors.background)
}

private struct BlockedUserItem: Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let accent: Color
}

#if DEBUG
struct HangoutsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HangoutsView()
        }
    }
}
#endif
