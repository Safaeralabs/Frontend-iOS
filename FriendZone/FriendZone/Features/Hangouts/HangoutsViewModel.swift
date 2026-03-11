import Foundation
import Combine

@MainActor
final class HangoutsViewModel: ObservableObject {
    @Published private(set) var allHangouts: [HangoutItem] = []
    @Published private(set) var isLoading = true

    @Published var selectedTimeline: HangoutsTimelineTab = .today
    @Published var selectedFilter: HangoutsFilterMode = .forYou
    @Published var selectedDay: Date
    @Published var advancedFilters = HangoutsAdvancedFilters.default
    @Published private(set) var requestedJoinIDs: Set<Int> = []

    private let calendar = Calendar.current
    private var hasLoaded = false

    init() {
        selectedDay = calendar.startOfDay(for: Date())
    }

    var weekDays: [Date] {
        let start = calendar.startOfDay(for: Date())
        return (0 ..< 7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    var filteredHangouts: [HangoutItem] {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        return allHangouts
            .filter { $0.endAt > now }
            .filter { item in
                switch selectedTimeline {
                case .today:
                    return calendar.isDate(item.startAt, inSameDayAs: now)
                case .upcoming:
                    return item.startAt >= startOfTomorrow && calendar.isDate(item.startAt, inSameDayAs: selectedDay)
                case .joined:
                    return item.isJoined
                }
            }
            .filter(passesSecondaryFilters(_:))
            .sorted { $0.startAt < $1.startAt }
    }

    var futureHangouts: [HangoutItem] {
        let now = Date()
        return allHangouts
            .filter { $0.endAt > now }
            .filter(passesSecondaryFilters(_:))
            .sorted { $0.startAt < $1.startAt }
    }

    var upcomingHangouts: [HangoutItem] {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        return futureHangouts.filter { $0.startAt >= startOfTomorrow }
    }

    func hangouts(on day: Date) -> [HangoutItem] {
        futureHangouts.filter { calendar.isDate($0.startAt, inSameDayAs: day) }
    }

    func hasHangouts(on day: Date) -> Bool {
        !hangouts(on: day).isEmpty
    }

    var advancedFiltersActiveCount: Int {
        advancedFilters.activeCount
    }

    var hasAdvancedFilters: Bool {
        !advancedFilters.isDefault
    }

    var advancedFilterTokens: [String] {
        var tokens: [String] = []
        if advancedFilters.maxDistanceKm < HangoutsAdvancedFilters.default.maxDistanceKm {
            tokens.append("≤ \(String(format: "%.1f", advancedFilters.maxDistanceKm))km")
        }
        if advancedFilters.freeOnly {
            tokens.append("Free only")
        }
        if advancedFilters.openSpotsOnly != HangoutsAdvancedFilters.default.openSpotsOnly {
            tokens.append(advancedFilters.openSpotsOnly ? "Open spots" : "Including full")
        }
        if !advancedFilters.selectedVibes.isEmpty {
            tokens.append(contentsOf: advancedFilters.selectedVibes.map(\.title).sorted())
        }
        return tokens
    }

    var shouldShowDayPicker: Bool {
        selectedTimeline == .upcoming
    }

    var liveNowCount: Int {
        let now = Date()
        return allHangouts.filter { $0.isLive && $0.endAt > now }.count
    }

    var tonightCount: Int {
        let now = Date()
        return allHangouts.filter {
            calendar.isDate($0.startAt, inSameDayAs: now) && $0.endAt > now
        }.count
    }

    var openSpotsCount: Int {
        filteredHangouts.reduce(0) { partial, item in
            partial + item.spotsLeft
        }
    }

    var timelineCounts: [HangoutsTimelineTab: Int] {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        let future = allHangouts.filter { $0.endAt > now }

        let today = future.filter { calendar.isDate($0.startAt, inSameDayAs: now) }.count
        let upcoming = future.filter { $0.startAt >= startOfTomorrow }.count
        let joined = future.filter { $0.isJoined }.count

        return [
            .today: today,
            .upcoming: upcoming,
            .joined: joined
        ]
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        allHangouts = []
        requestedJoinIDs.removeAll()
        hasLoaded = true
        isLoading = false
    }

    func replaceHangouts(_ items: [HangoutItem], requestedIDs: Set<Int>) {
        allHangouts = items
        requestedJoinIDs = requestedIDs
        hasLoaded = true
        isLoading = false
    }

    func resetFilters() {
        selectedFilter = .forYou
        selectedDay = calendar.startOfDay(for: Date())
        selectedTimeline = .today
        clearAdvancedFilters()
    }

    func selectTimeline(_ tab: HangoutsTimelineTab) {
        selectedTimeline = tab

        let today = calendar.startOfDay(for: Date())
        switch tab {
        case .today:
            selectedDay = today
        case .upcoming:
            if selectedDay <= today {
                selectedDay = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            }
        case .joined:
            break
        }
    }

    func addCreatedHangout(from draft: CreateHangoutDraft) {
        let endAt = draft.startAt.addingTimeInterval(Double(draft.durationHours) * 60 * 60)
        let newID = (allHangouts.map(\.id).max() ?? 100) + 1

        let item = HangoutItem(
            id: newID,
            sourceType: draft.sourceType,
            title: draft.title,
            description: draft.description,
            vibe: draft.vibe,
            cityName: draft.cityName,
            locationName: draft.locationName.isEmpty ? nil : draft.locationName,
            hostName: "you",
            startAt: draft.startAt,
            endAt: endAt,
            capacity: draft.capacity,
            approvedCount: 1,
            isLive: draft.isLive,
            isMicro: draft.isMicro,
            isJoined: true,
            participantNames: ["You"],
            coverImageData: draft.coverImageData,
            coverSeed: draft.coverSeed,
            distanceKm: 0.8,
            priceTier: .free
        )

        allHangouts.insert(item, at: 0)

        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(item.startAt, inSameDayAs: today) {
            selectedTimeline = .today
            selectedDay = today
        } else {
            selectedTimeline = .upcoming
            selectedDay = calendar.startOfDay(for: item.startAt)
        }
    }

    func clearAdvancedFilters() {
        advancedFilters = .default
    }

    func joinStatus(for item: HangoutItem) -> HangoutJoinStatus {
        if item.isJoined {
            return .joined
        }
        if requestedJoinIDs.contains(item.id) {
            return .requested
        }
        return .none
    }

    func requestJoin(for item: HangoutItem) {
        guard !item.isJoined, !item.isFull else { return }
        requestedJoinIDs.insert(item.id)
    }

    func cancelJoinRequest(for item: HangoutItem) {
        requestedJoinIDs.remove(item.id)
    }

    private func passesSecondaryFilters(_ item: HangoutItem) -> Bool {
        switch selectedFilter {
        case .forYou:
            break
        case .live:
            guard item.isLive else { return false }
        case .micro:
            guard item.isMicro else { return false }
        }

        if advancedFilters.freeOnly && item.priceTier != .free {
            return false
        }
        if advancedFilters.openSpotsOnly && item.isFull {
            return false
        }
        if item.distanceKm > advancedFilters.maxDistanceKm {
            return false
        }
        if !advancedFilters.selectedVibes.isEmpty && !advancedFilters.selectedVibes.contains(item.vibe) {
            return false
        }

        return true
    }
}
