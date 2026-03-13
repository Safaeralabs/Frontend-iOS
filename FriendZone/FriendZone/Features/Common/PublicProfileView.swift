import SwiftUI

struct PublicProfileData: Identifiable, Equatable {
    let id: String
    var userID: Int?
    var displayName: String
    var username: String?
    var bio: String
    var instagram: String
    var website: String
    var city: String
    var avatarURL: String?
    var followersCount: Int?
    var hostRating: Double?
    var hangoutsHosted: Int?
    var reviewsCount: Int?
    var interests: [String]
    var vibes: [String]
    var age: Int?
    var gender: String?
    var verifiedProfile: Bool
    var isPremium: Bool
    var isFollowing: Bool

    init(
        id: String,
        userID: Int? = nil,
        displayName: String,
        username: String? = nil,
        bio: String,
        instagram: String,
        website: String,
        city: String,
        avatarURL: String? = nil,
        followersCount: Int? = nil,
        hostRating: Double? = nil,
        hangoutsHosted: Int? = nil,
        reviewsCount: Int? = nil,
        interests: [String] = [],
        vibes: [String] = [],
        age: Int? = nil,
        gender: String? = nil,
        verifiedProfile: Bool = false,
        isPremium: Bool = false,
        isFollowing: Bool = false
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.username = username
        self.bio = bio
        self.instagram = instagram
        self.website = website
        self.city = city
        self.avatarURL = avatarURL
        self.followersCount = followersCount
        self.hostRating = hostRating
        self.hangoutsHosted = hangoutsHosted
        self.reviewsCount = reviewsCount
        self.interests = interests
        self.vibes = vibes
        self.age = age
        self.gender = gender
        self.verifiedProfile = verifiedProfile
        self.isPremium = isPremium
        self.isFollowing = isFollowing
    }

    init(draft: CreatorProfileDraft) {
        self.init(
            id: draft.id.uuidString,
            userID: draft.userID,
            displayName: draft.displayName,
            username: draft.username,
            bio: draft.bio,
            instagram: draft.instagram,
            website: draft.website,
            city: draft.city,
            avatarURL: draft.avatarURL,
            followersCount: draft.followersCount,
            hostRating: draft.hostRating
        )
    }

    init(publicProfile: PublicUserProfile) {
        let displayNameParts = [publicProfile.user.firstName, publicProfile.user.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = displayNameParts.isEmpty ? publicProfile.user.username.capitalized : displayNameParts.joined(separator: " ")

        self.init(
            id: String(publicProfile.user.id),
            userID: publicProfile.user.id,
            displayName: displayName,
            username: publicProfile.user.username,
            bio: publicProfile.bio ?? "",
            instagram: publicProfile.instagramUsername ?? "",
            website: publicProfile.linkedinURL ?? "",
            city: publicProfile.cityName ?? "",
            avatarURL: publicProfile.avatarURL,
            followersCount: publicProfile.followersCount,
            hostRating: publicProfile.hostRating,
            hangoutsHosted: publicProfile.hangoutsHosted,
            reviewsCount: publicProfile.reviewsCount,
            interests: publicProfile.interests ?? [],
            vibes: publicProfile.vibes ?? [],
            age: publicProfile.age,
            gender: publicProfile.gender,
            verifiedProfile: publicProfile.verifiedProfile ?? false,
            isPremium: publicProfile.isPremium ?? false
        )
    }

    var initial: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0) } ?? "F"
    }
}

struct CreatorProfileDraft: Identifiable, Equatable {
    let id: UUID
    var userID: Int?
    var displayName: String
    var username: String?
    var bio: String
    var instagram: String
    var website: String
    var city: String
    var avatarURL: String?
    var followersCount: Int?
    var hostRating: Double?

    init(
        id: UUID = .init(),
        userID: Int? = nil,
        displayName: String,
        username: String? = nil,
        bio: String,
        instagram: String,
        website: String,
        city: String,
        avatarURL: String? = nil,
        followersCount: Int? = nil,
        hostRating: Double? = nil
    ) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.username = username
        self.bio = bio
        self.instagram = instagram
        self.website = website
        self.city = city
        self.avatarURL = avatarURL
        self.followersCount = followersCount
        self.hostRating = hostRating
    }

    static let sample = CreatorProfileDraft(
        displayName: "FriendZone Labs",
        bio: "Creating curated social experiences across your city.",
        instagram: "friendzone",
        website: "https://friendzone.app",
        city: "Munich"
    )

    var initial: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0) } ?? "F"
    }
}

struct PublicProfileView: View {
    @EnvironmentObject private var session: AppSessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var profile: PublicProfileData
    @State private var isLoadingRemoteProfile = false
    @State private var isTogglingFollow = false
    @State private var loadErrorMessage: String?

    let leadingText: String
    let highlightText: String
    let subtitle: String?
    var onClose: (() -> Void)? = nil

    init(
        profile: PublicProfileData,
        leadingText: String,
        highlightText: String,
        subtitle: String?,
        onClose: (() -> Void)? = nil
    ) {
        _profile = State(initialValue: profile)
        self.leadingText = leadingText
        self.highlightText = highlightText
        self.subtitle = subtitle
        self.onClose = onClose
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                FriendZoneModuleHeader(
                    leadingText: leadingText,
                    highlightText: highlightText,
                    subtitle: subtitle
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                publicProfileCard
                    .padding(.horizontal, 16)

                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(FriendZoneTheme.Typography.system(13, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if hasProfileSignals {
                    profileSignalsSection
                        .padding(.horizontal, 16)
                }

                profileBioSection
                    .padding(.horizontal, 16)

                if hasProfileLinks {
                    profileLinks
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 0)
                    .frame(height: 32)
            }
        }
        .background(FriendZoneTheme.Colors.background)
        .navigationTitle(highlightText.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await hydrateRemoteProfileIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    close()
                }
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
        }
    }

    private var publicProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#0F172A"), Color(hex: "#0E7490"), Color(hex: "#2563EB")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 148)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 70, height: 70)
                            .overlay { avatarContent }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(profile.displayName)
                                .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                                .foregroundColor(.white)

                            if let username = profile.username, !username.isEmpty {
                                Text("@\(username)")
                                    .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.72))
                            }

                            Text(profileMetaSummary)
                                .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.86))
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        if !profile.city.isEmpty {
                            inverseProfileChip(icon: "📍", label: profile.city)
                        }
                        if profile.verifiedProfile {
                            inverseProfileChip(icon: "✅", label: "Verified")
                        }
                        if profile.isPremium {
                            inverseProfileChip(icon: "✨", label: "Premium")
                        }
                    }
                }
                .padding(18)
            }

            if hasStats {
                profileStatsGrid
            }

            if canToggleFollow {
                Button {
                    Task {
                        await toggleFollow()
                    }
                } label: {
                    Text(isTogglingFollow ? "Updating..." : (profile.isFollowing ? "Following" : "Follow"))
                        .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                        .foregroundColor(profile.isFollowing ? FriendZoneTheme.Colors.textPrimary : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(profile.isFollowing ? Color.black.opacity(0.05) : FriendZoneTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isTogglingFollow)
            }
        }
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
        }
    }

    private var profileMetaSummary: String {
        var parts: [String] = []
        if let age = profile.age {
            parts.append("\(age)")
        }
        if let gender = profile.gender?.trimmingCharacters(in: .whitespacesAndNewlines), !gender.isEmpty {
            parts.append(gender.capitalized)
        }
        return parts.isEmpty ? "FriendZone member" : parts.joined(separator: " · ")
    }

    private var hasStats: Bool {
        profile.followersCount != nil ||
        profile.hangoutsHosted != nil ||
        profile.reviewsCount != nil ||
        profile.hostRating != nil
    }

    private var profileStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            if let followersCount = profile.followersCount {
                profileStatCard(label: "Followers", value: "\(followersCount)")
            }
            if let hangoutsHosted = profile.hangoutsHosted {
                profileStatCard(label: "Hosted", value: "\(hangoutsHosted)")
            }
            if let reviewsCount = profile.reviewsCount {
                profileStatCard(label: "Reviews", value: "\(reviewsCount)")
            }
            if let hostRating = profile.hostRating {
                profileStatCard(label: "Host rating", value: String(format: "%.1f", hostRating))
            }
        }
    }

    private func profileStatCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(FriendZoneTheme.Typography.system(17, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(label.uppercased())
                .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(FriendZoneTheme.Colors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var hasProfileSignals: Bool {
        !profile.vibes.isEmpty || !profile.interests.isEmpty
    }

    private var profileSignalsSection: some View {
        VStack(spacing: 12) {
            if !profile.vibes.isEmpty {
                profileTagSection(
                    title: "Vibes",
                    subtitle: "Usually brings this energy.",
                    tags: profile.vibes,
                    icon: "✨"
                )
            }

            if !profile.interests.isEmpty {
                profileTagSection(
                    title: "Interests",
                    subtitle: "Things they usually lean into.",
                    tags: profile.interests,
                    icon: "🎯"
                )
            }
        }
    }

    private func profileTagSection(title: String, subtitle: String, tags: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(FriendZoneTheme.Typography.system(11, weight: .medium))
                    .foregroundColor(FriendZoneTheme.Colors.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 6) {
                        Text(icon)
                        Text(tag)
                            .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(FriendZoneTheme.Colors.surfaceMuted)
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
        }
    }

    private var profileBioSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About")
                .font(FriendZoneTheme.Typography.system(12, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.textTertiary)

            Text(profile.bio.isEmpty ? "No bio shared yet." : profile.bio)
                .font(FriendZoneTheme.Typography.system(14, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
        }
    }

    private var hasProfileLinks: Bool {
        !profile.instagram.isEmpty || !profile.website.isEmpty
    }

    private var profileLinks: some View {
        VStack(spacing: 10) {
            if !profile.instagram.isEmpty {
                profileLinkRow(icon: "at", title: "Instagram", value: "@\(profile.instagram)")
            }
            if let url = URL(string: profile.website), !profile.website.isEmpty {
                let isLinkedIn = profile.website.lowercased().contains("linkedin")
                profileLinkRow(
                    icon: isLinkedIn ? "briefcase" : "link",
                    title: isLinkedIn ? "LinkedIn" : "Website",
                    value: profile.website,
                    url: url
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(FriendZoneTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1.2)
        }
    }

    private var canToggleFollow: Bool {
        if let userID = profile.userID, let currentUserID = session.currentUser?.id {
            return userID != currentUserID
        }
        return false
    }

    @MainActor
    private func hydrateRemoteProfileIfNeeded() async {
        guard let userID = profile.userID else { return }
        isLoadingRemoteProfile = true
        defer { isLoadingRemoteProfile = false }

        do {
            let publicProfile = try await session.fetchPublicProfile(userID: userID)
            profile = PublicProfileData(publicProfile: publicProfile)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleFollow() async {
        guard let userID = profile.userID else { return }
        isTogglingFollow = true
        defer { isTogglingFollow = false }

        do {
            let isFollowing = try await session.toggleFollow(userID: userID)
            profile.isFollowing = isFollowing
            if let count = profile.followersCount {
                profile.followersCount = max(0, count + (isFollowing ? 1 : -1))
            }
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let avatarURL = profile.avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Text(profile.initial)
                    .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                    .foregroundColor(.white)
            }
            .clipShape(Circle())
        } else {
            Text(profile.initial)
                .font(FriendZoneTheme.Typography.system(24, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func inverseProfileChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(label)
                .font(FriendZoneTheme.Typography.system(11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.white.opacity(0.14))
        .clipShape(Capsule())
    }

    private func profileLinkRow(icon: String, title: String, value: String, url: URL? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
                .frame(width: 32, height: 32)
                .background(FriendZoneTheme.Colors.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(FriendZoneTheme.Typography.system(10, weight: .bold))
                    .foregroundColor(FriendZoneTheme.Colors.textTertiary)

                if let url = url {
                    Link(value, destination: url)
                        .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                } else {
                    Text(value)
                        .font(FriendZoneTheme.Typography.system(14, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                }
            }

            Spacer()
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
