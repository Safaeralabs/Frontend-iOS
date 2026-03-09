import Foundation

enum AppConfig {
    private static let defaultBaseURLString = "http://127.0.0.1:8000"

    static var baseURL: URL {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "FRIENDZONE_BASE_URL") as? String
        let candidate = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate, let url = URL(string: candidate), let scheme = url.scheme, scheme.hasPrefix("http") else {
            return URL(string: defaultBaseURLString)!
        }
        return url
    }

    static func url(for path: String) -> URL {
        guard !path.isEmpty else { return baseURL }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let basePath = components.path == "/" ? "" : components.path
        components.path = "\(basePath)\(normalizedPath)"

        return components.url ?? baseURL
    }

    static var googleClientID: String? {
        stringValue(forInfoKey: "GOOGLE_CLIENT_ID")
    }

    static var googleRedirectScheme: String? {
        stringValue(forInfoKey: "GOOGLE_REDIRECT_SCHEME")
    }

    static var googleRedirectURI: String? {
        guard let scheme = googleRedirectScheme, !scheme.isEmpty else { return nil }
        return "\(scheme):/oauth2redirect/google"
    }

    private static func stringValue(forInfoKey key: String) -> String? {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let candidate = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate, !candidate.isEmpty else { return nil }
        return candidate
    }
}
