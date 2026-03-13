import Foundation

protocol AmbitionsAPIServiceProtocol {
    func listAmbitions(status: String?) async throws -> [Ambition]
    func listMatches(status: String?) async throws -> [AmbitionMatch]
    func listPatterns() async throws -> [RecurringAvailability]
    func createQuickAmbition(_ payload: QuickAmbitionPayload) async throws -> QuickAmbitionCreateResponse
    func acceptMatch(matchID: Int) async throws -> AmbitionMatch
    func declineMatch(matchID: Int) async throws
}

enum AmbitionsAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpStatus(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Session expired. Log in again to load ambitions."
        case let .httpStatus(code, message):
            return "Request failed (\(code)): \(message)"
        case .decodingFailed:
            return "Could not decode server response."
        }
    }
}

final class AmbitionsAPIService: AmbitionsAPIServiceProtocol {
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

        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func listAmbitions(status: String?) async throws -> [Ambition] {
        let query = status.map { [URLQueryItem(name: "status", value: $0)] } ?? []
        return try await requestArray(path: "/api/ambitions/", queryItems: query)
    }

    func listMatches(status: String?) async throws -> [AmbitionMatch] {
        let query = status.map { [URLQueryItem(name: "status", value: $0)] } ?? []
        return try await requestArray(path: "/api/ambitions/matches/", queryItems: query)
    }

    func listPatterns() async throws -> [RecurringAvailability] {
        try await requestArray(path: "/api/ambitions/recurring-availabilities/", queryItems: [])
    }

    func createQuickAmbition(_ payload: QuickAmbitionPayload) async throws -> QuickAmbitionCreateResponse {
        let body = try encoder.encode(payload)
        return try await requestObject(path: "/api/ambitions/quick/", method: "POST", body: body)
    }

    func acceptMatch(matchID: Int) async throws -> AmbitionMatch {
        try await requestObject(path: "/api/ambitions/matches/\(matchID)/accept/", method: "POST")
    }

    func declineMatch(matchID: Int) async throws {
        try await requestVoid(path: "/api/ambitions/matches/\(matchID)/decline/", method: "POST")
    }

    private func requestArray<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> [T] {
        let data = try await request(path: path, method: "GET", queryItems: queryItems)
        return try decodeArrayOrWrapped(data: data)
    }

    private func requestObject<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        let data = try await request(path: path, method: method, queryItems: queryItems, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AmbitionsAPIError.decodingFailed
        }
    }

    private func requestVoid(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws {
        _ = try await request(path: path, method: method, queryItems: queryItems, body: body)
    }

    private func request(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Data? = nil
    ) async throws -> Data {
        var components = URLComponents(url: AppConfig.url(for: path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw AmbitionsAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmbitionsAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return data
        case 401:
            throw AmbitionsAPIError.unauthorized
        default:
            let message = decodeServerMessage(data: data) ?? "Unexpected error"
            throw AmbitionsAPIError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private func decodeArrayOrWrapped<T: Decodable>(data: Data) throws -> [T] {
        if let rawArray = try? decoder.decode([T].self, from: data) {
            return rawArray
        }

        if let wrapped = try? decoder.decode(APIArrayEnvelope<T>.self, from: data) {
            return wrapped.results ?? wrapped.data ?? []
        }

        throw AmbitionsAPIError.decodingFailed
    }

    private func decodeServerMessage(data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let detail = object["detail"] as? String, !detail.isEmpty {
            return detail
        }

        if let message = object["message"] as? String, !message.isEmpty {
            return message
        }

        if let errors = object["errors"] as? [String] {
            return errors.joined(separator: ", ")
        }

        return nil
    }
}

private struct APIArrayEnvelope<T: Decodable>: Decodable {
    let results: [T]?
    let data: [T]?
}

struct QuickAmbitionPayload: Encodable {
    let primaryInterest: String
    let signalType: String
    let vibe: String
    let cityPlaceId: String
    let cityName: String
    let interests: [String]
    let lat: Double?
    let lng: Double?
    let radiusKm: Int
}
