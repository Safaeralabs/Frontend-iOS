import Foundation
import Combine
import Security

struct AuthenticatedUser: Decodable, Equatable {
    let id: Int
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    let hasProfile: Bool?
    let isEventCreator: Bool?
    let isVenueOwner: Bool?
    let onboardingCompleted: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case pk
        case username
        case email
        case firstName
        case lastName
        case hasProfile
        case isEventCreator
        case isVenueOwner
        case onboardingCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
            ?? container.decode(Int.self, forKey: .pk)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        hasProfile = try container.decodeIfPresent(Bool.self, forKey: .hasProfile)
        isEventCreator = try container.decodeIfPresent(Bool.self, forKey: .isEventCreator)
        isVenueOwner = try container.decodeIfPresent(Bool.self, forKey: .isVenueOwner)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
    }
}

struct SessionProfileUser: Codable, Equatable {
    let id: Int
    let username: String
    let firstName: String?
    let lastName: String?
}

struct PublicUserProfile: Codable, Equatable, Identifiable {
    struct NestedUser: Codable, Equatable {
        let id: Int
        let username: String
        let firstName: String?
        let lastName: String?
    }

    let user: NestedUser
    let avatarURL: String?
    let bio: String?
    let age: Int?
    let gender: String?
    let cityName: String?
    let interests: [String]?
    let vibes: [String]?
    let hangoutsHosted: Int?
    let hostRating: Double?
    let reviewsCount: Int?
    let followersCount: Int?
    let verifiedProfile: Bool?
    let isPremium: Bool?
    let completionScore: Int?
    let instagramUsername: String?
    let linkedinURL: String?

    var id: Int { user.id }
}

struct SessionProfile: Codable, Equatable {
    let user: SessionProfileUser?
    let avatarImageUrl: String?
    let bio: String?
    let cityName: String?
    let cityPlaceId: String?
    let spokenLanguages: [String]?
    let interests: [String]?
    let vibes: [String]?
    let availabilitySchedule: [String]?
    let preferredGroupSize: String?
    let interestedIn: [String]?
    let gender: String?
    let instagramUsername: String?
    let followersCount: Int?
    let followingCount: Int?
    let hangoutsAttended: Int?
    let hangoutsHosted: Int?
    let hostRating: Double?
    let completionScore: Int?
    let onboardingCompleted: Bool
    let isEventCreator: Bool?
    let isVenueOwner: Bool?
}

struct OnboardingSubmission {
    struct Language: Equatable {
        let code: String
        let level: String
    }

    let name: String
    let avatar: String
    let city: String
    let cityPlaceId: String
    let spokenLanguages: [Language]
    let interests: [String]
    let vibes: [String]
    let availability: [String]
    let groupSize: String
    let activityTypes: [String]
    let gender: String
}

struct ProfileUpdateSubmission {
    let displayName: String
    let city: String
    let bio: String
    let instagramUsername: String
}

struct DiscoveryEventFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let venueName: String?
    let city: String?
    let cityPlaceId: String?
    let lat: Double?
    let lng: Double?
    let startAt: String
    let endAt: String?
    let category: String?
    let primaryImageUrl: String?
    let creator: Int?
    let creatorUsername: String?
    let creatorDisplayName: String?
    let creatorAvatarUrl: String?
    let spotsRemaining: Int?
    let hangoutsCount: Int?
}

struct DiscoveryOfferFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String?
    let perk: String
    let venueName: String?
    let owner: Int?
    let ownerUsername: String?
    let validUntil: String
    let spotsRemaining: Int?
}

struct EventDetailPhotoItem: Decodable, Identifiable, Equatable {
    let id: Int
    let imageUrl: String?
    let isPrimary: Bool?
    let sortOrder: Int?
}

struct EventDetailFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String?
    let creator: Int?
    let creatorUsername: String?
    let creatorDisplayName: String?
    let creatorAvatarUrl: String?
    let organizerName: String?
    let venueName: String?
    let venueAddress: String?
    let city: String?
    let cityPlaceId: String?
    let startAt: String
    let endAt: String?
    let capacity: Int?
    let spotsRemaining: Int?
    let totalParticipants: Int?
    let category: String?
    let categoryDisplay: String?
    let primaryImageUrl: String?
    let photos: [EventDetailPhotoItem]
    let tags: [String]?
}

struct OfferVenueDetailItem: Decodable, Equatable {
    let id: Int
    let name: String
    let city: String?
    let cityPlaceId: String?
    let category: String?
    let googlePlaceId: String?
    let lat: Double?
    let lng: Double?
}

struct OfferDetailFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String?
    let perk: String
    let venue: Int?
    let venueName: String?
    let venueDetail: OfferVenueDetailItem?
    let owner: Int?
    let ownerUsername: String?
    let validFrom: String?
    let validUntil: String
    let capacity: Int?
    let claimsUsed: Int?
    let spotsRemaining: Int?
    let terms: String?
    let hangoutId: Int?
}

struct CreatorEventFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let category: String?
    let venueName: String?
    let startAt: String
    let capacity: Int?
    let hangoutsCount: Int?
    let status: String
}

struct CreatorVenueFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let category: String
    let status: String
    let city: String
    let address: String
    let totalHangouts: Int?
    let totalOffers: Int?
    let totalPeopleReached: Int?
    let isVerified: Bool?
}

struct CreatorOfferFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let perk: String
    let status: String
    let venueName: String?
    let validUntil: String
    let recurrenceDisplay: String?
    let claimsUsed: Int?
    let capacity: Int?
}

struct HangoutParticipantFeedItem: Decodable, Equatable {
    let id: Int
    let user: Int
    let username: String
    let status: String
}

struct HangoutJoinRequestFeedItem: Decodable, Equatable {
    let id: Int
    let user: Int
    let userUsername: String
    let message: String?
    let status: String
}

struct HangoutFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let host: Int
    let hostUsername: String
    let title: String
    let description: String
    let coverImageUrl: String?
    let cityName: String
    let locationName: String?
    let lat: Double?
    let lng: Double?
    let startAt: String
    let endAt: String
    let capacity: Int
    let approvedParticipantsCount: Int?
    let status: String
    let sourceType: String
    let sourceEventId: Int?
    let sourceOfferId: Int?
    let vibe: String
    let isMicro: Bool
    let isLive: Bool
    let participants: [HangoutParticipantFeedItem]
    let joinRequests: [HangoutJoinRequestFeedItem]
}

struct HangoutMessageFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    let userUsername: String
    let message: String
    let createdAt: String
    let updatedAt: String?
    let isEdited: Bool?
}

struct AppNotificationFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let type: String
    let typeDisplay: String
    let title: String
    let message: String
    let actionURL: String?
    let relatedHangoutId: Int?
    let relatedEventId: Int?
    let relatedUserId: Int?
    let read: Bool
    let readAt: String?
    let createdAt: String
    let timeAgo: String
}

struct NotificationUnreadCountResponse: Decodable, Equatable {
    let unreadCount: Int
}

struct NotificationMarkAllReadResponse: Decodable, Equatable {
    let status: String
    let markedCount: Int
    let message: String
}

struct NotificationPreferencesFeedItem: Decodable, Equatable {
    let notifyJoinApproved: Bool
    let notifyJoinRejected: Bool
    let notifyNewJoinRequest: Bool
    let notifyHangoutCancelled: Bool
    let notifyHangoutChanged: Bool
    let notifyKicked: Bool
    let notifySpaceAvailable: Bool
    let notifyAmbitionMatches: Bool
    let notifyMatchUpdates: Bool
    let notifyEventStartingSoon: Bool
    let notifyNewEvents: Bool
    let notifySavedEventUpdates: Bool
    let notifyNewReviews: Bool
    let notifyBadges: Bool
}

struct NotificationPreferencesUpdateRequest: Encodable {
    let notifyJoinApproved: Bool
    let notifyJoinRejected: Bool
    let notifyNewJoinRequest: Bool
    let notifyHangoutCancelled: Bool
    let notifyHangoutChanged: Bool
    let notifyKicked: Bool
    let notifySpaceAvailable: Bool
    let notifyAmbitionMatches: Bool
    let notifyMatchUpdates: Bool
    let notifyEventStartingSoon: Bool
    let notifyNewEvents: Bool
    let notifySavedEventUpdates: Bool
    let notifyNewReviews: Bool
    let notifyBadges: Bool
}

private struct EventSoloJoinResponse: Decodable {
    let id: Int
}

private struct HangoutMessageCreateRequest: Encodable {
    let message: String
}

struct CreateHangoutResponse: Decodable, Equatable {
    let id: Int
    let sourceType: String
    let title: String
    let description: String
    let cityName: String
    let locationName: String?
    let startAt: String
    let endAt: String
    let capacity: Int
    let approvedParticipantsCount: Int?
    let isLive: Bool
    let isMicro: Bool
    let hostUsername: String
}

private struct CreateHangoutPayload: Encodable {
    let languages: [String]
    let title: String
    let description: String
    let cityPlaceId: String
    let cityName: String
    let locationName: String
    let locationAddress: String
    let lat: Double?
    let lng: Double?
    let startAt: String?
    let endAt: String?
    let capacity: Int?
    let isCapacityUnlimited: Bool
    let isTimeFlexible: Bool
    let visibility: String
    let allowWaitlist: Bool
    let vibe: String
    let isMicro: Bool
    let isLive: Bool
    let genderPreference: String
    let audienceTags: [String]
    let sourceEventId: Int?

    private enum CodingKeys: String, CodingKey {
        case languages
        case title
        case description
        case cityPlaceId = "city_place_id"
        case cityName = "city_name"
        case locationName = "location_name"
        case locationAddress = "location_address"
        case lat
        case lng
        case startAt = "start_at"
        case endAt = "end_at"
        case capacity
        case isCapacityUnlimited = "is_capacity_unlimited"
        case isTimeFlexible = "is_time_flexible"
        case visibility
        case allowWaitlist = "allow_waitlist"
        case vibe
        case isMicro = "is_micro"
        case isLive = "is_live"
        case genderPreference = "gender_preference"
        case audienceTags = "audience_tags"
        case sourceEventId = "source_event_id"
    }
}

private struct AuthTokenPair: Codable {
    let access: String
    let refresh: String
}

private struct EmptyResponse: Decodable {}

private struct AuthSessionPayload: Decodable {
    let user: AuthenticatedUser
    let access: String
    let refresh: String
}

private struct AppleLoginRequest: Encodable {
    let code: String
    let idToken: String?
}

private struct GoogleLoginRequest: Encodable {
    let code: String
    let redirectUri: String
}

private struct TokenRefreshPayload: Decodable {
    let access: String
    let refresh: String?
}

private struct CompleteOnboardingRequest: Encodable {
    let name: String
    let avatar: String
    let city: String
    let cityPlaceId: String
    let languages: [[String: String]]
    let spokenLanguages: [String]
    let interests: [String]
    let vibes: [String]
    let availability: [String]
    let groupSize: String
    let activityTypes: [String]
    let interestedIn: [String]
    let gender: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case avatar
        case city
        case cityPlaceId = "city_place_id"
        case languages
        case spokenLanguages = "spoken_languages"
        case interests
        case vibes
        case availability
        case groupSize
        case activityTypes
        case interestedIn = "interested_in"
        case gender
    }
}

private struct CompleteOnboardingResponse: Decodable {
    let message: String?
    let profile: SessionProfile
}

private struct FollowToggleResponse: Decodable {
    let action: String
    let followingId: Int?
    let followingCount: Int?
}

private struct UserPatchRequest: Encodable {
    let firstName: String
    let lastName: String
}

private struct ProfilePatchRequest: Encodable {
    let cityName: String
    let bio: String
    let instagramUsername: String
}

enum AppSessionError: LocalizedError {
    case invalidResponse
    case unauthorized
    case missingRefreshToken
    case httpStatus(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Session expired. Log in again to continue."
        case .missingRefreshToken:
            return "Missing refresh token. Log in again."
        case let .httpStatus(code, message):
            return "Request failed (\(code)): \(message)"
        case .decodingFailed:
            return "Could not decode server response."
        }
    }
}

final class AppSessionStore: ObservableObject {
    static let shared = AppSessionStore()

    @Published private(set) var isHydrating = false
    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var currentUser: AuthenticatedUser?
    @Published private(set) var currentProfile: SessionProfile?
    @Published private(set) var backendReachable = false

    private let authAPI: AuthAPIService
    private let profileAPI: ProfileAPIService
    private let discoverAPI: DiscoverAPIService
    private let notificationsAPI: NotificationsAPIService
    private let tokenStore: AuthTokenStore
    private let defaults: UserDefaults
    private var hasBootstrapped = false

    private static let isAuthenticatedKey = "fz.auth.isAuthenticated"
    private static let hasCompletedOnboardingKey = "fz.auth.hasCompletedOnboarding"

    fileprivate init(
        authAPI: AuthAPIService = AuthAPIService(),
        profileAPI: ProfileAPIService = ProfileAPIService(),
        discoverAPI: DiscoverAPIService = DiscoverAPIService(),
        notificationsAPI: NotificationsAPIService = NotificationsAPIService(),
        tokenStore: AuthTokenStore = AuthTokenStore(),
        defaults: UserDefaults = .standard
    ) {
        self.authAPI = authAPI
        self.profileAPI = profileAPI
        self.discoverAPI = discoverAPI
        self.notificationsAPI = notificationsAPI
        self.tokenStore = tokenStore
        self.defaults = defaults
        self.isAuthenticated = defaults.bool(forKey: Self.isAuthenticatedKey)
        self.hasCompletedOnboarding = defaults.object(forKey: Self.hasCompletedOnboardingKey) as? Bool ?? true
    }

    @MainActor
    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await restoreSession()
    }

    @MainActor
    func login(username: String, password: String) async throws {
        let payload = try await authAPI.login(username: username, password: password)
        try tokenStore.save(tokens: AuthTokenPair(access: payload.access, refresh: payload.refresh))
        currentUser = payload.user
        isAuthenticated = true
        persistState()
        try await refreshProfileState()
    }

    @MainActor
    func register(username: String, email: String, password: String, passwordConfirmation: String) async throws {
        let payload = try await authAPI.register(
            username: username,
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation
        )
        try tokenStore.save(tokens: AuthTokenPair(access: payload.access, refresh: payload.refresh))
        currentUser = payload.user
        isAuthenticated = true
        hasCompletedOnboarding = payload.user.onboardingCompleted ?? false
        persistState()
        try await refreshProfileState()
    }

    @MainActor
    func loginWithApple(authorizationCode: String, identityToken: String?) async throws {
        let payload = try await authAPI.loginWithApple(
            authorizationCode: authorizationCode,
            identityToken: identityToken
        )
        try tokenStore.save(tokens: AuthTokenPair(access: payload.access, refresh: payload.refresh))
        currentUser = payload.user
        isAuthenticated = true
        persistState()
        try await refreshProfileState()
    }

    @MainActor
    func loginWithGoogle(authorizationCode: String, redirectURI: String) async throws {
        let payload = try await authAPI.loginWithGoogle(
            authorizationCode: authorizationCode,
            redirectURI: redirectURI
        )
        try tokenStore.save(tokens: AuthTokenPair(access: payload.access, refresh: payload.refresh))
        currentUser = payload.user
        isAuthenticated = true
        persistState()
        try await refreshProfileState()
    }

    func requestPasswordReset(email: String) async throws {
        try await authAPI.requestPasswordReset(email: email)
    }

    @MainActor
    func refreshBackendReachability() async {
        backendReachable = await authAPI.pingBackend()
    }

    func fetchUpcomingEvents() async throws -> [DiscoveryEventFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchUpcomingEvents(accessToken: accessToken)
        }
    }

    func fetchActiveOffers() async throws -> [DiscoveryOfferFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchActiveOffers(accessToken: accessToken)
        }
    }

    func fetchEventDetail(id: Int) async throws -> EventDetailFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchEventDetail(id: id, accessToken: accessToken)
        }
    }

    func fetchOfferDetail(id: Int) async throws -> OfferDetailFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchOfferDetail(id: id, accessToken: accessToken)
        }
    }

    func fetchMyCreatorEvents() async throws -> [CreatorEventFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchMyCreatorEvents(accessToken: accessToken)
        }
    }

    func fetchMyCreatorVenues() async throws -> [CreatorVenueFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchMyCreatorVenues(accessToken: accessToken)
        }
    }

    func fetchMyCreatorOffers() async throws -> [CreatorOfferFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchMyCreatorOffers(accessToken: accessToken)
        }
    }

    func joinEventSolo(id: Int) async throws {
        _ = try await authorizedCall { [self] accessToken in
            try await discoverAPI.joinEventSolo(id: id, accessToken: accessToken)
        } as EventSoloJoinResponse
    }

    func fetchHangouts() async throws -> [HangoutFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchHangouts(accessToken: accessToken)
        }
    }

    func fetchHangoutDetail(id: Int) async throws -> HangoutFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchHangoutDetail(id: id, accessToken: accessToken)
        }
    }

    func requestJoinHangout(id: Int, message: String = "") async throws -> HangoutJoinRequestFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.requestJoinHangout(id: id, message: message, accessToken: accessToken)
        }
    }

    func leaveHangout(id: Int) async throws {
        _ = try await authorizedCall { [self] accessToken in
            try await discoverAPI.leaveHangout(id: id, accessToken: accessToken)
        } as EmptyResponse
    }

    func cancelHangout(id: Int) async throws {
        _ = try await authorizedCall { [self] accessToken in
            try await discoverAPI.cancelHangout(id: id, accessToken: accessToken)
        } as EmptyResponse
    }

    func createHangout(from draft: CreateHangoutDraft) async throws -> CreateHangoutResponse {
        if draft.sourceType == .offer {
            throw AppSessionError.httpStatus(400, "Offer-sourced hangouts are not exposed by the backend create endpoint yet.")
        }
        if draft.visibility == .inviteOnly {
            throw AppSessionError.httpStatus(400, "Private hangouts are not fully supported by the current backend create serializer yet.")
        }

        let payload = makeCreateHangoutPayload(from: draft)
        return try await authorizedCall { [self] accessToken in
            try await discoverAPI.createHangout(payload: payload, coverJPEGData: draft.coverImageData, accessToken: accessToken)
        }
    }

    func approveJoinRequest(hangoutID: Int, requestID: Int) async throws -> HangoutFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.approveJoinRequest(hangoutID: hangoutID, requestID: requestID, accessToken: accessToken)
        }
    }

    func rejectJoinRequest(hangoutID: Int, requestID: Int) async throws -> HangoutFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.rejectJoinRequest(hangoutID: hangoutID, requestID: requestID, accessToken: accessToken)
        }
    }

    func fetchHangoutMessages(hangoutID: Int) async throws -> [HangoutMessageFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchHangoutMessages(hangoutID: hangoutID, accessToken: accessToken)
        }
    }

    func sendHangoutMessage(hangoutID: Int, message: String) async throws -> HangoutMessageFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.sendHangoutMessage(hangoutID: hangoutID, message: message, accessToken: accessToken)
        }
    }

    func fetchNotifications(unreadOnly: Bool = false) async throws -> [AppNotificationFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await notificationsAPI.fetchNotifications(unreadOnly: unreadOnly, accessToken: accessToken)
        }
    }

    func markNotificationRead(id: Int) async throws -> AppNotificationFeedItem {
        try await authorizedCall { [self] accessToken in
            try await notificationsAPI.markNotificationRead(id: id, accessToken: accessToken)
        }
    }

    func markAllNotificationsRead(ids: [Int]? = nil) async throws -> NotificationMarkAllReadResponse {
        try await authorizedCall { [self] accessToken in
            try await notificationsAPI.markAllNotificationsRead(ids: ids, accessToken: accessToken)
        }
    }

    func fetchUnreadNotificationCount() async throws -> Int {
        let response = try await authorizedCall { [self] accessToken in
            try await notificationsAPI.fetchUnreadCount(accessToken: accessToken)
        }
        return response.unreadCount
    }

    func deleteNotification(id: Int) async throws {
        _ = try await authorizedCall { [self] accessToken in
            try await notificationsAPI.deleteNotification(id: id, accessToken: accessToken)
        } as EmptyResponse
    }

    func fetchNotificationPreferences() async throws -> NotificationPreferencesFeedItem {
        try await authorizedCall { [self] accessToken in
            try await notificationsAPI.fetchPreferences(accessToken: accessToken)
        }
    }

    func updateNotificationPreferences(_ payload: NotificationPreferencesUpdateRequest) async throws -> NotificationPreferencesFeedItem {
        try await authorizedCall { [self] accessToken in
            try await notificationsAPI.updatePreferences(payload: payload, accessToken: accessToken)
        }
    }

    @MainActor
    func completeOnboarding(_ submission: OnboardingSubmission) async throws {
        let request = CompleteOnboardingRequest(
            name: submission.name,
            avatar: submission.avatar,
            city: submission.city,
            cityPlaceId: submission.cityPlaceId,
            languages: submission.spokenLanguages.map { ["code": $0.code, "level": $0.level] },
            spokenLanguages: submission.spokenLanguages.map(\.code),
            interests: submission.interests,
            vibes: submission.vibes,
            availability: submission.availability,
            groupSize: submission.groupSize,
            activityTypes: submission.activityTypes,
            interestedIn: submission.activityTypes.isEmpty ? submission.interests : submission.activityTypes,
            gender: submission.gender.isEmpty ? nil : submission.gender
        )

        let nameParts = splitDisplayName(submission.name)
        if !nameParts.firstName.isEmpty || !nameParts.lastName.isEmpty {
            let updatedUser = try await authorizedCall { [self] accessToken in
                try await self.authAPI.updateCurrentUser(
                    payload: UserPatchRequest(
                        firstName: nameParts.firstName,
                        lastName: nameParts.lastName
                    ),
                    accessToken: accessToken
                )
            }
            currentUser = updatedUser
        }

        let profile = try await authorizedCall { [self] accessToken in
            try await self.profileAPI.completeOnboarding(payload: request, accessToken: accessToken)
        }

        currentProfile = profile
        hasCompletedOnboarding = profile.onboardingCompleted
        persistState()
    }

    @MainActor
    func updateProfile(_ submission: ProfileUpdateSubmission) async throws {
        let cleanedDisplayName = submission.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameParts = cleanedDisplayName.split(separator: " ", maxSplits: 1).map(String.init)
        let firstName = nameParts.first ?? ""
        let lastName = nameParts.count > 1 ? nameParts[1] : ""

        let updatedUser = try await authorizedCall { [self] accessToken in
            try await self.authAPI.updateCurrentUser(
                payload: UserPatchRequest(firstName: firstName, lastName: lastName),
                accessToken: accessToken
            )
        }

        let updatedProfile = try await authorizedCall { [self] accessToken in
            try await self.profileAPI.updateMyProfile(
                payload: ProfilePatchRequest(
                    cityName: submission.city,
                    bio: submission.bio,
                    instagramUsername: submission.instagramUsername.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                ),
                accessToken: accessToken
            )
        }

        currentUser = updatedUser
        currentProfile = updatedProfile
        hasCompletedOnboarding = updatedProfile.onboardingCompleted
        persistState()
    }

    @MainActor
    func uploadAvatar(jpegData: Data) async throws {
        let updatedProfile = try await authorizedCall { [self] accessToken in
            try await self.profileAPI.uploadAvatar(jpegData: jpegData, accessToken: accessToken)
        }
        currentProfile = updatedProfile
        hasCompletedOnboarding = updatedProfile.onboardingCompleted
        persistState()
    }

    func fetchPublicProfile(userID: Int) async throws -> PublicUserProfile {
        try await authorizedCall { [self] accessToken in
            try await self.profileAPI.fetchPublicProfile(userID: userID, accessToken: accessToken)
        }
    }

    func toggleFollow(userID: Int) async throws -> Bool {
        let response = try await authorizedCall { [self] accessToken in
            try await self.profileAPI.toggleFollow(userID: userID, accessToken: accessToken)
        }
        return response.action == "following"
    }

    @MainActor
    func logout() async {
        let accessToken = tokenStore.load()?.access
        let refreshToken = tokenStore.load()?.refresh
        if let refreshToken {
            try? await authAPI.logout(accessToken: accessToken, refreshToken: refreshToken)
        }
        clearSession()
    }

    var roleFlags: SettingsUserRoleFlags {
        SettingsUserRoleFlags(
            isEventCreator: currentProfile?.isEventCreator ?? currentUser?.isEventCreator ?? false,
            isVenueOwner: currentProfile?.isVenueOwner ?? currentUser?.isVenueOwner ?? false,
            isStaff: false
        )
    }

    @MainActor
    func hardLogout() {
        clearSession()
    }

    @MainActor
    private func restoreSession() async {
        guard tokenStore.load() != nil else {
            clearSession(persist: true)
            return
        }

        isHydrating = true
        defer { isHydrating = false }

        do {
            let user = try await authorizedCall { [self] accessToken in
                try await self.authAPI.fetchCurrentUser(accessToken: accessToken)
            }
            currentUser = user
            isAuthenticated = true
            persistState()
            try await refreshProfileState()
        } catch {
            clearSession()
        }
    }

    @MainActor
    private func refreshProfileState() async throws {
        let profile = try await authorizedCall { [self] accessToken in
            try await self.profileAPI.fetchMyProfile(accessToken: accessToken)
        }
        currentProfile = profile
        hasCompletedOnboarding = profile.onboardingCompleted
        persistState()
    }

    @MainActor
    private func authorizedCall<T>(_ operation: @escaping (String) async throws -> T) async throws -> T {
        guard let tokens = tokenStore.load() else {
            throw AppSessionError.unauthorized
        }

        do {
            return try await operation(tokens.access)
        } catch AppSessionError.unauthorized {
            let refreshed = try await refreshSession()
            return try await operation(refreshed.access)
        }
    }

    @MainActor
    private func refreshSession() async throws -> AuthTokenPair {
        guard let currentTokens = tokenStore.load() else {
            throw AppSessionError.missingRefreshToken
        }
        let refreshed = try await authAPI.refresh(refreshToken: currentTokens.refresh)
        let newTokens = AuthTokenPair(
            access: refreshed.access,
            refresh: refreshed.refresh ?? currentTokens.refresh
        )
        try tokenStore.save(tokens: newTokens)
        return newTokens
    }

    @MainActor
    private func clearSession(persist: Bool = true) {
        try? tokenStore.clear()
        currentUser = nil
        currentProfile = nil
        isAuthenticated = false
        hasCompletedOnboarding = true
        if persist {
            persistState()
        }
    }

    private func persistState() {
        defaults.set(isAuthenticated, forKey: Self.isAuthenticatedKey)
        defaults.set(hasCompletedOnboarding, forKey: Self.hasCompletedOnboardingKey)
    }

    private func splitDisplayName(_ fullName: String) -> (firstName: String, lastName: String) {
        let parts = fullName
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstName = parts.first else {
            return ("", "")
        }

        return (firstName, parts.dropFirst().joined(separator: " "))
    }

    private func makeCreateHangoutPayload(from draft: CreateHangoutDraft) -> CreateHangoutPayload {
        let startAt = draft.startAt
        let endAt = draft.startAt.addingTimeInterval(Double(max(1, draft.durationHours)) * 3600)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        return CreateHangoutPayload(
            languages: draft.languages.compactMap(languageCode(for:)),
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
            cityPlaceId: draft.cityPlaceID.trimmingCharacters(in: .whitespacesAndNewlines),
            cityName: draft.cityName.trimmingCharacters(in: .whitespacesAndNewlines),
            locationName: draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            locationAddress: draft.locationAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            lat: draft.latitude,
            lng: draft.longitude,
            startAt: draft.sourceType == .event ? nil : iso.string(from: startAt),
            endAt: draft.sourceType == .event ? nil : iso.string(from: endAt),
            capacity: draft.isCapacityUnlimited ? nil : draft.capacity,
            isCapacityUnlimited: draft.isCapacityUnlimited,
            isTimeFlexible: draft.isTimeFlexible,
            visibility: draft.visibility == .inviteOnly ? "invite_only" : "public",
            allowWaitlist: true,
            vibe: backendVibe(for: draft.vibe),
            isMicro: draft.isMicro,
            isLive: draft.isLive,
            genderPreference: backendGenderPreference(for: draft.genderPreference),
            audienceTags: draft.audienceTags,
            sourceEventId: draft.sourceType == .event ? draft.sourceEventID : nil
        )
    }

    private func languageCode(for label: String) -> String? {
        switch label.lowercased() {
        case "english": return "en"
        case "spanish": return "es"
        case "german": return "de"
        case "french": return "fr"
        case "italian": return "it"
        default: return nil
        }
    }

    private func backendVibe(for vibe: HangoutVibe) -> String {
        switch vibe {
        case .chill: return "chill"
        case .drinks: return "drinks"
        case .deepTalk: return "deep talks"
        case .activity: return "creative"
        case .foodie: return "food"
        case .sporty: return "sporty"
        }
    }

    private func backendGenderPreference(for value: HangoutGenderPreference) -> String {
        switch value {
        case .any: return "any"
        case .womenOnly: return "women_only"
        case .menOnly: return "men_only"
        }
    }
}

private final class AuthTokenStore {
    private let service = "com.friendzone.auth"
    private let account = "primary"

    func save(tokens: AuthTokenPair) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(tokens)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData] = data
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AppSessionError.invalidResponse
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw AppSessionError.invalidResponse
        }
    }

    func load() -> AuthTokenPair? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let tokens = try? JSONDecoder().decode(AuthTokenPair.self, from: data) else {
            return nil
        }
        return tokens
    }

    func clear() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppSessionError.invalidResponse
        }
    }
}

private final class AuthAPIService {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30

        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func login(username: String, password: String) async throws -> AuthSessionPayload {
        let body = try encoder.encode(["username": username, "password": password])
        let data = try await request(path: "/api/auth/login/", method: "POST", body: body)
        return try decode(AuthSessionPayload.self, from: data)
    }

    func register(username: String, email: String, password: String, passwordConfirmation: String) async throws -> AuthSessionPayload {
        let body = try encoder.encode([
            "username": username,
            "email": email,
            "password1": password,
            "password2": passwordConfirmation
        ])
        let data = try await request(path: "/api/auth/registration/", method: "POST", body: body)
        return try decode(AuthSessionPayload.self, from: data)
    }

    func requestPasswordReset(email: String) async throws {
        let body = try encoder.encode(["email": email])
        _ = try await request(path: "/api/auth/password/reset/", method: "POST", body: body)
    }

    func loginWithApple(authorizationCode: String, identityToken: String?) async throws -> AuthSessionPayload {
        let body = try encoder.encode(
            AppleLoginRequest(code: authorizationCode, idToken: identityToken)
        )
        let data = try await request(path: "/api/auth/apple/", method: "POST", body: body)
        return try decode(AuthSessionPayload.self, from: data)
    }

    func loginWithGoogle(authorizationCode: String, redirectURI: String) async throws -> AuthSessionPayload {
        let body = try encoder.encode(
            GoogleLoginRequest(code: authorizationCode, redirectUri: redirectURI)
        )
        let data = try await request(path: "/api/auth/google/", method: "POST", body: body)
        return try decode(AuthSessionPayload.self, from: data)
    }

    func fetchCurrentUser(accessToken: String) async throws -> AuthenticatedUser {
        let data = try await request(path: "/api/auth/user/", method: "GET", accessToken: accessToken)
        return try decode(AuthenticatedUser.self, from: data)
    }

    func updateCurrentUser(payload: UserPatchRequest, accessToken: String) async throws -> AuthenticatedUser {
        let body = try encoder.encode(payload)
        let data = try await request(path: "/api/auth/me/", method: "PATCH", body: body, accessToken: accessToken)
        return try decode(AuthenticatedUser.self, from: data)
    }

    func refresh(refreshToken: String) async throws -> TokenRefreshPayload {
        let body = try encoder.encode(["refresh": refreshToken])
        let data = try await request(path: "/api/auth/token/refresh/", method: "POST", body: body)
        return try decode(TokenRefreshPayload.self, from: data)
    }

    func logout(accessToken: String?, refreshToken: String) async throws {
        let body = try encoder.encode(["refresh": refreshToken])
        _ = try await request(path: "/api/auth/logout/", method: "POST", body: body, accessToken: accessToken)
    }

    func pingBackend() async -> Bool {
        var request = URLRequest(url: AppConfig.url(for: "/api/auth/user/"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200 ..< 500).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    private func request(path: String, method: String, body: Data? = nil, accessToken: String? = nil) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppSessionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return data
        case 401:
            throw AppSessionError.unauthorized
        default:
            let message = decodeServerMessage(data: data) ?? "Unexpected error"
            throw AppSessionError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppSessionError.decodingFailed
        }
    }

    private func decodeServerMessage(data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let detail = object["detail"] as? String, !detail.isEmpty {
            return detail
        }
        if let message = object["message"] as? String, !message.isEmpty {
            return message
        }
        if let error = object["error"] as? String, !error.isEmpty {
            return error
        }
        if let emailErrors = object["email"] as? [String], !emailErrors.isEmpty {
            return emailErrors.joined(separator: ", ")
        }
        if let usernameErrors = object["username"] as? [String], !usernameErrors.isEmpty {
            return usernameErrors.joined(separator: ", ")
        }
        if let nonFieldErrors = object["non_field_errors"] as? [String], !nonFieldErrors.isEmpty {
            return nonFieldErrors.joined(separator: ", ")
        }
        return nil
    }
}

private final class ProfileAPIService {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30

        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func fetchMyProfile(accessToken: String) async throws -> SessionProfile {
        let data = try await request(path: "/api/profiles/me/", method: "GET", accessToken: accessToken)
        return try decode(SessionProfile.self, from: data)
    }

    func updateMyProfile(payload: ProfilePatchRequest, accessToken: String) async throws -> SessionProfile {
        let body = try encoder.encode(payload)
        let data = try await request(path: "/api/profiles/me/", method: "PATCH", body: body, accessToken: accessToken)
        return try decode(SessionProfile.self, from: data)
    }

    func completeOnboarding(payload: CompleteOnboardingRequest, accessToken: String) async throws -> SessionProfile {
        let body = try encoder.encode(payload)
        let data = try await request(path: "/api/profiles/me/complete/", method: "POST", body: body, accessToken: accessToken)
        let decoded = try decode(CompleteOnboardingResponse.self, from: data)
        return decoded.profile
    }

    func uploadAvatar(jpegData: Data, accessToken: String) async throws -> SessionProfile {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: AppConfig.url(for: "/api/profiles/me/profile/avatar/"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = multipartBody(jpegData: jpegData, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppSessionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return try decode(SessionProfile.self, from: data)
        case 401:
            throw AppSessionError.unauthorized
        default:
            let message = decodeServerMessage(data: data) ?? "Unexpected error"
            throw AppSessionError.httpStatus(httpResponse.statusCode, message)
        }
    }

    func fetchPublicProfile(userID: Int, accessToken: String) async throws -> PublicUserProfile {
        let data = try await request(path: "/api/profiles/\(userID)/", method: "GET", accessToken: accessToken)
        return try decode(PublicUserProfile.self, from: data)
    }

    func toggleFollow(userID: Int, accessToken: String) async throws -> FollowToggleResponse {
        let data = try await request(path: "/api/profiles/me/follow/\(userID)/", method: "POST", accessToken: accessToken)
        return try decode(FollowToggleResponse.self, from: data)
    }

    private func request(path: String, method: String, body: Data? = nil, accessToken: String) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppSessionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return data
        case 401:
            throw AppSessionError.unauthorized
        default:
            let message = decodeServerMessage(data: data) ?? "Unexpected error"
            throw AppSessionError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppSessionError.decodingFailed
        }
    }

    private func multipartBody(jpegData: Data, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private func decodeServerMessage(data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = object["detail"] as? String, !detail.isEmpty {
            return detail
        }
        if let error = object["error"] as? String, !error.isEmpty {
            return error
        }
        if let details = object["details"] as? [String: Any], !details.isEmpty {
            return details.values.compactMap { $0 as? String }.joined(separator: ", ")
        }
        return nil
    }
}

private final class DiscoverAPIService {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30

        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchUpcomingEvents(accessToken: String) async throws -> [DiscoveryEventFeedItem] {
        let data = try await request(path: "/api/events/upcoming/", accessToken: accessToken)
        return try decode([DiscoveryEventFeedItem].self, from: data)
    }

    func fetchHangouts(accessToken: String) async throws -> [HangoutFeedItem] {
        let data = try await request(path: "/api/hangouts/", accessToken: accessToken)
        return try decode([HangoutFeedItem].self, from: data)
    }

    func fetchHangoutDetail(id: Int, accessToken: String) async throws -> HangoutFeedItem {
        let data = try await request(path: "/api/hangouts/\(id)/", accessToken: accessToken)
        return try decode(HangoutFeedItem.self, from: data)
    }

    func fetchActiveOffers(accessToken: String) async throws -> [DiscoveryOfferFeedItem] {
        let data = try await request(path: "/api/offers/", accessToken: accessToken)
        return try decode([DiscoveryOfferFeedItem].self, from: data)
    }

    func fetchEventDetail(id: Int, accessToken: String) async throws -> EventDetailFeedItem {
        let data = try await request(path: "/api/events/\(id)/", accessToken: accessToken)
        return try decode(EventDetailFeedItem.self, from: data)
    }

    func fetchOfferDetail(id: Int, accessToken: String) async throws -> OfferDetailFeedItem {
        let data = try await request(path: "/api/offers/\(id)/", accessToken: accessToken)
        return try decode(OfferDetailFeedItem.self, from: data)
    }

    func fetchMyCreatorEvents(accessToken: String) async throws -> [CreatorEventFeedItem] {
        let data = try await request(path: "/api/events/mine/", accessToken: accessToken)
        return try decode([CreatorEventFeedItem].self, from: data)
    }

    func fetchMyCreatorVenues(accessToken: String) async throws -> [CreatorVenueFeedItem] {
        let data = try await request(path: "/api/venues/mine/", accessToken: accessToken)
        return try decode([CreatorVenueFeedItem].self, from: data)
    }

    func fetchMyCreatorOffers(accessToken: String) async throws -> [CreatorOfferFeedItem] {
        let data = try await request(path: "/api/offers/mine/", accessToken: accessToken)
        return try decode([CreatorOfferFeedItem].self, from: data)
    }

    func joinEventSolo(id: Int, accessToken: String) async throws -> EventSoloJoinResponse {
        let data = try await request(path: "/api/events/\(id)/join-solo/", method: "POST", accessToken: accessToken)
        return try decode(EventSoloJoinResponse.self, from: data)
    }

    func requestJoinHangout(id: Int, message: String, accessToken: String) async throws -> HangoutJoinRequestFeedItem {
        let body = try JSONEncoder().encode(["message": message])
        let data = try await request(path: "/api/hangouts/\(id)/join/", method: "POST", body: body, accessToken: accessToken)
        return try decode(HangoutJoinRequestFeedItem.self, from: data)
    }

    func leaveHangout(id: Int, accessToken: String) async throws -> EmptyResponse {
        let data = try await request(path: "/api/hangouts/\(id)/leave/", method: "POST", accessToken: accessToken)
        if data.isEmpty { return EmptyResponse() }
        return (try? decode(EmptyResponse.self, from: data)) ?? EmptyResponse()
    }

    func cancelHangout(id: Int, accessToken: String) async throws -> EmptyResponse {
        let data = try await request(path: "/api/hangouts/\(id)/cancel/", method: "POST", accessToken: accessToken)
        if data.isEmpty { return EmptyResponse() }
        return (try? decode(EmptyResponse.self, from: data)) ?? EmptyResponse()
    }

    func approveJoinRequest(hangoutID: Int, requestID: Int, accessToken: String) async throws -> HangoutFeedItem {
        let body = try JSONEncoder().encode(["request_id": requestID])
        let data = try await request(path: "/api/hangouts/\(hangoutID)/approve/", method: "POST", body: body, accessToken: accessToken)
        return try decode(HangoutFeedItem.self, from: data)
    }

    func rejectJoinRequest(hangoutID: Int, requestID: Int, accessToken: String) async throws -> HangoutFeedItem {
        let body = try JSONEncoder().encode(["request_id": requestID])
        let data = try await request(path: "/api/hangouts/\(hangoutID)/reject/", method: "POST", body: body, accessToken: accessToken)
        return try decode(HangoutFeedItem.self, from: data)
    }

    func fetchHangoutMessages(hangoutID: Int, accessToken: String) async throws -> [HangoutMessageFeedItem] {
        let data = try await request(path: "/api/hangouts/\(hangoutID)/messages/", accessToken: accessToken)
        return try decode([HangoutMessageFeedItem].self, from: data)
    }

    func sendHangoutMessage(hangoutID: Int, message: String, accessToken: String) async throws -> HangoutMessageFeedItem {
        let payload = HangoutMessageCreateRequest(message: message)
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/hangouts/\(hangoutID)/messages/", method: "POST", body: body, accessToken: accessToken)
        return try decode(HangoutMessageFeedItem.self, from: data)
    }

    func createHangout(payload: CreateHangoutPayload, coverJPEGData: Data?, accessToken: String) async throws -> CreateHangoutResponse {
        if let coverJPEGData {
            let boundary = "Boundary-\(UUID().uuidString)"
            var request = URLRequest(url: AppConfig.url(for: "/api/hangouts/"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = multipartHangoutBody(payload: payload, jpegData: coverJPEGData, boundary: boundary)

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppSessionError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200 ..< 300:
                return try decode(CreateHangoutResponse.self, from: data)
            case 401:
                throw AppSessionError.unauthorized
            default:
                let message = decodeServerMessage(data: data) ?? "Unexpected error"
                throw AppSessionError.httpStatus(httpResponse.statusCode, message)
            }
        }

        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/hangouts/", method: "POST", body: body, accessToken: accessToken)
        return try decode(CreateHangoutResponse.self, from: data)
    }

    private func request(path: String, method: String = "GET", body: Data? = nil, accessToken: String) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppSessionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return data
        case 401:
            throw AppSessionError.unauthorized
        default:
            throw AppSessionError.httpStatus(httpResponse.statusCode, "Failed to fetch discovery data.")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppSessionError.decodingFailed
        }
    }

    private func multipartHangoutBody(payload: CreateHangoutPayload, jpegData: Data, boundary: String) -> Data {
        var body = Data()

        if
            let encoded = try? JSONEncoder().encode(payload),
            let object = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        {
            for (key, value) in object {
                switch value {
                case let value as String:
                    appendMultipartField(name: key, value: value, to: &body, boundary: boundary)
                case let value as Bool:
                    appendMultipartField(name: key, value: value ? "true" : "false", to: &body, boundary: boundary)
                case let value as Int:
                    appendMultipartField(name: key, value: String(value), to: &body, boundary: boundary)
                case let value as Double:
                    appendMultipartField(name: key, value: String(value), to: &body, boundary: boundary)
                case let values as [String]:
                    for value in values {
                        appendMultipartField(name: key, value: value, to: &body, boundary: boundary)
                    }
                default:
                    break
                }
            }
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"cover_image\"; filename=\"cover.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private func appendMultipartField(name: String, value: String, to body: inout Data, boundary: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func decodeServerMessage(data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = object["detail"] as? String, !detail.isEmpty {
            return detail
        }
        if let error = object["error"] as? String, !error.isEmpty {
            return error
        }
        if let nonFieldErrors = object["non_field_errors"] as? [String], !nonFieldErrors.isEmpty {
            return nonFieldErrors.joined(separator: ", ")
        }
        if let firstArray = object.values.first(where: { $0 is [String] }) as? [String], !firstArray.isEmpty {
            return firstArray.joined(separator: ", ")
        }
        return nil
    }
}

private final class NotificationsAPIService {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30

        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchNotifications(unreadOnly: Bool, accessToken: String) async throws -> [AppNotificationFeedItem] {
        let suffix = unreadOnly ? "?unread_only=true" : ""
        let data = try await request(path: "/api/notifications/\(suffix)", accessToken: accessToken)
        return try decode([AppNotificationFeedItem].self, from: data)
    }

    func markNotificationRead(id: Int, accessToken: String) async throws -> AppNotificationFeedItem {
        let data = try await request(path: "/api/notifications/\(id)/mark_read/", method: "POST", accessToken: accessToken)
        return try decode(AppNotificationFeedItem.self, from: data)
    }

    func markAllNotificationsRead(ids: [Int]?, accessToken: String) async throws -> NotificationMarkAllReadResponse {
        let body: Data?
        if let ids, !ids.isEmpty {
            body = try JSONEncoder().encode(["notification_ids": ids])
        } else {
            body = try JSONEncoder().encode([String: [Int]]())
        }
        let data = try await request(path: "/api/notifications/mark_all_read/", method: "POST", body: body, accessToken: accessToken)
        return try decode(NotificationMarkAllReadResponse.self, from: data)
    }

    func fetchUnreadCount(accessToken: String) async throws -> NotificationUnreadCountResponse {
        let data = try await request(path: "/api/notifications/unread_count/", accessToken: accessToken)
        return try decode(NotificationUnreadCountResponse.self, from: data)
    }

    func deleteNotification(id: Int, accessToken: String) async throws -> EmptyResponse {
        let data = try await request(path: "/api/notifications/\(id)/", method: "DELETE", accessToken: accessToken)
        if data.isEmpty { return EmptyResponse() }
        return (try? decode(EmptyResponse.self, from: data)) ?? EmptyResponse()
    }

    func fetchPreferences(accessToken: String) async throws -> NotificationPreferencesFeedItem {
        let data = try await request(path: "/api/notifications/notification-preferences/", accessToken: accessToken)
        return try decode(NotificationPreferencesFeedItem.self, from: data)
    }

    func updatePreferences(payload: NotificationPreferencesUpdateRequest, accessToken: String) async throws -> NotificationPreferencesFeedItem {
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/notifications/notification-preferences/", method: "PATCH", body: body, accessToken: accessToken)
        return try decode(NotificationPreferencesFeedItem.self, from: data)
    }

    private func request(path: String, method: String = "GET", body: Data? = nil, accessToken: String) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppSessionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return data
        case 401:
            throw AppSessionError.unauthorized
        default:
            let message = decodeServerMessage(data: data) ?? "Unexpected error"
            throw AppSessionError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppSessionError.decodingFailed
        }
    }

    private func decodeServerMessage(data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = object["detail"] as? String, !detail.isEmpty {
            return detail
        }
        if let error = object["error"] as? String, !error.isEmpty {
            return error
        }
        if let message = object["message"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }
}
