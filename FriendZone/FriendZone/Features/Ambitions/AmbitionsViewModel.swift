import Foundation
import Combine

@MainActor
final class AmbitionsViewModel: ObservableObject {
    @Published private(set) var ambitions: [Ambition] = []
    @Published private(set) var matches: [AmbitionMatch] = []
    @Published private(set) var patterns: [RecurringAvailability] = []

    @Published private(set) var isLoading = false
    @Published private(set) var activeMatchActions: [Int: AmbitionMatchAction] = [:]
    @Published var pendingOpenHangoutID: Int?
    @Published var errorMessage: String?

    private let service: AmbitionsAPIServiceProtocol
    private var hasLoaded = false

    init(service: AmbitionsAPIServiceProtocol? = nil) {
        self.service = service ?? AmbitionsAPIService()
    }

    var formingMatches: [AmbitionMatch] {
        matches.filter { $0.hangout == nil }
    }

    var hangoutMatches: [AmbitionMatch] {
        let now = Date()
        return matches.filter { match in
            guard match.hangout != nil else { return false }
            if let end = ISODateParser.parse(match.endAt) {
                return end > now
            }
            return true
        }
    }

    var totalActive: Int {
        ambitions.count + formingMatches.count + hangoutMatches.count
    }

    var shouldPollForHangout: Bool {
        matches.contains {
            ($0.userStatus ?? "").lowercased() == "accepted" && $0.hangout == nil
        }
    }

    func count(for section: AmbitionsSection) -> Int {
        switch section {
        case .ambition:
            return ambitions.count
        case .matches:
            return formingMatches.count
        case .hangouts:
            return hangoutMatches.count
        case .weekly:
            return patterns.count
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let ambitionsTask = service.listAmbitions(status: "active")
            async let formingTask = service.listMatches(status: "forming")
            async let convertedTask = service.listMatches(status: "converted")
            async let patternsTask = service.listPatterns()

            let activeAmbitions = try await ambitionsTask
            let formingMatches = try await formingTask
            let convertedMatches = try await convertedTask
            let recurringPatterns = try await patternsTask

            let now = Date()
            ambitions = activeAmbitions.filter { ambition in
                guard let end = ISODateParser.parse(ambition.endAt) else { return true }
                return end > now
            }

            let mergedMatches = Self.mergeUnique(formingMatches + convertedMatches)
            matches = mergedMatches
            patterns = recurringPatterns

            hasLoaded = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func respondToMatch(matchID: Int, action: AmbitionMatchAction) async {
        guard activeMatchActions[matchID] == nil else { return }
        activeMatchActions[matchID] = action
        errorMessage = nil

        defer {
            activeMatchActions[matchID] = nil
        }

        do {
            switch action {
            case .accept:
                let updated = try await service.acceptMatch(matchID: matchID)
                upsertMatch(updated)
                if let hangoutID = updated.hangout {
                    pendingOpenHangoutID = hangoutID
                }
            case .decline:
                try await service.declineMatch(matchID: matchID)
                matches.removeAll { $0.id == matchID }
            }

            try await refreshMatchesOnly()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearPendingHangoutOpen() {
        pendingOpenHangoutID = nil
    }

    func pollForHangoutUpdates() async {
        do {
            try await refreshMatchesOnly()
            if let converted = matches.first(where: {
                ($0.userStatus ?? "").lowercased() == "accepted" && $0.hangout != nil
            }), let hangoutID = converted.hangout {
                pendingOpenHangoutID = hangoutID
            }
        } catch {
            // Polling errors are non-fatal; keep last visible state.
        }
    }

    private func refreshMatchesOnly() async throws {
        async let formingTask = service.listMatches(status: "forming")
        async let convertedTask = service.listMatches(status: "converted")

        let formingMatches = try await formingTask
        let convertedMatches = try await convertedTask

        matches = Self.mergeUnique(formingMatches + convertedMatches)
    }

    private func upsertMatch(_ updated: AmbitionMatch) {
        if let index = matches.firstIndex(where: { $0.id == updated.id }) {
            matches[index] = updated
            return
        }
        matches.insert(updated, at: 0)
    }

    private static func mergeUnique(_ input: [AmbitionMatch]) -> [AmbitionMatch] {
        var seen = Set<Int>()
        var output: [AmbitionMatch] = []

        for item in input {
            if seen.insert(item.id).inserted {
                output.append(item)
            }
        }

        return output
    }
}

enum AmbitionMatchAction: Equatable {
    case accept
    case decline
}

enum AmbitionsSection: String, CaseIterable, Identifiable {
    case ambition
    case matches
    case hangouts
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ambition: return "Ambition"
        case .matches: return "Matches"
        case .hangouts: return "Hangouts"
        case .weekly: return "Weekly"
        }
    }

    var icon: String {
        switch self {
        case .ambition: return "bolt.fill"
        case .matches: return "person.2.fill"
        case .hangouts: return "figure.2"
        case .weekly: return "calendar"
        }
    }

    var emptyTitle: String {
        switch self {
        case .ambition: return "No active ambitions"
        case .matches: return "No matches yet"
        case .hangouts: return "No hangouts yet"
        case .weekly: return "No weekly patterns"
        }
    }

    var emptySubtitle: String {
        switch self {
        case .ambition:
            return "Start your first ambition and we will match you with the right people."
        case .matches:
            return "When your ambitions line up with someone else, matches will appear here."
        case .hangouts:
            return "Converted matches become hangouts and will show up in this tab."
        case .weekly:
            return "Set recurring availability to get better weekly matches."
        }
    }
}

enum ISODateParser {
    private static let standardFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        return standardFormatter.date(from: value)
    }
}
