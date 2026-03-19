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
    var friendsCount: Int?
    var hostRating: Double?
    var hangoutsHosted: Int?
    var reviewsCount: Int?
    var interests: [String]
    var vibes: [String]
    var age: Int?
    var gender: String?
    var verifiedProfile: Bool
    var isPremium: Bool
    var friendStatus: FriendStatus

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
        friendsCount: Int? = nil,
        hostRating: Double? = nil,
        hangoutsHosted: Int? = nil,
        reviewsCount: Int? = nil,
        interests: [String] = [],
        vibes: [String] = [],
        age: Int? = nil,
        gender: String? = nil,
        verifiedProfile: Bool = false,
        isPremium: Bool = false,
        friendStatus: FriendStatus = .none
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
        self.friendsCount = friendsCount
        self.hostRating = hostRating
        self.hangoutsHosted = hangoutsHosted
        self.reviewsCount = reviewsCount
        self.interests = interests
        self.vibes = vibes
        self.age = age
        self.gender = gender
        self.verifiedProfile = verifiedProfile
        self.isPremium = isPremium
        self.friendStatus = friendStatus
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
            friendsCount: publicProfile.friendsCount,
            hostRating: publicProfile.hostRating,
            hangoutsHosted: publicProfile.hangoutsHosted,
            reviewsCount: publicProfile.reviewsCount,
            interests: publicProfile.interests ?? [],
            vibes: publicProfile.vibes ?? [],
            age: publicProfile.age,
            gender: publicProfile.gender,
            verifiedProfile: publicProfile.verifiedProfile ?? false,
            isPremium: publicProfile.isPremium ?? false,
            friendStatus: publicProfile.friendStatus
        )
    }

    var initial: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0) } ?? "F"
    }

    var socialCount: Int? {
        friendsCount ?? followersCount
    }

    var socialCountLabel: String {
        friendsCount != nil ? "Friends" : "Followers"
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
    @State private var isUpdatingFriendship = false
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
            VStack(spacing: 12) {
                publicProfileCard
                    .padding(.horizontal, 16)
                    .padding(.top, FriendZoneTheme.Chrome.topOffset)

                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.error)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
                    .frame(height: 20)
            }
        }
        .background(FriendZoneTheme.Colors.background)
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

            if canManageFriendship {
                friendshipActionButton
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
        profile.socialCount != nil ||
        profile.hangoutsHosted != nil ||
        profile.reviewsCount != nil ||
        profile.hostRating != nil
    }

    private var profileStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            if let socialCount = profile.socialCount {
                profileStatCard(label: profile.socialCountLabel, value: "\(socialCount)")
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

    private var canManageFriendship: Bool {
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
    private func handleFriendshipAction() async {
        guard let userID = profile.userID else { return }
        isUpdatingFriendship = true
        defer { isUpdatingFriendship = false }

        do {
            let response = try await session.manageFriendship(userID: userID)
            profile.friendStatus = response.friendStatus
            if let targetFriendsCount = response.targetFriendsCount {
                profile.friendsCount = targetFriendsCount
            }
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    private var friendshipActionButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await handleFriendshipAction()
                }
            } label: {
                Text(isUpdatingFriendship ? "Updating..." : friendshipPrimaryLabel)
                    .font(FriendZoneTheme.Typography.system(13, weight: .bold))
                    .foregroundColor(friendshipButtonForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(friendshipButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isUpdatingFriendship)

            if profile.friendStatus == .incomingRequest {
                Button("Decline") {
                    Task {
                        await declineFriendRequest()
                    }
                }
                .font(FriendZoneTheme.Typography.system(12, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .disabled(isUpdatingFriendship)
            }
        }
    }

    @MainActor
    private func declineFriendRequest() async {
        guard let userID = profile.userID else { return }
        isUpdatingFriendship = true
        defer { isUpdatingFriendship = false }

        do {
            let response = try await session.declineFriendRequest(userID: userID)
            profile.friendStatus = response.friendStatus
            if let targetFriendsCount = response.targetFriendsCount {
                profile.friendsCount = targetFriendsCount
            }
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    private var friendshipPrimaryLabel: String {
        switch profile.friendStatus {
        case .none:
            return "Add Friend"
        case .outgoingRequest:
            return "Requested"
        case .incomingRequest:
            return "Accept Friend"
        case .friends:
            return "Friends"
        case .selfProfile:
            return "You"
        }
    }

    private var friendshipButtonBackground: Color {
        switch profile.friendStatus {
        case .none, .incomingRequest:
            return FriendZoneTheme.Colors.primary
        case .outgoingRequest, .friends, .selfProfile:
            return Color.black.opacity(0.05)
        }
    }

    private var friendshipButtonForeground: Color {
        switch profile.friendStatus {
        case .none, .incomingRequest:
            return .white
        case .outgoingRequest, .friends, .selfProfile:
            return FriendZoneTheme.Colors.textPrimary
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

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
