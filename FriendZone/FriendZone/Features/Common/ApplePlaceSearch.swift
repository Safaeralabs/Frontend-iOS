import Combine
import Contacts
import CoreLocation
import Foundation
import MapKit

struct ApplePlaceSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

struct AppleResolvedPlace: Equatable {
    let name: String
    let formattedAddress: String
    let cityName: String?
    let countryName: String?
    let countryCode: String?
    let administrativeArea: String?
    let subAdministrativeArea: String?
    let subLocality: String?
    let postalCode: String?
    let timeZoneIdentifier: String?
    let latitude: Double?
    let longitude: Double?
}

@MainActor
final class ApplePlaceSearchModel: NSObject, ObservableObject {
    @Published var query: String = "" {
        didSet { updateQueryFragment() }
    }
    @Published private(set) var suggestions: [ApplePlaceSuggestion] = []
    @Published private(set) var isSearching = false

    private let completer: MKLocalSearchCompleter
    private let geocoder = CLGeocoder()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private var preferredCityKey = ""

    init(resultTypes: MKLocalSearchCompleter.ResultType = [.address, .pointOfInterest]) {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = resultTypes
        super.init()
        completer.delegate = self
    }

    func setPreferredCity(_ cityName: String?) async {
        let normalizedCity = Self.normalized(cityName)
        guard normalizedCity != preferredCityKey else { return }

        preferredCityKey = normalizedCity
        guard !normalizedCity.isEmpty else { return }

        do {
            let placemarks = try await geocoder.geocodeAddressString(cityName ?? "")
            guard let location = placemarks.first?.location else { return }
            completer.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
            )
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.count >= 2 {
                completer.queryFragment = trimmedQuery
            }
        } catch {
            // Keep autocomplete working even if the city bias cannot be resolved.
        }
    }

    func clear() {
        query = ""
        suggestions = []
        completionsByID.removeAll()
        isSearching = false
    }

    func clearSuggestions() {
        suggestions = []
        completionsByID.removeAll()
        isSearching = false
    }

    func resolve(_ suggestion: ApplePlaceSuggestion) async throws -> AppleResolvedPlace {
        guard let completion = completionsByID[suggestion.id] else {
            throw NSError(domain: "ApplePlaceSearch", code: 404, userInfo: [NSLocalizedDescriptionKey: "The selected place is no longer available."])
        }

        let request = MKLocalSearch.Request(completion: completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let mapItem = response.mapItems.first else {
            throw NSError(domain: "ApplePlaceSearch", code: 404, userInfo: [NSLocalizedDescriptionKey: "No map result was found for the selected place."])
        }

        let placemark = mapItem.placemark
        let coordinate = placemark.coordinate
        return AppleResolvedPlace(
            name: mapItem.name ?? suggestion.title,
            formattedAddress: Self.formattedAddress(for: placemark),
            cityName: placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea,
            countryName: placemark.country,
            countryCode: placemark.isoCountryCode,
            administrativeArea: placemark.administrativeArea,
            subAdministrativeArea: placemark.subAdministrativeArea,
            subLocality: placemark.subLocality,
            postalCode: placemark.postalCode,
            timeZoneIdentifier: (mapItem.timeZone ?? placemark.timeZone)?.identifier,
            latitude: coordinate.latitude.isFinite ? coordinate.latitude : nil,
            longitude: coordinate.longitude.isFinite ? coordinate.longitude : nil
        )
    }

    private func updateQueryFragment() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            clearSuggestions()
            return
        }
        isSearching = true
        completer.queryFragment = trimmed
    }

    private static func formattedAddress(for placemark: MKPlacemark) -> String {
        if let postalAddress = placemark.postalAddress {
            return CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let streetLine = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let localityLine = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return [streetLine, localityLine]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func prioritizedResults(from completions: [MKLocalSearchCompletion]) -> [MKLocalSearchCompletion] {
        guard !preferredCityKey.isEmpty else { return completions }

        return completions.sorted { lhs, rhs in
            let lhsScore = score(lhs)
            let rhsScore = score(rhs)
            if lhsScore == rhsScore {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhsScore > rhsScore
        }
    }

    private func score(_ completion: MKLocalSearchCompletion) -> Int {
        let title = Self.normalized(completion.title)
        let subtitle = Self.normalized(completion.subtitle)
        let haystack = "\(title) \(subtitle)"
        if subtitle == preferredCityKey {
            return 4
        }
        if subtitle.contains(preferredCityKey) {
            return 3
        }
        if title.contains(preferredCityKey) {
            return 2
        }
        if haystack.contains(preferredCityKey) {
            return 1
        }
        return 0
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

extension ApplePlaceSearchModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = Array(completer.results)

        Task { @MainActor in
            let currentQuery = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard currentQuery.count >= 2 else {
                self.clearSuggestions()
                return
            }

            let prioritized = Array(self.prioritizedResults(from: results).prefix(6))
            let items = prioritized.enumerated().map { index, completion in
                ApplePlaceSuggestion(
                    id: "\(index)|\(completion.title)|\(completion.subtitle)",
                    title: completion.title,
                    subtitle: completion.subtitle
                )
            }
            let lookup = Dictionary(
                uniqueKeysWithValues: zip(items.map(\.id), prioritized)
            )
            self.completionsByID = lookup
            self.suggestions = items
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.clearSuggestions()
        }
    }
}
