import Foundation
import Testing
@testable import Wink

@Suite("Hourly heatmap data")
struct HourlyHeatmapDataTests {
    @Test
    func hourlyCountsReturnZeroFilledAlignedSevenDayWindow() async {
        let harness = TestPersistenceHarness()
        defer { harness.cleanup() }

        let tracker = UsageTracker(
            databasePath: harness.directory.appendingPathComponent("usage.db").path,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        let shortcutID = UUID()
        let reference = isoDateTime("2026-04-22T12:00:00Z")

        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-22T09:15:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-22T09:45:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-20T18:00:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-16T00:05:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-15T10:00:00Z"))

        let buckets = await tracker.hourlyCounts(days: 7, relativeTo: reference)

        #expect(buckets.count == 7 * 24)
        #expect(buckets.first == HourlyUsageBucket(date: "2026-04-16", hour: 0, count: 1))
        #expect(buckets.last == HourlyUsageBucket(date: "2026-04-22", hour: 23, count: 0))
        #expect(buckets.contains(HourlyUsageBucket(date: "2026-04-22", hour: 9, count: 2)))
        #expect(buckets.contains(HourlyUsageBucket(date: "2026-04-20", hour: 18, count: 1)))
        #expect(buckets.contains(HourlyUsageBucket(date: "2026-04-17", hour: 4, count: 0)))
        #expect(buckets.contains { $0.date == "2026-04-15" } == false)
    }

    @Test
    func previousPeriodTotalUsesAdjacentWindowBoundaries() async {
        let harness = TestPersistenceHarness()
        defer { harness.cleanup() }

        let tracker = UsageTracker(
            databasePath: harness.directory.appendingPathComponent("usage.db").path,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        let shortcutID = UUID()
        let reference = isoDateTime("2026-04-22T12:00:00Z")

        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-22T09:00:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-21T09:00:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-20T09:00:00Z"))

        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-15T09:00:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-15T10:00:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-10T11:00:00Z"))
        await tracker.recordUsage(shortcutId: shortcutID, on: isoDateTime("2026-04-09T12:00:00Z"))

        #expect(await tracker.totalSwitches(days: 7, relativeTo: reference) == 3)
        #expect(await tracker.previousPeriodTotal(days: 7, relativeTo: reference) == 4)
    }
}

private func isoDateTime(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: value)!
}
