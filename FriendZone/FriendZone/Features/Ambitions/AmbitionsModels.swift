import Foundation

struct Ambition: Decodable, Identifiable {
    let id: Int
    let primaryInterest: String?
    let vibe: String?
    let cityName: String?
    let startAt: String?
    let endAt: String?
    let status: String?
    let createdAt: String?
    let updatedAt: String?
}

struct AmbitionMatchMemberUser: Decodable {
    let id: Int
    let username: String
    let avatarURL: String?
}

struct AmbitionMatchMember: Decodable, Identifiable {
    let id: Int
    let user: AmbitionMatchMemberUser
    let status: String?
    let compatibilityScore: Double?
}

struct AmbitionMatch: Decodable, Identifiable {
    let id: Int
    let primaryInterest: String?
    let matchQualityScore: Double?
    let cityName: String?
    let startAt: String?
    let endAt: String?
    let status: String?
    let userStatus: String?
    let hangout: Int?
    let hangoutParticipantCount: Int?
    let hangoutIsFull: Bool?
    let minSize: Int?
    let maxSize: Int?
    let acceptedCount: Int?
    let suggestedCount: Int?
    let declinedCount: Int?
    let totalMembers: Int?
    let isReadyForHangout: Bool?
    let otherMembers: [AmbitionMatchMember]?
}

struct RecurringAvailability: Decodable, Identifiable {
    let id: Int
    let weekday: Int?
    let startTime: String?
    let endTime: String?
    let timezone: String?
    let vibe: String?
    let interests: [String]?
    let cityName: String?
    let isActive: Bool?
    let lastGeneratedAt: String?
}
