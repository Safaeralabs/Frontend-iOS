import Foundation

enum RoleType: String, Codable, CaseIterable {
    case eventCreator = "event_creator"
    case venueOwner = "venue_owner"
}

enum RoleRequestStatus: String, Codable {
    case pending
    case approved
    case rejected

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        self = RoleRequestStatus(rawValue: raw) ?? .pending
    }
}

struct RoleRequest: Decodable, Identifiable {
    let id: Int
    let user: Int?
    let userUsername: String?
    let userEmail: String?
    let roleType: RoleType
    let roleTypeDisplay: String?
    let status: RoleRequestStatus
    let statusDisplay: String?
    let organizationName: String?
    let organizationDescription: String?
    let venueName: String?
    let venueGooglePlaceID: String?
    let venueAddress: String?
    let venueCategory: String?
    let rejectionReason: String?
    let reviewedByUsername: String?
    let reviewedAt: String?
    let createdAt: String?
    let updatedAt: String?
}

struct CreateRoleRequestDTO: Encodable {
    let roleType: RoleType
    let organizationName: String?
    let organizationDescription: String?
    let venueName: String?
    let venueGooglePlaceID: String?
    let venueAddress: String?
    let venueCategory: String?
}

struct SettingsUserRoleFlags: Equatable {
    var isEventCreator: Bool
    var isVenueOwner: Bool
    var isStaff: Bool

    var hasCreatorRole: Bool {
        isEventCreator || isVenueOwner
    }

    static let empty = SettingsUserRoleFlags(
        isEventCreator: false,
        isVenueOwner: false,
        isStaff: false
    )
}

protocol RoleRequestsAPIServiceProtocol {
    func list() async throws -> [RoleRequest]
    func create(_ dto: CreateRoleRequestDTO) async throws -> RoleRequest
}

protocol SettingsProfileAPIServiceProtocol {
    func fetchUserRoleFlags() async throws -> SettingsUserRoleFlags
}

enum RoleRequestsAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpStatus(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Session expired. Log in again to continue."
        case let .httpStatus(code, message):
            return "Request failed (\(code)): \(message)"
        case .decodingFailed:
            return "Could not decode server response."
        }
    }
}

final class RoleRequestsAPIService: RoleRequestsAPIServiceProtocol {
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

    func list() async throws -> [RoleRequest] {
        let data = try await request(path: "/api/role-requests/", method: "GET")
        return try decodeArrayOrWrapped(data: data)
    }

    func create(_ dto: CreateRoleRequestDTO) async throws -> RoleRequest {
        let bodyData = try encoder.encode(dto)
        let data = try await request(path: "/api/role-requests/", method: "POST", body: bodyData)
        do {
            return try decoder.decode(RoleRequest.self, from: data)
        } catch {
            throw RoleRequestsAPIError.decodingFailed
        }
    }

    private func request(path: String, method: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoleRequestsAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return data
        case 401:
            throw RoleRequestsAPIError.unauthorized
        default:
            let message = decodeServerMessage(data: data) ?? "Unexpected error"
            throw RoleRequestsAPIError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private func decodeArrayOrWrapped<T: Decodable>(data: Data) throws -> [T] {
        if let rawArray = try? decoder.decode([T].self, from: data) {
            return rawArray
        }

        if let wrapped = try? decoder.decode(APIArrayEnvelope<T>.self, from: data) {
            return wrapped.results ?? wrapped.data ?? []
        }

        throw RoleRequestsAPIError.decodingFailed
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

        if let errors = object["errors"] as? [String], !errors.isEmpty {
            return errors.joined(separator: ", ")
        }

        return nil
    }
}

final class SettingsProfileAPIService: SettingsProfileAPIServiceProtocol {
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

    func fetchUserRoleFlags() async throws -> SettingsUserRoleFlags {
        var request = URLRequest(url: AppConfig.url(for: "/api/profile/"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoleRequestsAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            do {
                let decoded = try decoder.decode(ProfileFlagsResponse.self, from: data)

                return SettingsUserRoleFlags(
                    isEventCreator: decoded.profile?.isEventCreator ?? decoded.isEventCreator ?? false,
                    isVenueOwner: decoded.profile?.isVenueOwner ?? decoded.isVenueOwner ?? false,
                    isStaff: decoded.user?.isStaff ?? decoded.isStaff ?? false
                )
            } catch {
                throw RoleRequestsAPIError.decodingFailed
            }
        case 401:
            throw RoleRequestsAPIError.unauthorized
        default:
            let message = decodeServerMessage(data: data) ?? "Unexpected error"
            throw RoleRequestsAPIError.httpStatus(httpResponse.statusCode, message)
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

        if let errors = object["errors"] as? [String], !errors.isEmpty {
            return errors.joined(separator: ", ")
        }

        return nil
    }
}

private struct APIArrayEnvelope<T: Decodable>: Decodable {
    let results: [T]?
    let data: [T]?
}

private struct ProfileFlagsResponse: Decodable {
    let profile: ProfileFlagsPayload?
    let user: UserFlagsPayload?
    let isEventCreator: Bool?
    let isVenueOwner: Bool?
    let isStaff: Bool?
}

private struct ProfileFlagsPayload: Decodable {
    let isEventCreator: Bool?
    let isVenueOwner: Bool?
}

private struct UserFlagsPayload: Decodable {
    let isStaff: Bool?
}
