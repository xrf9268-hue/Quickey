import Foundation

struct HourlyUsageBucket: Sendable, Equatable, Hashable {
    let date: String
    let hour: Int
    let count: Int
}

protocol UsageTracking: Sendable {
    func usageCounts(days: Int, relativeTo now: Date) async -> [UUID: Int]
    func dailyCounts(days: Int, relativeTo now: Date) async -> [String: [(date: String, count: Int)]]
    func totalSwitches(days: Int, relativeTo now: Date) async -> Int
    func hourlyCounts(days: Int, relativeTo now: Date) async -> [HourlyUsageBucket]
    func previousPeriodTotal(days: Int, relativeTo now: Date) async -> Int
    func streakDays(relativeTo now: Date) async -> Int
}

extension UsageTracking {
    func usageCounts(days: Int) async -> [UUID: Int] {
        await usageCounts(days: days, relativeTo: Date())
    }

    func dailyCounts(days: Int) async -> [String: [(date: String, count: Int)]] {
        await dailyCounts(days: days, relativeTo: Date())
    }

    func totalSwitches(days: Int) async -> Int {
        await totalSwitches(days: days, relativeTo: Date())
    }

    func hourlyCounts(days: Int) async -> [HourlyUsageBucket] {
        await hourlyCounts(days: days, relativeTo: Date())
    }

    func hourlyCounts(days: Int, relativeTo now: Date) async -> [HourlyUsageBucket] {
        []
    }

    func previousPeriodTotal(days: Int) async -> Int {
        await previousPeriodTotal(days: days, relativeTo: Date())
    }

    func previousPeriodTotal(days: Int, relativeTo now: Date) async -> Int {
        0
    }

    func streakDays() async -> Int {
        await streakDays(relativeTo: Date())
    }

    func streakDays(relativeTo now: Date) async -> Int {
        0
    }
}
