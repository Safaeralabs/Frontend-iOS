import Foundation
import SwiftUI

enum HangoutSourceType: String, CaseIterable, Sendable {
    case hangout
    case offer
    case event

    var badgeTitle: String {
        switch self {
        case .hangout: return "HANGOUT"
        case .offer: return "VENUE OFFER"
        case .event: return "EVENT HANGOUT"
        }
    }
}

enum HangoutVibe: String, CaseIterable, Sendable {
    case chill = "chill"
    case social = "social"
    case party = "party"
    case creative = "creative"
    case outdoors = "outdoors"
    case drinks = "drinks"
    case deepTalk = "deep talks"
    case boardGames = "board games"
    case culture = "culture"
    case sporty = "sporty"
    case foodie = "food"

    var title: String {
        switch self {
        case .chill: return "Chill"
        case .social: return "Social"
        case .party: return "Party"
        case .creative: return "Creative"
        case .outdoors: return "Outdoors"
        case .drinks: return "Drinks"
        case .deepTalk: return "Deep Talks"
        case .boardGames: return "Board Games"
        case .culture: return "Culture"
        case .foodie: return "Food"
        case .sporty: return "Sporty"
        }
    }

    var emoji: String {
        switch self {
        case .chill: return "🛋️"
        case .social: return "🫶"
        case .party: return "🎉"
        case .creative: return "🎨"
        case .outdoors: return "🌿"
        case .drinks: return "🍸"
        case .deepTalk: return "🗣️"
        case .boardGames: return "🎲"
        case .culture: return "🎭"
        case .sporty: return "⚽"
        case .foodie: return "🍝"
        }
    }

    var accentColor: Color {
        switch self {
        case .chill: return Color(hex: "#5B70D6")
        case .social: return Color(hex: "#199C94")
        case .party: return Color(hex: "#D93E8A")
        case .creative: return Color(hex: "#7F63E8")
        case .outdoors: return Color(hex: "#3E9557")
        case .drinks: return Color(hex: "#7D9731")
        case .deepTalk: return Color(hex: "#5057B8")
        case .boardGames: return Color(hex: "#C98217")
        case .culture: return Color(hex: "#A23E61")
        case .sporty: return Color(hex: "#1E7BE8")
        case .foodie: return Color(hex: "#D95F3D")
        }
    }

    init?(backendRawValue: String) {
        let normalized = backendRawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "chill":
            self = .chill
        case "social":
            self = .social
        case "party":
            self = .party
        case "creative":
            self = .creative
        case "outdoors":
            self = .outdoors
        case "drinks":
            self = .drinks
        case "deep talks", "deep_talks", "deeptalks":
            self = .deepTalk
        case "board games", "board_games", "boardgames":
            self = .boardGames
        case "culture":
            self = .culture
        case "sporty":
            self = .sporty
        case "food":
            self = .foodie
        case "activity":
            self = .social
        default:
            return nil
        }
    }
}

enum HangoutsFilterMode: String, CaseIterable, Identifiable {
    case forYou
    case live
    case micro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forYou: return "For You"
        case .live: return "Live"
        case .micro: return "Micro"
        }
    }
}

enum HangoutsTimelineTab: String, CaseIterable, Identifiable {
    case today
    case upcoming
    case joined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .joined: return "Joined"
        }
    }
}

enum HangoutVisibilityOption: String, CaseIterable, Sendable {
    case `public`
    case inviteOnly

    var title: String {
        switch self {
        case .public: return "Public"
        case .inviteOnly: return "Private"
        }
    }

    var detailTitle: String {
        switch self {
        case .public: return "Public"
        case .inviteOnly: return "Private circle"
        }
    }

    init?(backendRawValue: String) {
        switch backendRawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "public":
            self = .public
        case "invite_only", "inviteonly", "private":
            self = .inviteOnly
        default:
            return nil
        }
    }
}

enum HangoutGenderPreference: String, CaseIterable, Sendable {
    case any
    case womenOnly
    case menOnly

    var title: String {
        switch self {
        case .any: return "🌍 Everyone"
        case .womenOnly: return "💅 Gurlz Only"
        case .menOnly: return "🕺 The Boyz Only"
        }
    }

    var detailTitle: String {
        switch self {
        case .any: return "Everyone"
        case .womenOnly: return "Women only"
        case .menOnly: return "Men only"
        }
    }

    init?(backendRawValue: String) {
        switch backendRawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "any":
            self = .any
        case "women_only", "women", "female":
            self = .womenOnly
        case "men_only", "men", "male":
            self = .menOnly
        default:
            return nil
        }
    }
}

enum HangoutCreateVibe: String, CaseIterable, Sendable {
    case chill = "chill"
    case social = "social"
    case party = "party"
    case creative = "creative"
    case outdoors = "outdoors"
    case drinks = "drinks"
    case deepTalks = "deep talks"
    case boardGames = "board games"
    case culture = "culture"
    case sporty = "sporty"
    case food = "food"

    var title: String {
        hangoutVibe.title
    }

    var emoji: String {
        hangoutVibe.emoji
    }

    var accentColor: Color {
        hangoutVibe.accentColor
    }

    var hangoutVibe: HangoutVibe {
        switch self {
        case .chill: return .chill
        case .social: return .social
        case .party: return .party
        case .creative: return .creative
        case .outdoors: return .outdoors
        case .drinks: return .drinks
        case .deepTalks: return .deepTalk
        case .boardGames: return .boardGames
        case .culture: return .culture
        case .sporty: return .sporty
        case .food: return .foodie
        }
    }
}

enum HangoutAudienceTagOption: String, CaseIterable, Sendable {
    case expatsWelcome = "expats_welcome"
    case lgbtqFriendly = "lgbtq_friendly"
    case students
    case professionals
    case noAlcohol = "no_alcohol"
    case dogFriendly = "dog_friendly"
    case youngAdults = "young_adults"
    case thirtyPlus = "thirty_plus"

    var title: String {
        switch self {
        case .expatsWelcome: return "Expats"
        case .lgbtqFriendly: return "LGBTQ+"
        case .students: return "Students"
        case .professionals: return "Professionals"
        case .noAlcohol: return "No Alcohol"
        case .dogFriendly: return "Dog Friendly"
        case .youngAdults: return "18-25"
        case .thirtyPlus: return "30+"
        }
    }

    var emoji: String {
        switch self {
        case .expatsWelcome: return "🌍"
        case .lgbtqFriendly: return "🏳️‍🌈"
        case .students: return "🎓"
        case .professionals: return "💼"
        case .noAlcohol: return "🥤"
        case .dogFriendly: return "🐶"
        case .youngAdults: return "✨"
        case .thirtyPlus: return "🪩"
        }
    }
}

enum HangoutPriceTier: String, CaseIterable, Identifiable {
    case free
    case budget
    case premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "Free"
        case .budget: return "Budget"
        case .premium: return "Premium"
        }
    }

    var shortLabel: String {
        switch self {
        case .free: return "FREE"
        case .budget: return "$$"
        case .premium: return "$$$"
        }
    }
}

enum HangoutJoinStatus: Equatable {
    case none
    case requested
    case joined

    var chipTitle: String {
        switch self {
        case .none: return "OPEN"
        case .requested: return "REQUESTED"
        case .joined: return "JOINED"
        }
    }
}

struct HangoutsAdvancedFilters: Equatable {
    var maxDistanceKm: Double = 10
    var freeOnly: Bool = false
    var openSpotsOnly: Bool = true
    var selectedVibes: Set<HangoutVibe> = []

    static let `default` = HangoutsAdvancedFilters()

    var isDefault: Bool {
        maxDistanceKm == Self.default.maxDistanceKm &&
            freeOnly == Self.default.freeOnly &&
            openSpotsOnly == Self.default.openSpotsOnly &&
            selectedVibes == Self.default.selectedVibes
    }

    var activeCount: Int {
        var count = 0
        if maxDistanceKm < Self.default.maxDistanceKm { count += 1 }
        if freeOnly != Self.default.freeOnly { count += 1 }
        if openSpotsOnly != Self.default.openSpotsOnly { count += 1 }
        if !selectedVibes.isEmpty { count += 1 }
        return count
    }
}

struct CreateHangoutDraft {
    var title: String = ""
    var description: String = ""
    var vibe: HangoutCreateVibe = .chill
    var languages: [String] = []
    var locationName: String = ""
    var locationAddress: String = ""
    var cityName: String = ""
    var cityPlaceID: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var startAt: Date = Date().addingTimeInterval(60 * 60)
    var endAt: Date = Date().addingTimeInterval(60 * 60 * 3)
    var durationHours: Int = 2
    var isTimeFlexible: Bool = false
    var capacity: Int = 6
    var isCapacityUnlimited: Bool = false
    var visibility: HangoutVisibilityOption = .public
    var inviteCode: String = ""
    var inviteCodeHint: String = ""
    var genderPreference: HangoutGenderPreference = .any
    var audienceTags: [String] = []
    var allowWaitlist: Bool = true
    var sourceType: HangoutSourceType = .hangout
    var sourceLabel: String? = nil
    var sourceEventID: Int? = nil
    var sourceOfferID: Int? = nil
    var coverImageData: Data? = nil
    var coverSeed: Int = 0
}

struct CreateHangoutSubmission: Sendable {
    let title: String
    let description: String
    let vibe: HangoutCreateVibe
    let languages: [String]
    let locationName: String
    let locationAddress: String
    let cityName: String
    let cityPlaceID: String
    let latitude: Double?
    let longitude: Double?
    let startAt: Date
    let endAt: Date
    let durationHours: Int
    let isTimeFlexible: Bool
    let capacity: Int
    let isCapacityUnlimited: Bool
    let visibility: HangoutVisibilityOption
    let inviteCode: String
    let inviteCodeHint: String
    let genderPreference: HangoutGenderPreference
    let audienceTags: [String]
    let allowWaitlist: Bool
    let sourceType: HangoutSourceType
    let sourceLabel: String?
    let sourceEventID: Int?
    let sourceOfferID: Int?
    let coverImageData: Data?
    let coverSeed: Int

    init(
        title: String,
        description: String,
        vibe: HangoutCreateVibe,
        languages: [String],
        locationName: String,
        locationAddress: String,
        cityName: String,
        cityPlaceID: String,
        latitude: Double?,
        longitude: Double?,
        startAt: Date,
        endAt: Date,
        durationHours: Int,
        isTimeFlexible: Bool,
        capacity: Int,
        isCapacityUnlimited: Bool,
        visibility: HangoutVisibilityOption,
        inviteCode: String,
        inviteCodeHint: String,
        genderPreference: HangoutGenderPreference,
        audienceTags: [String],
        allowWaitlist: Bool,
        sourceType: HangoutSourceType,
        sourceLabel: String?,
        sourceEventID: Int?,
        sourceOfferID: Int?,
        coverImageData: Data?,
        coverSeed: Int
    ) {
        self.title = title
        self.description = description
        self.vibe = vibe
        self.languages = languages
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.cityName = cityName
        self.cityPlaceID = cityPlaceID
        self.latitude = latitude
        self.longitude = longitude
        self.startAt = startAt
        self.endAt = endAt
        self.durationHours = durationHours
        self.isTimeFlexible = isTimeFlexible
        self.capacity = capacity
        self.isCapacityUnlimited = isCapacityUnlimited
        self.visibility = visibility
        self.inviteCode = inviteCode
        self.inviteCodeHint = inviteCodeHint
        self.genderPreference = genderPreference
        self.audienceTags = audienceTags
        self.allowWaitlist = allowWaitlist
        self.sourceType = sourceType
        self.sourceLabel = sourceLabel
        self.sourceEventID = sourceEventID
        self.sourceOfferID = sourceOfferID
        self.coverImageData = coverImageData
        self.coverSeed = coverSeed
    }

    init(draft: CreateHangoutDraft) {
        title = String(draft.title)
        description = String(draft.description)
        vibe = draft.vibe
        languages = draft.languages.map { String($0) }
        locationName = String(draft.locationName)
        locationAddress = String(draft.locationAddress)
        cityName = String(draft.cityName)
        cityPlaceID = String(draft.cityPlaceID)
        latitude = draft.latitude
        longitude = draft.longitude
        startAt = draft.startAt
        endAt = draft.endAt
        durationHours = draft.durationHours
        isTimeFlexible = draft.isTimeFlexible
        capacity = draft.capacity
        isCapacityUnlimited = draft.isCapacityUnlimited
        visibility = draft.visibility
        inviteCode = String(draft.inviteCode)
        inviteCodeHint = String(draft.inviteCodeHint)
        genderPreference = draft.genderPreference
        audienceTags = draft.audienceTags.map { String($0) }
        allowWaitlist = draft.allowWaitlist
        sourceType = draft.sourceType
        sourceLabel = draft.sourceLabel.map { String($0) }
        sourceEventID = draft.sourceEventID
        sourceOfferID = draft.sourceOfferID
        coverImageData = draft.coverImageData.map { Data($0) }
        coverSeed = draft.coverSeed
    }
}

struct HangoutItem: Identifiable {
    let id: Int
    let sourceType: HangoutSourceType
    let title: String
    let description: String
    let vibe: HangoutVibe
    let cityName: String
    let locationName: String?
    let locationAddress: String?
    let latitude: Double?
    let longitude: Double?
    let hostUserID: Int?
    let hostName: String
    let startAt: Date
    let endAt: Date
    let capacity: Int
    let isCapacityUnlimited: Bool?
    let approvedCount: Int
    let isJoined: Bool
    let participantNames: [String]
    let coverImageData: Data?
    let coverImageURL: String?
    let coverSeed: Int
    let distanceKm: Double
    let priceTier: HangoutPriceTier
    let visibility: HangoutVisibilityOption?
    let inviteCode: String?
    let inviteCodeHint: String?
    let allowWaitlist: Bool?
    let genderPreference: HangoutGenderPreference?
    let audienceTags: [String]
    let languages: [String]
    let isTimeFlexible: Bool?
    let sourceEventID: Int?
    let sourceOfferID: Int?

    init(
        id: Int,
        sourceType: HangoutSourceType,
        title: String,
        description: String,
        vibe: HangoutVibe,
        cityName: String,
        locationName: String?,
        locationAddress: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        hostUserID: Int?,
        hostName: String,
        startAt: Date,
        endAt: Date,
        capacity: Int,
        isCapacityUnlimited: Bool? = nil,
        approvedCount: Int,
        isJoined: Bool,
        participantNames: [String],
        coverImageData: Data?,
        coverImageURL: String? = nil,
        coverSeed: Int,
        distanceKm: Double,
        priceTier: HangoutPriceTier,
        visibility: HangoutVisibilityOption? = nil,
        inviteCode: String? = nil,
        inviteCodeHint: String? = nil,
        allowWaitlist: Bool? = nil,
        genderPreference: HangoutGenderPreference? = nil,
        audienceTags: [String] = [],
        languages: [String] = [],
        isTimeFlexible: Bool? = nil,
        sourceEventID: Int? = nil,
        sourceOfferID: Int? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.title = title
        self.description = description
        self.vibe = vibe
        self.cityName = cityName
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.latitude = latitude
        self.longitude = longitude
        self.hostUserID = hostUserID
        self.hostName = hostName
        self.startAt = startAt
        self.endAt = endAt
        self.capacity = capacity
        self.isCapacityUnlimited = isCapacityUnlimited
        self.approvedCount = approvedCount
        self.isJoined = isJoined
        self.participantNames = participantNames
        self.coverImageData = coverImageData
        self.coverImageURL = coverImageURL
        self.coverSeed = coverSeed
        self.distanceKm = distanceKm
        self.priceTier = priceTier
        self.visibility = visibility
        self.inviteCode = inviteCode
        self.inviteCodeHint = inviteCodeHint
        self.allowWaitlist = allowWaitlist
        self.genderPreference = genderPreference
        self.audienceTags = audienceTags
        self.languages = languages
        self.isTimeFlexible = isTimeFlexible
        self.sourceEventID = sourceEventID
        self.sourceOfferID = sourceOfferID
    }

    var locationDisplay: String {
        locationName ?? cityName
    }

    var hasUnlockedLocation: Bool {
        isJoined
    }

    var publicLocationDisplay: String {
        if hasUnlockedLocation {
            return locationDisplay
        }

        let normalizedCity = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedCity.isEmpty {
            return "Exact spot after you join"
        }
        return "Near \(normalizedCity)"
    }

    var publicLocationHint: String? {
        hasUnlockedLocation ? nil : "Exact spot after you join"
    }

    func isHosted(by userID: Int?) -> Bool {
        guard let userID, let hostUserID else { return false }
        return hostUserID == userID
    }

    var hasUnlimitedCapacity: Bool {
        isCapacityUnlimited == true
    }

    var spotsLeft: Int {
        if hasUnlimitedCapacity {
            return max(capacity, 1)
        }
        return max(0, capacity - approvedCount)
    }

    var isFull: Bool {
        if hasUnlimitedCapacity {
            return false
        }
        return spotsLeft == 0
    }

    var isLive: Bool {
        let now = Date()
        return endAt > now && startAt <= now.addingTimeInterval(3 * 60 * 60)
    }

    var isMicro: Bool {
        (2 ... 3).contains(capacity)
    }

    var distanceLabel: String {
        if distanceKm < 1 {
            return "\(Int(distanceKm * 1000))m"
        }
        return String(format: "%.1fkm", distanceKm)
    }
}
