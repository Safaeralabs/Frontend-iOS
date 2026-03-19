import Foundation
import Combine
import Security

enum FriendStatus: String, Codable, Equatable {
    case none
    case outgoingRequest = "outgoing_request"
    case incomingRequest = "incoming_request"
    case friends
    case selfProfile = "self"

    init(rawValueOrNone value: String?) {
        self = FriendStatus(rawValue: value ?? "") ?? .none
    }
}

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
    let linkedProviders: [String]?
    let hasUsablePassword: Bool?

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
        case linkedProviders
        case hasUsablePassword
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
        linkedProviders = try container.decodeIfPresent([String].self, forKey: .linkedProviders)
        hasUsablePassword = try container.decodeIfPresent(Bool.self, forKey: .hasUsablePassword)
    }
}

struct SessionProfileUser: Codable, Equatable {
    let id: Int
    let username: String
    let firstName: String?
    let lastName: String?
}

struct PublicUserProfile: Decodable, Equatable, Identifiable {
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
    let friendsCount: Int?
    let friendStatus: FriendStatus
    let verifiedProfile: Bool?
    let isPremium: Bool?
    let completionScore: Int?
    let instagramUsername: String?
    let linkedinURL: String?

    var id: Int { user.id }

    private enum CodingKeys: String, CodingKey {
        case user
        case avatarURL
        case bio
        case age
        case gender
        case cityName
        case interests
        case vibes
        case hangoutsHosted
        case hostRating
        case reviewsCount
        case followersCount
        case friendsCount
        case friendStatus
        case verifiedProfile
        case isPremium
        case completionScore
        case instagramUsername
        case linkedinURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(NestedUser.self, forKey: .user)
        avatarURL = try container.decodeFlexibleStringIfPresent(forKey: .avatarURL)
        bio = try container.decodeFlexibleStringIfPresent(forKey: .bio)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        gender = try container.decodeFlexibleStringIfPresent(forKey: .gender)
        cityName = try container.decodeFlexibleStringIfPresent(forKey: .cityName)
        interests = try container.decodeFlexibleStringArrayIfPresent(forKey: .interests)
        vibes = try container.decodeFlexibleStringArrayIfPresent(forKey: .vibes)
        hangoutsHosted = try container.decodeIfPresent(Int.self, forKey: .hangoutsHosted)
        hostRating = try container.decodeFlexibleDoubleIfPresent(forKey: .hostRating)
        reviewsCount = try container.decodeIfPresent(Int.self, forKey: .reviewsCount)
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount)
        friendsCount = try container.decodeIfPresent(Int.self, forKey: .friendsCount)
        friendStatus = FriendStatus(rawValueOrNone: try container.decodeFlexibleStringIfPresent(forKey: .friendStatus))
        verifiedProfile = try container.decodeIfPresent(Bool.self, forKey: .verifiedProfile)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium)
        completionScore = try container.decodeIfPresent(Int.self, forKey: .completionScore)
        instagramUsername = try container.decodeFlexibleStringIfPresent(forKey: .instagramUsername)
        linkedinURL = try container.decodeFlexibleStringIfPresent(forKey: .linkedinURL)
    }
}

struct SessionProfile: Decodable, Equatable {
    let user: SessionProfileUser?
    let avatarImageUrl: String?
    let bio: String?
    let birthDate: String?
    let cityName: String?
    let cityPlaceId: String?
    let travelModeEnabled: Bool?
    let travelCityName: String?
    let travelCityPlaceId: String?
    let activeCityName: String?
    let activeCityPlaceId: String?
    let nativeLanguage: String?
    let spokenLanguages: [String]?
    let interests: [String]?
    let vibes: [String]?
    let availabilitySchedule: [String]?
    let preferredGroupSize: String?
    let interestedIn: [String]?
    let gender: String?
    let instagramUsername: String?
    let linkedinURL: String?
    let reviewsCount: Int?
    let followersCount: Int?
    let followingCount: Int?
    let friendsCount: Int?
    let incomingFriendRequestsCount: Int?
    let outgoingFriendRequestsCount: Int?
    let hangoutsAttended: Int?
    let hangoutsHosted: Int?
    let hostRating: Double?
    let completionScore: Int?
    let completionMissingFields: [String]?
    let onboardingCompleted: Bool
    let verifiedProfile: Bool?
    let phoneVerified: Bool?
    let emailVerified: Bool?
    let isEventCreator: Bool?
    let isVenueOwner: Bool?

    private enum CodingKeys: String, CodingKey {
        case user
        case avatarImageUrl
        case avatarUrl
        case bio
        case birthDate
        case cityName
        case cityPlaceId
        case travelModeEnabled
        case travelCityName
        case travelCityPlaceId
        case activeCityName
        case activeCityPlaceId
        case nativeLanguages
        case spokenLanguages
        case interests
        case vibes
        case availabilitySchedule
        case preferredGroupSize
        case interestedIn
        case gender
        case instagramUsername
        case linkedinURL
        case reviewsCount
        case followersCount
        case followingCount
        case friendsCount
        case incomingFriendRequestsCount
        case outgoingFriendRequestsCount
        case hangoutsAttended
        case hangoutsHosted
        case hostRating
        case completionScore
        case completionMissingFields
        case onboardingCompleted
        case verifiedProfile
        case phoneVerified
        case emailVerified
        case isEventCreator
        case isVenueOwner
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decodeIfPresent(SessionProfileUser.self, forKey: .user)
        avatarImageUrl = try container.decodeFlexibleStringIfPresent(forKey: .avatarImageUrl)
            ?? container.decodeFlexibleStringIfPresent(forKey: .avatarUrl)
        bio = try container.decodeFlexibleStringIfPresent(forKey: .bio)
        birthDate = try container.decodeFlexibleStringIfPresent(forKey: .birthDate)
        cityName = try container.decodeFlexibleStringIfPresent(forKey: .cityName)
        cityPlaceId = try container.decodeFlexibleStringIfPresent(forKey: .cityPlaceId)
        travelModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .travelModeEnabled)
        travelCityName = try container.decodeFlexibleStringIfPresent(forKey: .travelCityName)
        travelCityPlaceId = try container.decodeFlexibleStringIfPresent(forKey: .travelCityPlaceId)
        activeCityName = try container.decodeFlexibleStringIfPresent(forKey: .activeCityName)
        activeCityPlaceId = try container.decodeFlexibleStringIfPresent(forKey: .activeCityPlaceId)
        nativeLanguage = try container.decodeFlexibleStringIfPresent(forKey: .nativeLanguages)
        spokenLanguages = try container.decodeFlexibleStringArrayIfPresent(forKey: .spokenLanguages)
        interests = try container.decodeFlexibleStringArrayIfPresent(forKey: .interests)
        vibes = try container.decodeFlexibleStringArrayIfPresent(forKey: .vibes)
        availabilitySchedule = try container.decodeFlexibleAvailabilityArrayIfPresent(forKey: .availabilitySchedule)
        preferredGroupSize = try container.decodeFlexibleStringIfPresent(forKey: .preferredGroupSize)
        interestedIn = try container.decodeFlexibleStringArrayIfPresent(forKey: .interestedIn)
        gender = try container.decodeFlexibleStringIfPresent(forKey: .gender)
        instagramUsername = try container.decodeFlexibleStringIfPresent(forKey: .instagramUsername)
        linkedinURL = try container.decodeFlexibleStringIfPresent(forKey: .linkedinURL)
        reviewsCount = try container.decodeIfPresent(Int.self, forKey: .reviewsCount)
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount)
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount)
        friendsCount = try container.decodeIfPresent(Int.self, forKey: .friendsCount)
        incomingFriendRequestsCount = try container.decodeIfPresent(Int.self, forKey: .incomingFriendRequestsCount)
        outgoingFriendRequestsCount = try container.decodeIfPresent(Int.self, forKey: .outgoingFriendRequestsCount)
        hangoutsAttended = try container.decodeIfPresent(Int.self, forKey: .hangoutsAttended)
        hangoutsHosted = try container.decodeIfPresent(Int.self, forKey: .hangoutsHosted)
        hostRating = try container.decodeFlexibleDoubleIfPresent(forKey: .hostRating)
        completionScore = try container.decodeIfPresent(Int.self, forKey: .completionScore)
        completionMissingFields = try container.decodeFlexibleStringArrayIfPresent(forKey: .completionMissingFields)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        verifiedProfile = try container.decodeIfPresent(Bool.self, forKey: .verifiedProfile)
        phoneVerified = try container.decodeIfPresent(Bool.self, forKey: .phoneVerified)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified)
        isEventCreator = try container.decodeIfPresent(Bool.self, forKey: .isEventCreator)
        isVenueOwner = try container.decodeIfPresent(Bool.self, forKey: .isVenueOwner)
    }
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
    let cityPlaceId: String?
    let bio: String
    let instagramUsername: String
    let birthDate: Date?
    let gender: String?
    let spokenLanguages: [String]
    let interests: [String]

    init(
        displayName: String,
        city: String,
        cityPlaceId: String? = nil,
        bio: String,
        instagramUsername: String,
        birthDate: Date? = nil,
        gender: String? = nil,
        spokenLanguages: [String] = [],
        interests: [String] = []
    ) {
        self.displayName = displayName
        self.city = city
        self.cityPlaceId = cityPlaceId
        self.bio = bio
        self.instagramUsername = instagramUsername
        self.birthDate = birthDate
        self.gender = gender
        self.spokenLanguages = spokenLanguages
        self.interests = interests
    }
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
    let endAt: String?
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

struct LocationGuessResponse: Decodable, Equatable {
    let country: String?
    let cityName: String
    let cityPlaceId: String
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
    let locationAddress: String?
    let lat: Double?
    let lng: Double?
    let startAt: String
    let endAt: String
    let capacity: Int
    let isCapacityUnlimited: Bool?
    let isTimeFlexible: Bool?
    let approvedParticipantsCount: Int?
    let status: String
    let sourceType: String
    let sourceEventId: Int?
    let sourceOfferId: Int?
    let vibe: String
    let languages: [String]
    let visibility: String?
    let inviteCode: String?
    let inviteCodeHint: String?
    let allowWaitlist: Bool?
    let genderPreference: String?
    let audienceTags: [String]
    let participants: [HangoutParticipantFeedItem]
    let joinRequests: [HangoutJoinRequestFeedItem]

    private enum CodingKeys: String, CodingKey {
        case id
        case host
        case hostUsername
        case title
        case description
        case coverImageUrl
        case cityName
        case locationName
        case locationAddress
        case lat
        case lng
        case startAt
        case endAt
        case capacity
        case isCapacityUnlimited
        case isTimeFlexible
        case approvedParticipantsCount
        case status
        case sourceType
        case sourceEventId
        case sourceOfferId
        case vibe
        case languages
        case visibility
        case inviteCode
        case inviteCodeHint
        case allowWaitlist
        case genderPreference
        case audienceTags
        case participants
        case joinRequests
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        host = try container.decode(Int.self, forKey: .host)
        hostUsername = try container.decodeIfPresent(String.self, forKey: .hostUsername) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        cityName = try container.decodeIfPresent(String.self, forKey: .cityName) ?? ""
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        locationAddress = try container.decodeIfPresent(String.self, forKey: .locationAddress)
        lat = try container.decodeFlexibleDoubleIfPresent(forKey: .lat)
        lng = try container.decodeFlexibleDoubleIfPresent(forKey: .lng)
        startAt = try container.decode(String.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(String.self, forKey: .endAt) ?? startAt
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity) ?? 0
        isCapacityUnlimited = try container.decodeIfPresent(Bool.self, forKey: .isCapacityUnlimited)
        isTimeFlexible = try container.decodeIfPresent(Bool.self, forKey: .isTimeFlexible)
        approvedParticipantsCount = try container.decodeIfPresent(Int.self, forKey: .approvedParticipantsCount)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? "community"
        sourceEventId = try container.decodeIfPresent(Int.self, forKey: .sourceEventId)
        sourceOfferId = try container.decodeIfPresent(Int.self, forKey: .sourceOfferId)
        vibe = try container.decodeIfPresent(String.self, forKey: .vibe) ?? "chill"
        languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? []
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        inviteCodeHint = try container.decodeIfPresent(String.self, forKey: .inviteCodeHint)
        allowWaitlist = try container.decodeIfPresent(Bool.self, forKey: .allowWaitlist)
        genderPreference = try container.decodeIfPresent(String.self, forKey: .genderPreference)
        audienceTags = try container.decodeIfPresent([String].self, forKey: .audienceTags) ?? []
        participants = try container.decodeIfPresent([HangoutParticipantFeedItem].self, forKey: .participants) ?? []
        joinRequests = try container.decodeIfPresent([HangoutJoinRequestFeedItem].self, forKey: .joinRequests) ?? []
    }
}

struct AppSessionAPIArrayEnvelope<T: Decodable>: Decodable {
    let results: [T]?
    let data: [T]?
}

func decodeAppSessionAPIArrayResponse<T: Decodable>(_ type: T.Type, from data: Data, decoder: JSONDecoder) throws -> [T] {
    if let values = try? decoder.decode([T].self, from: data) {
        return values
    }

    let envelope = try decoder.decode(AppSessionAPIArrayEnvelope<T>.self, from: data)
    if let results = envelope.results {
        return results
    }
    if let values = envelope.data {
        return values
    }
    return []
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        do {
            if let value = try decodeIfPresent(Double.self, forKey: key) {
                return value
            }
        } catch {
            // Fall through to string-based decoding.
        }

        do {
            if let string = try decodeIfPresent(String.self, forKey: key) {
                return Double(string)
            }
        } catch {
            return nil
        }
        return nil
    }

    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        do {
            if let value = try decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        } catch {
            // Fall through to numeric decoding.
        }

        do {
            if let intValue = try decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }
        } catch {
            // Fall through to floating-point decoding.
        }

        do {
            if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            }
        } catch {
            return nil
        }
        return nil
    }

    func decodeFlexibleStringArrayIfPresent(forKey key: Key) throws -> [String]? {
        do {
            if let values = try decodeIfPresent([String].self, forKey: key) {
                let cleaned = values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return cleaned.isEmpty ? nil : cleaned
            }
        } catch {
            // Fall through to single-value decoding.
        }
        if let value = try decodeFlexibleStringIfPresent(forKey: key) {
            return [value]
        }
        return nil
    }

    func decodeFlexibleAvailabilityArrayIfPresent(forKey key: Key) throws -> [String]? {
        if let values = try decodeFlexibleStringArrayIfPresent(forKey: key) {
            return values
        }
        do {
            if let flags = try decodeIfPresent([String: Bool].self, forKey: key) {
                let active = flags
                    .filter(\.value)
                    .map(\.key)
                    .sorted()
                return active.isEmpty ? nil : active
            }
        } catch {
            return nil
        }
        return nil
    }
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

struct EventSoloJoinFeedItem: Decodable, Identifiable, Equatable {
    let id: Int
    let eventId: Int
    let eventTitle: String
    let venueName: String
    let creatorName: String
    let startAt: String
    let endAt: String?
    let joinedAt: String?
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
    let durationHours: Int?
    let capacity: Int?
    let isCapacityUnlimited: Bool
    let isTimeFlexible: Bool
    let visibility: String
    let inviteCode: String?
    let inviteCodeHint: String?
    let allowWaitlist: Bool
    let vibe: String
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
        case durationHours = "duration_hours"
        case capacity
        case isCapacityUnlimited = "is_capacity_unlimited"
        case isTimeFlexible = "is_time_flexible"
        case visibility
        case inviteCode = "invite_code"
        case inviteCodeHint = "invite_code_hint"
        case allowWaitlist = "allow_waitlist"
        case vibe
        case genderPreference = "gender_preference"
        case audienceTags = "audience_tags"
        case sourceEventId = "source_event_id"
    }
}

private struct CreatorEventCreatePayload: Encodable {
    let title: String
    let description: String
    let venueName: String
    let venueAddress: String
    let googlePlaceId: String?
    let city: String
    let cityPlaceId: String
    let lat: Double?
    let lng: Double?
    let startAt: String
    let endAt: String
    let capacity: Int
    let category: String
    let tags: [String]
    let imageURL: String

    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case venueName = "venue_name"
        case venueAddress = "venue_address"
        case googlePlaceId = "google_place_id"
        case city
        case cityPlaceId = "city_place_id"
        case lat
        case lng
        case startAt = "start_at"
        case endAt = "end_at"
        case capacity
        case category
        case tags
        case imageURL = "image_url"
    }
}

private struct CreatorOfferCreatePayload: Encodable {
    let title: String
    let description: String
    let perk: String
    let venue: Int
    let validFrom: String
    let validUntil: String
    let recurrence: String
    let capacity: Int?
    let autoCreateHangout: Bool
    let terms: String

    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case perk
        case venue
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case recurrence
        case capacity
        case autoCreateHangout = "auto_create_hangout"
        case terms
    }
}

private struct CreatorEventUpdatePayload: Encodable {
    let title: String
    let startAt: String
    let endAt: String
    let capacity: Int
    let category: String

    private enum CodingKeys: String, CodingKey {
        case title
        case startAt = "start_at"
        case endAt = "end_at"
        case capacity
        case category
    }
}

private struct CreatorOfferUpdatePayload: Encodable {
    let title: String
    let perk: String
    let validUntil: String
    let recurrence: String
    let capacity: Int?

    private enum CodingKeys: String, CodingKey {
        case title
        case perk
        case validUntil = "valid_until"
        case recurrence
        case capacity
    }
}

private struct CreatorVenueCreatePayload: Encodable {
    let name: String
    let category: String
    let googlePlaceId: String?
    let address: String
    let city: String
    let cityPlaceId: String
    let lat: Double?
    let lng: Double?

    private enum CodingKeys: String, CodingKey {
        case name
        case category
        case googlePlaceId = "google_place_id"
        case address
        case city
        case cityPlaceId = "city_place_id"
        case lat
        case lng
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

struct FriendshipActionResponse: Decodable, Equatable {
    let action: String
    let friendStatus: FriendStatus
    let userId: Int?
    let friendsCount: Int?
    let incomingFriendRequestsCount: Int?
    let outgoingFriendRequestsCount: Int?
    let targetFriendsCount: Int?

    private enum CodingKeys: String, CodingKey {
        case action
        case friendStatus
        case userId
        case friendsCount
        case incomingFriendRequestsCount
        case outgoingFriendRequestsCount
        case targetFriendsCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(String.self, forKey: .action)
        friendStatus = FriendStatus(rawValueOrNone: try container.decodeFlexibleStringIfPresent(forKey: .friendStatus))
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        friendsCount = try container.decodeIfPresent(Int.self, forKey: .friendsCount)
        incomingFriendRequestsCount = try container.decodeIfPresent(Int.self, forKey: .incomingFriendRequestsCount)
        outgoingFriendRequestsCount = try container.decodeIfPresent(Int.self, forKey: .outgoingFriendRequestsCount)
        targetFriendsCount = try container.decodeIfPresent(Int.self, forKey: .targetFriendsCount)
    }
}

private struct UserPatchRequest: Encodable {
    let firstName: String
    let lastName: String
}

private struct ProfilePatchRequest: Encodable {
    let cityName: String?
    let cityPlaceId: String?
    let bio: String?
    let instagramUsername: String?
    let birthDate: String?
    let gender: String?
    let spokenLanguages: [String]?
    let interests: [String]?
    let travelModeEnabled: Bool?
    let travelCityName: String?
    let travelCityPlaceId: String?
}

enum AppSessionError: LocalizedError {
    case invalidResponse
    case unauthorized
    case missingRefreshToken
    case httpStatus(Int, String)
    case decodingFailed
    case invalidInput(String)

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
        case let .invalidInput(message):
            return message
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

    var homeCityName: String? {
        Self.cleanCityValue(currentProfile?.cityName)
    }

    var homeCityPlaceId: String? {
        Self.cleanCityValue(currentProfile?.cityPlaceId)
    }

    var activeCityName: String? {
        Self.cleanCityValue(currentProfile?.activeCityName)
            ?? Self.cleanCityValue(currentProfile?.cityName)
    }

    var activeCityPlaceId: String? {
        Self.cleanCityValue(currentProfile?.activeCityPlaceId)
            ?? Self.cleanCityValue(currentProfile?.cityPlaceId)
    }

    var isTravelModeActive: Bool {
        (currentProfile?.travelModeEnabled ?? false) && activeCityPlaceId != homeCityPlaceId
    }

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
        self.hasCompletedOnboarding = defaults.object(forKey: Self.hasCompletedOnboardingKey) as? Bool ?? false
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
        hasCompletedOnboarding = payload.user.onboardingCompleted ?? false
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
        hasCompletedOnboarding = payload.user.onboardingCompleted ?? false
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
        hasCompletedOnboarding = payload.user.onboardingCompleted ?? false
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

    func fetchUpcomingEvents(cityPlaceId: String? = nil) async throws -> [DiscoveryEventFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchUpcomingEvents(cityPlaceId: cityPlaceId, accessToken: accessToken)
        }
    }

    func fetchActiveOffers(cityPlaceId: String? = nil) async throws -> [DiscoveryOfferFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchActiveOffers(cityPlaceId: cityPlaceId, accessToken: accessToken)
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

    func createCreatorEvent(
        title: String,
        description: String,
        venueName: String,
        venueAddress: String,
        googlePlaceId: String? = nil,
        city: String? = nil,
        cityPlaceId: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        startAt: Date,
        endAt: Date,
        capacity: Int,
        category: String
    ) async throws -> CreatorEventFeedItem {
        let profile = currentProfile
        let payload = CreatorEventCreatePayload(
            title: title,
            description: description,
            venueName: venueName,
            venueAddress: venueAddress,
            googlePlaceId: googlePlaceId,
            city: city ?? activeCityName ?? profile?.cityName ?? "",
            cityPlaceId: cityPlaceId ?? activeCityPlaceId ?? profile?.cityPlaceId ?? "",
            lat: lat,
            lng: lng,
            startAt: iso8601String(from: startAt),
            endAt: iso8601String(from: endAt),
            capacity: capacity,
            category: category,
            tags: [],
            imageURL: ""
        )
        return try await authorizedCall { [self] accessToken in
            try await discoverAPI.createCreatorEvent(payload: payload, accessToken: accessToken)
        }
    }

    func createCreatorOffer(
        title: String,
        description: String,
        perk: String,
        venueID: Int,
        validFrom: Date,
        validUntil: Date,
        recurrence: String,
        capacity: Int?,
        autoCreateHangout: Bool,
        terms: String
    ) async throws -> CreatorOfferFeedItem {
        let payload = CreatorOfferCreatePayload(
            title: title,
            description: description,
            perk: perk,
            venue: venueID,
            validFrom: iso8601String(from: validFrom),
            validUntil: iso8601String(from: validUntil),
            recurrence: recurrence,
            capacity: capacity,
            autoCreateHangout: autoCreateHangout,
            terms: terms
        )
        return try await authorizedCall { [self] accessToken in
            try await discoverAPI.createCreatorOffer(payload: payload, accessToken: accessToken)
        }
    }

    func createCreatorVenue(
        name: String,
        category: String,
        address: String,
        city: String,
        googlePlaceId: String? = nil,
        cityPlaceId: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil
    ) async throws -> CreatorVenueFeedItem {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = CreatorVenueCreatePayload(
            name: normalizedName,
            category: category,
            googlePlaceId: googlePlaceId,
            address: normalizedAddress,
            city: normalizedCity,
            cityPlaceId: cityPlaceId ?? activeCityPlaceId ?? currentProfile?.cityPlaceId ?? "",
            lat: lat,
            lng: lng
        )
        return try await authorizedCall { [self] accessToken in
            try await discoverAPI.createCreatorVenue(payload: payload, accessToken: accessToken)
        }
    }

    func guessLocation(lat: Double, lng: Double, cityName: String? = nil, country: String? = nil) async throws -> LocationGuessResponse {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.guessLocation(lat: lat, lng: lng, cityName: cityName, country: country, accessToken: accessToken)
        }
    }

    func updateCreatorEvent(
        id: Int,
        title: String,
        startAt: Date,
        endAt: Date,
        capacity: Int,
        category: String
    ) async throws -> CreatorEventFeedItem {
        let payload = CreatorEventUpdatePayload(
            title: title,
            startAt: iso8601String(from: startAt),
            endAt: iso8601String(from: endAt),
            capacity: capacity,
            category: category
        )
        return try await authorizedCall { [self] accessToken in
            try await discoverAPI.updateCreatorEvent(id: id, payload: payload, accessToken: accessToken)
        }
    }

    func cancelCreatorEvent(id: Int) async throws -> CreatorEventFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.cancelCreatorEvent(id: id, accessToken: accessToken)
        }
    }

    func updateCreatorOffer(
        id: Int,
        title: String,
        perk: String,
        validUntil: Date,
        recurrence: String,
        capacity: Int?
    ) async throws -> CreatorOfferFeedItem {
        let payload = CreatorOfferUpdatePayload(
            title: title,
            perk: perk,
            validUntil: iso8601String(from: validUntil),
            recurrence: recurrence,
            capacity: capacity
        )
        return try await authorizedCall { [self] accessToken in
            try await discoverAPI.updateCreatorOffer(id: id, payload: payload, accessToken: accessToken)
        }
    }

    func pauseCreatorOffer(id: Int) async throws -> CreatorOfferFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.pauseCreatorOffer(id: id, accessToken: accessToken)
        }
    }

    func resumeCreatorOffer(id: Int) async throws -> CreatorOfferFeedItem {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.resumeCreatorOffer(id: id, accessToken: accessToken)
        }
    }

    func joinEventSolo(id: Int) async throws {
        _ = try await authorizedCall { [self] accessToken in
            try await discoverAPI.joinEventSolo(id: id, accessToken: accessToken)
        } as EventSoloJoinResponse
    }

    func fetchMySoloJoins() async throws -> [EventSoloJoinFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchMySoloJoins(accessToken: accessToken)
        }
    }

    func fetchHangouts(cityPlaceId: String? = nil) async throws -> [HangoutFeedItem] {
        try await authorizedCall { [self] accessToken in
            try await discoverAPI.fetchHangouts(cityPlaceId: cityPlaceId, accessToken: accessToken)
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

    func createHangout(from submission: CreateHangoutSubmission) async throws -> CreateHangoutResponse {
        if submission.sourceType == .offer {
            throw AppSessionError.httpStatus(400, "Offer-sourced hangouts are not exposed by the backend create endpoint yet.")
        }

        let payload = makeCreateHangoutPayload(from: submission)
        print("[AppSessionStore] createHangout start title=\(submission.title) source=\(submission.sourceType.rawValue) coverBytes=\(submission.coverImageData?.count ?? 0)")
        return try await authorizedCall { [self] accessToken in
            try await discoverAPI.createHangout(payload: payload, coverJPEGData: submission.coverImageData, accessToken: accessToken)
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
                    cityPlaceId: submission.cityPlaceId ?? currentProfile?.cityPlaceId,
                    bio: submission.bio,
                    instagramUsername: submission.instagramUsername.trimmingCharacters(in: CharacterSet(charactersIn: "@")),
                    birthDate: submission.birthDate.map(dateOnlyString(from:)),
                    gender: submission.gender?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? submission.gender : nil,
                    spokenLanguages: submission.spokenLanguages,
                    interests: submission.interests,
                    travelModeEnabled: nil,
                    travelCityName: nil,
                    travelCityPlaceId: nil
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
    func updateTravelMode(enabled: Bool, cityName: String? = nil, cityPlaceId: String? = nil) async throws {
        let normalizedCityName = cityName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCityPlaceId = cityPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines)

        if enabled && ((normalizedCityName ?? "").isEmpty || (normalizedCityPlaceId ?? "").isEmpty) {
            throw AppSessionError.invalidInput("Pick a city before enabling Travel Mode.")
        }

        let updatedProfile = try await authorizedCall { [self] accessToken in
            try await self.profileAPI.updateMyProfile(
                payload: ProfilePatchRequest(
                    cityName: nil,
                    cityPlaceId: nil,
                    bio: nil,
                    instagramUsername: nil,
                    birthDate: nil,
                    gender: nil,
                    spokenLanguages: nil,
                    interests: nil,
                    travelModeEnabled: enabled,
                    travelCityName: enabled ? normalizedCityName : nil,
                    travelCityPlaceId: enabled ? normalizedCityPlaceId : nil
                ),
                accessToken: accessToken
            )
        }

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

    func manageFriendship(userID: Int) async throws -> FriendshipActionResponse {
        try await authorizedCall { [self] accessToken in
            try await self.profileAPI.manageFriendship(userID: userID, accessToken: accessToken)
        }
    }

    func declineFriendRequest(userID: Int) async throws -> FriendshipActionResponse {
        try await authorizedCall { [self] accessToken in
            try await self.profileAPI.declineFriendRequest(userID: userID, accessToken: accessToken)
        }
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
            hasCompletedOnboarding = user.onboardingCompleted ?? false
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
        hasCompletedOnboarding = false
        if persist {
            persistState()
        }
    }

    private func persistState() {
        defaults.set(isAuthenticated, forKey: Self.isAuthenticatedKey)
        defaults.set(hasCompletedOnboarding, forKey: Self.hasCompletedOnboardingKey)
    }

    private static func cleanCityValue(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
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

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func dateOnlyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func makeCreateHangoutPayload(from submission: CreateHangoutSubmission) -> CreateHangoutPayload {
        let startAt = submission.startAt
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        var normalizedLanguages: [String] = []
        var seenLanguageCodes = Set<String>()
        for rawLanguage in submission.languages {
            let normalized = rawLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, seenLanguageCodes.insert(normalized).inserted else {
                continue
            }
            normalizedLanguages.append(normalized)
            if normalizedLanguages.count == 3 {
                break
            }
        }

        return CreateHangoutPayload(
            languages: normalizedLanguages,
            title: String(submission.title).trimmingCharacters(in: .whitespacesAndNewlines),
            description: String(submission.description).trimmingCharacters(in: .whitespacesAndNewlines),
            cityPlaceId: String(submission.cityPlaceID).trimmingCharacters(in: .whitespacesAndNewlines),
            cityName: String(submission.cityName).trimmingCharacters(in: .whitespacesAndNewlines),
            locationName: String(submission.locationName).trimmingCharacters(in: .whitespacesAndNewlines),
            locationAddress: String(submission.locationAddress).trimmingCharacters(in: .whitespacesAndNewlines),
            lat: submission.latitude,
            lng: submission.longitude,
            startAt: submission.sourceType == .event ? nil : iso.string(from: startAt),
            endAt: nil,
            durationHours: submission.sourceType == .event ? nil : submission.durationHours,
            capacity: submission.isCapacityUnlimited ? nil : submission.capacity,
            isCapacityUnlimited: submission.isCapacityUnlimited,
            isTimeFlexible: submission.isTimeFlexible,
            visibility: submission.visibility == .inviteOnly ? "invite_only" : "public",
            inviteCode: normalizedOptionalString(submission.inviteCode),
            inviteCodeHint: normalizedOptionalString(submission.inviteCodeHint),
            allowWaitlist: submission.visibility == .inviteOnly ? false : submission.allowWaitlist,
            vibe: submission.vibe.rawValue,
            genderPreference: backendGenderPreference(for: submission.genderPreference),
            audienceTags: Array(submission.audienceTags).map { String($0) },
            sourceEventId: submission.sourceType == .event ? submission.sourceEventID : nil
        )
    }

    private func normalizedOptionalString(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
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
    static let loginPath = "/api/auth/login/"
    static let registerPath = "/api/auth/register/"
    static let passwordResetPath = "/api/auth/password/reset/"
    static let clientMarker = "ios-auth-v3"

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
        let data = try await request(path: Self.loginPath, method: "POST", body: body)
        return try decode(AuthSessionPayload.self, from: data)
    }

    func register(username: String, email: String, password: String, passwordConfirmation: String) async throws -> AuthSessionPayload {
        let body = try encoder.encode([
            "username": username,
            "email": email,
            "password1": password,
            "password2": passwordConfirmation
        ])
        let data = try await request(path: Self.registerPath, method: "POST", body: body)
        return try decode(AuthSessionPayload.self, from: data)
    }

    func requestPasswordReset(email: String) async throws {
        let body = try encoder.encode(["email": email])
        _ = try await request(path: Self.passwordResetPath, method: "POST", body: body)
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
        request.setValue(Self.clientMarker, forHTTPHeaderField: "X-FZ-Client")
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

    func manageFriendship(userID: Int, accessToken: String) async throws -> FriendshipActionResponse {
        let data = try await request(path: "/api/profiles/me/friends/\(userID)/", method: "POST", accessToken: accessToken)
        return try decode(FriendshipActionResponse.self, from: data)
    }

    func declineFriendRequest(userID: Int, accessToken: String) async throws -> FriendshipActionResponse {
        let data = try await request(path: "/api/profiles/me/friends/\(userID)/decline/", method: "POST", accessToken: accessToken)
        return try decode(FriendshipActionResponse.self, from: data)
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

    func fetchUpcomingEvents(cityPlaceId: String? = nil, accessToken: String) async throws -> [DiscoveryEventFeedItem] {
        let normalizedCityPlaceId = cityPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedCityPlaceId.isEmpty {
            var components = URLComponents(url: AppConfig.url(for: "/api/events/upcoming/"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "city_place_id", value: normalizedCityPlaceId)]
            guard let url = components?.url else {
                throw AppSessionError.invalidResponse
            }
            let data = try await request(url: url, accessToken: accessToken)
            return try decodeCollectionResponse(DiscoveryEventFeedItem.self, from: data)
        }

        let data = try await request(path: "/api/events/upcoming/", accessToken: accessToken)
        return try decodeCollectionResponse(DiscoveryEventFeedItem.self, from: data)
    }

    func fetchHangouts(cityPlaceId: String? = nil, accessToken: String) async throws -> [HangoutFeedItem] {
        let normalizedCityPlaceId = cityPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !normalizedCityPlaceId.isEmpty {
            var components = URLComponents(url: AppConfig.url(for: "/api/hangouts/"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "city_place_id", value: normalizedCityPlaceId)]
            guard let url = components?.url else {
                throw AppSessionError.invalidResponse
            }
            let data = try await request(url: url, accessToken: accessToken)
            return try decodeHangoutList(from: data)
        }

        let data = try await request(path: "/api/hangouts/", accessToken: accessToken)
        return try decodeHangoutList(from: data)
    }

    func fetchHangoutDetail(id: Int, accessToken: String) async throws -> HangoutFeedItem {
        let data = try await request(path: "/api/hangouts/\(id)/", accessToken: accessToken)
        return try decode(HangoutFeedItem.self, from: data)
    }

    func fetchActiveOffers(cityPlaceId: String? = nil, accessToken: String) async throws -> [DiscoveryOfferFeedItem] {
        let normalizedCityPlaceId = cityPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedCityPlaceId.isEmpty {
            var components = URLComponents(url: AppConfig.url(for: "/api/offers/"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "city_place_id", value: normalizedCityPlaceId)]
            guard let url = components?.url else {
                throw AppSessionError.invalidResponse
            }
            let data = try await request(url: url, accessToken: accessToken)
            return try decodeCollectionResponse(DiscoveryOfferFeedItem.self, from: data)
        }

        let data = try await request(path: "/api/offers/", accessToken: accessToken)
        return try decodeCollectionResponse(DiscoveryOfferFeedItem.self, from: data)
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
        return try decodeCollectionResponse(CreatorEventFeedItem.self, from: data)
    }

    func fetchMyCreatorVenues(accessToken: String) async throws -> [CreatorVenueFeedItem] {
        let data = try await request(path: "/api/venues/mine/", accessToken: accessToken)
        return try decodeCollectionResponse(CreatorVenueFeedItem.self, from: data)
    }

    func fetchMyCreatorOffers(accessToken: String) async throws -> [CreatorOfferFeedItem] {
        let data = try await request(path: "/api/offers/mine/", accessToken: accessToken)
        return try decodeCollectionResponse(CreatorOfferFeedItem.self, from: data)
    }

    func guessLocation(lat: Double, lng: Double, cityName: String? = nil, country: String? = nil, accessToken: String) async throws -> LocationGuessResponse {
        var components = URLComponents(url: AppConfig.url(for: "/api/locations/location/guess/"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng))
        ]
        let normalizedCityName = cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedCityName.isEmpty {
            queryItems.append(URLQueryItem(name: "city_name", value: normalizedCityName))
        }
        let normalizedCountry = country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedCountry.isEmpty {
            queryItems.append(URLQueryItem(name: "country", value: normalizedCountry))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw AppSessionError.invalidResponse
        }
        let data = try await request(url: url, accessToken: accessToken)
        return try decode(LocationGuessResponse.self, from: data)
    }

    func createCreatorEvent(payload: CreatorEventCreatePayload, accessToken: String) async throws -> CreatorEventFeedItem {
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/events/", method: "POST", body: body, accessToken: accessToken)
        return try decode(CreatorEventFeedItem.self, from: data)
    }

    func createCreatorOffer(payload: CreatorOfferCreatePayload, accessToken: String) async throws -> CreatorOfferFeedItem {
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/offers/", method: "POST", body: body, accessToken: accessToken)
        return try decode(CreatorOfferFeedItem.self, from: data)
    }

    func createCreatorVenue(payload: CreatorVenueCreatePayload, accessToken: String) async throws -> CreatorVenueFeedItem {
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/venues/", method: "POST", body: body, accessToken: accessToken)
        return try decode(CreatorVenueFeedItem.self, from: data)
    }

    func updateCreatorEvent(id: Int, payload: CreatorEventUpdatePayload, accessToken: String) async throws -> CreatorEventFeedItem {
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/events/\(id)/", method: "PATCH", body: body, accessToken: accessToken)
        return try decode(CreatorEventFeedItem.self, from: data)
    }

    func cancelCreatorEvent(id: Int, accessToken: String) async throws -> CreatorEventFeedItem {
        let data = try await request(path: "/api/events/\(id)/cancel/", method: "POST", accessToken: accessToken)
        return try decode(CreatorEventFeedItem.self, from: data)
    }

    func updateCreatorOffer(id: Int, payload: CreatorOfferUpdatePayload, accessToken: String) async throws -> CreatorOfferFeedItem {
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/offers/\(id)/", method: "PATCH", body: body, accessToken: accessToken)
        return try decode(CreatorOfferFeedItem.self, from: data)
    }

    func pauseCreatorOffer(id: Int, accessToken: String) async throws -> CreatorOfferFeedItem {
        let data = try await request(path: "/api/offers/\(id)/pause/", method: "POST", accessToken: accessToken)
        return try decode(CreatorOfferFeedItem.self, from: data)
    }

    func resumeCreatorOffer(id: Int, accessToken: String) async throws -> CreatorOfferFeedItem {
        let data = try await request(path: "/api/offers/\(id)/resume/", method: "POST", accessToken: accessToken)
        return try decode(CreatorOfferFeedItem.self, from: data)
    }

    func joinEventSolo(id: Int, accessToken: String) async throws -> EventSoloJoinResponse {
        let data = try await request(path: "/api/events/\(id)/join-solo/", method: "POST", accessToken: accessToken)
        return try decode(EventSoloJoinResponse.self, from: data)
    }

    func fetchMySoloJoins(accessToken: String) async throws -> [EventSoloJoinFeedItem] {
        let data = try await request(path: "/api/events/solo-joins/me/", accessToken: accessToken)
        return try decodeCollectionResponse(EventSoloJoinFeedItem.self, from: data)
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
        return try decodeCollectionResponse(HangoutMessageFeedItem.self, from: data)
    }

    func sendHangoutMessage(hangoutID: Int, message: String, accessToken: String) async throws -> HangoutMessageFeedItem {
        let payload = HangoutMessageCreateRequest(message: message)
        let body = try JSONEncoder().encode(payload)
        let data = try await request(path: "/api/hangouts/\(hangoutID)/messages/", method: "POST", body: body, accessToken: accessToken)
        return try decode(HangoutMessageFeedItem.self, from: data)
    }

    func createHangout(payload: CreateHangoutPayload, coverJPEGData: Data?, accessToken: String) async throws -> CreateHangoutResponse {
        if let coverJPEGData {
            print("[DiscoverAPI] createHangout multipart start coverBytes=\(coverJPEGData.count)")
            let boundary = "Boundary-\(UUID().uuidString)"
            let multipartFileURL = try Self.writeMultipartHangoutFile(payload: payload, jpegData: coverJPEGData, boundary: boundary)
            defer { try? FileManager.default.removeItem(at: multipartFileURL) }
            let multipartSize = (try? FileManager.default.attributesOfItem(atPath: multipartFileURL.path)[.size] as? NSNumber)?.intValue ?? 0
            print("[DiscoverAPI] multipart file ready bytes=\(multipartSize)")
            var request = URLRequest(url: AppConfig.url(for: "/api/hangouts/"))
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.upload(for: request, fromFile: multipartFileURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppSessionError.invalidResponse
            }
            print("[DiscoverAPI] createHangout multipart response status=\(httpResponse.statusCode) bytes=\(data.count)")

            switch httpResponse.statusCode {
            case 200 ..< 300:
                return try decodeCreateHangoutResponse(from: data)
            case 401:
                throw AppSessionError.unauthorized
            default:
                let message = decodeServerMessage(data: data) ?? "Unexpected error"
                throw AppSessionError.httpStatus(httpResponse.statusCode, message)
            }
        }

        let body = try JSONEncoder().encode(payload)
        print("[DiscoverAPI] createHangout json start bytes=\(body.count)")
        let data = try await request(path: "/api/hangouts/", method: "POST", body: body, accessToken: accessToken)
        print("[DiscoverAPI] createHangout json success bytes=\(data.count)")
        return try decodeCreateHangoutResponse(from: data)
    }

    private func request(path: String, method: String = "GET", body: Data? = nil, accessToken: String) async throws -> Data {
        try await request(url: AppConfig.url(for: path), method: method, body: body, accessToken: accessToken)
    }

    private func request(url: URL, method: String = "GET", body: Data? = nil, accessToken: String) async throws -> Data {
        var request = URLRequest(url: url)
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
            let message = decodeServerMessage(data: data) ?? "Failed to fetch discovery data."
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

    private func decodeHangoutList(from data: Data) throws -> [HangoutFeedItem] {
        do {
            return try decodeCollectionResponse(HangoutFeedItem.self, from: data)
        } catch {
            throw AppSessionError.decodingFailed
        }
    }

    private func decodeCollectionResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> [T] {
        try decodeAppSessionAPIArrayResponse(T.self, from: data, decoder: decoder)
    }

    private func decodeCreateHangoutResponse(from data: Data) throws -> CreateHangoutResponse {
        if let response = try? decoder.decode(CreateHangoutResponse.self, from: data) {
            return response
        }

        if let hangout = try? decoder.decode(HangoutFeedItem.self, from: data) {
            return CreateHangoutResponse(
                id: hangout.id,
                sourceType: hangout.sourceType,
                title: hangout.title,
                description: hangout.description,
                cityName: hangout.cityName,
                locationName: hangout.locationName,
                startAt: hangout.startAt,
                endAt: hangout.endAt,
                capacity: hangout.capacity,
                approvedParticipantsCount: hangout.approvedParticipantsCount,
                hostUsername: hangout.hostUsername
            )
        }

        let message = decodeServerMessage(data: data) ?? "Unexpected create hangout response."
        throw AppSessionError.httpStatus(200, message)
    }

    private static func writeMultipartHangoutFile(payload: CreateHangoutPayload, jpegData: Data, boundary: String) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("hangout-\(UUID().uuidString).multipart")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)
        do {
            try writeMultipartPayload(payload: payload, to: handle, boundary: boundary)
            try writeMultipartFileField(name: "cover_image", filename: "cover.jpg", mimeType: "image/jpeg", data: jpegData, to: handle, boundary: boundary)
            try write("--\(boundary)--\r\n", to: handle)
            try handle.close()
            return fileURL
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
    }

    private static func writeMultipartPayload(payload: CreateHangoutPayload, to handle: FileHandle, boundary: String) throws {
        if
            let encoded = try? JSONEncoder().encode(payload),
            let object = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        {
            for (key, value) in object {
                switch value {
                case let value as String:
                    try writeMultipartField(name: key, value: value, to: handle, boundary: boundary)
                case let value as Bool:
                    try writeMultipartField(name: key, value: value ? "true" : "false", to: handle, boundary: boundary)
                case let value as Int:
                    try writeMultipartField(name: key, value: String(value), to: handle, boundary: boundary)
                case let value as Double:
                    try writeMultipartField(name: key, value: String(value), to: handle, boundary: boundary)
                case let values as [String]:
                    for value in values {
                        try writeMultipartField(name: key, value: value, to: handle, boundary: boundary)
                    }
                default:
                    break
                }
            }
        }
    }

    private static func writeMultipartField(name: String, value: String, to handle: FileHandle, boundary: String) throws {
        try write("--\(boundary)\r\n", to: handle)
        try write("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n", to: handle)
        try write("\(value)\r\n", to: handle)
    }

    private static func writeMultipartFileField(name: String, filename: String, mimeType: String, data: Data, to handle: FileHandle, boundary: String) throws {
        try write("--\(boundary)\r\n", to: handle)
        try write("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n", to: handle)
        try write("Content-Type: \(mimeType)\r\n\r\n", to: handle)
        try handle.write(contentsOf: data)
        try write("\r\n", to: handle)
    }

    private static func write(_ string: String, to handle: FileHandle) throws {
        guard let data = string.data(using: .utf8) else { return }
        try handle.write(contentsOf: data)
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
        return try decodeAppSessionAPIArrayResponse(AppNotificationFeedItem.self, from: data, decoder: decoder)
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
