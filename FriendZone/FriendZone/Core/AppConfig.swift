import Foundation

enum AppConfig {
    private static let defaultBaseURLString = "https://friendzone.app"

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
        if path.hasPrefix("/") {
            return baseURL.appending(path: String(path.dropFirst()))
        }
        return baseURL.appending(path: path)
    }
}
