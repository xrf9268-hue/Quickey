import Foundation
import Observation

enum InsightsPeriod: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"

    var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        }
    }

    var label: String {
        switch self {
        case .day: "Today"
        case .week: "Past 7 Days"
        case .month: "Past 30 Days"
        }
    }

    var summaryRangeText: String {
        switch self {
        case .day: "today"
        case .week: "in the past 7 days"
        case .month: "in the past 30 days"
        }
    }
}

struct RankedShortcut: Identifiable {
    let id: UUID
    let appName: String
    let bundleIdentifier: String
    let count: Int
}

@Observable @MainActor
final class InsightsViewModel {
    var period: InsightsPeriod = .week {
        didSet { scheduleRefresh() }
    }
    var totalCount: Int = 0
    var ranking: [RankedShortcut] = []

    private let usageTracker: (any UsageTracking)?
    private let shortcutStore: ShortcutStore
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration: UInt64 = 0

    init(usageTracker: (any UsageTracking)?, shortcutStore: ShortcutStore) {
        self.usageTracker = usageTracker
        self.shortcutStore = shortcutStore
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let selectedPeriod = period
        refreshTask = Task { @MainActor [weak self] in
            await self?.doRefresh(for: selectedPeriod, generation: generation)
        }
    }

    func refresh() async {
        refreshGeneration &+= 1
        await doRefresh(for: period, generation: refreshGeneration)
    }

    func refresh(for period: InsightsPeriod) async {
        refreshGeneration &+= 1
        await doRefresh(for: period, generation: refreshGeneration)
    }

    private func doRefresh(for period: InsightsPeriod, generation: UInt64) async {
        let now = Date()

        guard let usageTracker else {
            guard generation == refreshGeneration else { return }
            totalCount = 0
            ranking = []
            return
        }

        let days = period.days
        async let totalCountResult = usageTracker.totalSwitches(days: days, relativeTo: now)
        async let countsResult = usageTracker.usageCounts(days: days, relativeTo: now)

        let totalCount = await totalCountResult
        let counts = await countsResult
        let shortcuts = shortcutStore.shortcuts
        let shortcutMap = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.id, $0) })

        guard !Task.isCancelled else { return }
        guard generation == refreshGeneration else { return }

        self.totalCount = totalCount

        var ranked: [RankedShortcut] = []
        for (id, count) in counts {
            guard let shortcut = shortcutMap[id] else { continue }
            ranked.append(RankedShortcut(id: id, appName: shortcut.appName, bundleIdentifier: shortcut.bundleIdentifier, count: count))
        }
        ranked.sort {
            if $0.count == $1.count {
                return $0.appName.localizedStandardCompare($1.appName) == .orderedAscending
            }
            return $0.count > $1.count
        }
        ranking = ranked
    }
}
