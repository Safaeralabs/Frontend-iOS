import Foundation

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
    case chill
    case drinks
    case deepTalk
    case activity
    case foodie
    case sporty

    var title: String {
        switch self {
        case .chill: return "Chill"
        case .drinks: return "Drinks"
        case .deepTalk: return "Deep Talk"
        case .activity: return "Activity"
        case .foodie: return "Food"
        case .sporty: return "Sporty"
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
}

enum HangoutGenderPreference: String, CaseIterable, Sendable {
    case any
    case womenOnly
    case menOnly

    var title: String {
        switch self {
        case .any: return "Any"
        case .womenOnly: return "Women"
        case .menOnly: return "Men"
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
    var vibe: HangoutVibe = .chill
    var languages: [String] = []
    var locationName: String = ""
    var locationAddress: String = ""
    var cityName: String = ""
    var cityPlaceID: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var startAt: Date = Date().addingTimeInterval(60 * 60)
    var durationHours: Int = 2
    var isTimeFlexible: Bool = false
    var capacity: Int = 6
    var isCapacityUnlimited: Bool = false
    var visibility: HangoutVisibilityOption = .public
    var inviteCode: String = ""
    var genderPreference: HangoutGenderPreference = .any
    var audienceTags: [String] = []
    var isMicro: Bool = false
    var isLive: Bool = false
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
    let vibe: HangoutVibe
    let languages: [String]
    let locationName: String
    let locationAddress: String
    let cityName: String
    let cityPlaceID: String
    let latitude: Double?
    let longitude: Double?
    let startAt: Date
    let durationHours: Int
    let isTimeFlexible: Bool
    let capacity: Int
    let isCapacityUnlimited: Bool
    let visibility: HangoutVisibilityOption
    let inviteCode: String
    let genderPreference: HangoutGenderPreference
    let audienceTags: [String]
    let isMicro: Bool
    let isLive: Bool
    let sourceType: HangoutSourceType
    let sourceLabel: String?
    let sourceEventID: Int?
    let sourceOfferID: Int?
    let coverImageData: Data?
    let coverSeed: Int

    init(
        title: String,
        description: String,
        vibe: HangoutVibe,
        languages: [String],
        locationName: String,
        locationAddress: String,
        cityName: String,
        cityPlaceID: String,
        latitude: Double?,
        longitude: Double?,
        startAt: Date,
        durationHours: Int,
        isTimeFlexible: Bool,
        capacity: Int,
        isCapacityUnlimited: Bool,
        visibility: HangoutVisibilityOption,
        inviteCode: String,
        genderPreference: HangoutGenderPreference,
        audienceTags: [String],
        isMicro: Bool,
        isLive: Bool,
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
        self.durationHours = durationHours
        self.isTimeFlexible = isTimeFlexible
        self.capacity = capacity
        self.isCapacityUnlimited = isCapacityUnlimited
        self.visibility = visibility
        self.inviteCode = inviteCode
        self.genderPreference = genderPreference
        self.audienceTags = audienceTags
        self.isMicro = isMicro
        self.isLive = isLive
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
        durationHours = draft.durationHours
        isTimeFlexible = draft.isTimeFlexible
        capacity = draft.capacity
        isCapacityUnlimited = draft.isCapacityUnlimited
        visibility = draft.visibility
        inviteCode = String(draft.inviteCode)
        genderPreference = draft.genderPreference
        audienceTags = draft.audienceTags.map { String($0) }
        isMicro = draft.isMicro
        isLive = draft.isLive
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
    let hostName: String
    let startAt: Date
    let endAt: Date
    let capacity: Int
    let approvedCount: Int
    let isLive: Bool
    let isMicro: Bool
    let isJoined: Bool
    let participantNames: [String]
    let coverImageData: Data?
    let coverSeed: Int
    let distanceKm: Double
    let priceTier: HangoutPriceTier

    var locationDisplay: String {
        locationName ?? cityName
    }

    var spotsLeft: Int {
        max(0, capacity - approvedCount)
    }

    var isFull: Bool {
        spotsLeft == 0
    }

    var distanceLabel: String {
        if distanceKm < 1 {
            return "\(Int(distanceKm * 1000))m"
        }
        return String(format: "%.1fkm", distanceKm)
    }
}
