import Foundation
import Combine

@MainActor
final class AmbitionsViewModel: ObservableObject {
    @Published private(set) var ambitions: [Ambition] = []
    @Published private(set) var matches: [AmbitionMatch] = []

    @Published private(set) var isLoading = false
    @Published private(set) var isCreating = false
    @Published private(set) var activeMatchActions: [Int: AmbitionMatchAction] = [:]
    @Published var pendingOpenHangoutID: Int?
    @Published var errorMessage: String?
    @Published var successMessage: String?

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

            let activeAmbitions = try await ambitionsTask
            let formingMatches = try await formingTask
            let convertedMatches = try await convertedTask

            let now = Date()
            ambitions = activeAmbitions.filter { ambition in
                guard let end = ISODateParser.parse(ambition.endAt) else { return true }
                return end > now
            }

            let mergedMatches = Self.mergeUnique(formingMatches + convertedMatches)
            matches = mergedMatches

            hasLoaded = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func createQuickAmbition(_ payload: QuickAmbitionPayload) async {
        guard !isCreating else { return }
        isCreating = true
        errorMessage = nil
        successMessage = nil

        defer { isCreating = false }

        do {
            let response = try await service.createQuickAmbition(payload)
            ambitions.insert(response.ambition, at: 0)

            if let match = response.match {
                upsertMatch(match)
                if let hangoutID = match.hangout {
                    pendingOpenHangoutID = hangoutID
                    successMessage = "Hangout unlocked."
                } else if (match.userStatus ?? "").lowercased() == "accepted" {
                    successMessage = "You are in. Waiting on the others."
                } else {
                    successMessage = "Signal sent. We found a possible crew."
                }
            } else {
                successMessage = "Signal sent. We will keep looking."
            }

            hasLoaded = true
            try await refreshMatchesOnly()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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

    func clearSuccessMessage() {
        successMessage = nil
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
