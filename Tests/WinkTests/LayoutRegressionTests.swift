import AppKit
import SwiftUI
import Testing
@testable import Wink

@Suite("Layout regressions")
struct LayoutRegressionTests {
    @Test @MainActor
    func insightsRankingUsesScrollViewWhenRankingIsPopulated() async {
        let shortcutId = UUID()
        let store = ShortcutStore()
        store.replaceAll(with: [
            AppShortcut(
                id: shortcutId,
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                keyEquivalent: "s",
                modifierFlags: ["command"]
            )
        ])

        let viewModel = InsightsViewModel(
            usageTracker: StaticUsageTracker(shortcutId: shortcutId),
            shortcutStore: store
        )
        await viewModel.refresh(for: .week)

        let hostingView = makeHostingView(
            InsightsTabView(viewModel: viewModel),
            size: NSSize(width: 680, height: 420)
        )

        #expect(containsDescendant(in: hostingView) { $0 is NSScrollView })
    }

    @Test @MainActor
    func insightsCardUsesUpdatedSectionTitleCopy() {
        #expect(InsightsTabCopy.rankingSectionTitle == "Most used")
    }

    @Test @MainActor
    func winkCardExpandsToFillWidthInsideLeadingStack() {
        let hostingView = makeHostingView(
            CardWidthProbeView(),
            size: NSSize(width: 720, height: 220)
        )

        let widestDirectSubview = hostingView.subviews
            .map(\.frame.width)
            .max() ?? 0

        #expect(widestDirectSubview >= 660)
    }

    @Test @MainActor
    func shortcutsListRowPresentationUsesUsageSubtitleWithoutVisibleBundleIdentifier() {
        let shortcut = AppShortcut(
            appName: "Missing App",
            bundleIdentifier: "com.example.MissingApp",
            keyEquivalent: "m",
            modifierFlags: ["command", "shift"]
        )
        let presentation = ShortcutsListRowPresentation(
            shortcut: shortcut,
            usageCount: 732,
            runtimeStatus: ShortcutRuntimeStatus(
                isRunning: false,
                isUnavailable: true
            )
        )

        #expect(presentation.title == "Missing App")
        #expect(presentation.subtitle == "732× past 7 days")
        // usageCount > 0 but lastUsed is nil: show the em-dash placeholder so the
        // user still sees the "past 7 days" counter rather than a misleading "—".
        #expect(presentation.metadataText == "732× past 7 days · Last used —")
        #expect(presentation.contentOpacity == 1.0)
        #expect(presentation.showsRunningIndicator == false)
        #expect(presentation.runningStatusText == nil)
        #expect(presentation.unavailableStatusText == "App unavailable")
        #expect(presentation.unavailableHelpText == "Couldn't find this app. Rebind it to restore the shortcut.")
        #expect(presentation.title != "com.example.MissingApp")
        #expect(presentation.subtitle != "com.example.MissingApp")
        #expect(presentation.unavailableStatusText != "com.example.MissingApp")
        #expect(presentation.unavailableHelpText != "com.example.MissingApp")
    }

    @Test @MainActor
    func shortcutsListRowPresentationRendersNotUsedYetWhenUsageCountIsZero() {
        let shortcut = AppShortcut(
            appName: "Notes",
            bundleIdentifier: "com.apple.Notes",
            keyEquivalent: "n",
            modifierFlags: ["command", "option"]
        )
        let presentation = ShortcutsListRowPresentation(
            shortcut: shortcut,
            usageCount: 0,
            runtimeStatus: ShortcutRuntimeStatus(isRunning: false, isUnavailable: false)
        )

        #expect(presentation.metadataText == "Not used yet")
    }

    @Test @MainActor
    func shortcutsListRowPresentationShowsHistoricalLastUsedWhenSevenDayCountIsZero() {
        // Shortcut triggered more than 7 days ago: usageCount drops to 0 but the
        // hourly history still carries a timestamp. We should surface the historical
        // last-used rather than falsely claiming the shortcut was never used.
        let shortcut = AppShortcut(
            appName: "Zed",
            bundleIdentifier: "dev.zed.Zed",
            keyEquivalent: "z",
            modifierFlags: ["command", "option", "shift", "control"]
        )
        let now = Date()
        let tenDaysAgo = now.addingTimeInterval(-10 * 24 * 60 * 60)
        let presentation = ShortcutsListRowPresentation(
            shortcut: shortcut,
            usageCount: 0,
            runtimeStatus: ShortcutRuntimeStatus(isRunning: false, isUnavailable: false),
            lastUsed: tenDaysAgo,
            now: now
        )

        #expect(presentation.metadataText != "Not used yet")
        #expect(presentation.metadataText.hasPrefix("Last used "))
        #expect(!presentation.metadataText.contains("past 7 days"))
    }

    @Test @MainActor
    func shortcutsListRowPresentationRendersRelativeLastUsedWhenDateIsProvided() {
        let shortcut = AppShortcut(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            keyEquivalent: "t",
            modifierFlags: ["command", "option"]
        )
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-2 * 60 * 60)
        let presentation = ShortcutsListRowPresentation(
            shortcut: shortcut,
            usageCount: 32,
            runtimeStatus: ShortcutRuntimeStatus(isRunning: false, isUnavailable: false),
            lastUsed: twoHoursAgo,
            now: now
        )

        #expect(presentation.metadataText.hasPrefix("32× past 7 days · Last used "))
        #expect(presentation.metadataText != "32× past 7 days · Last used —")
        #expect(presentation.lastUsedText != "Last used —")
    }

    @Test @MainActor
    func shortcutsListRowPresentationShowsRunningIndicatorWhenAppIsActive() {
        let shortcut = AppShortcut(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            keyEquivalent: "s",
            modifierFlags: ["command"]
        )
        let presentation = ShortcutsListRowPresentation(
            shortcut: shortcut,
            usageCount: 12,
            runtimeStatus: ShortcutRuntimeStatus(
                isRunning: true,
                isUnavailable: false
            )
        )

        #expect(presentation.showsRunningIndicator == true)
        #expect(presentation.runningStatusText == nil)
        #expect(presentation.unavailableHelpText == nil)
    }

    @Test @MainActor
    func shortcutsListRowPresentationAddsRunningLabelWhenDifferentiateWithoutColorIsEnabled() {
        let shortcut = AppShortcut(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            keyEquivalent: "s",
            modifierFlags: ["command"]
        )
        let presentation = ShortcutsListRowPresentation(
            shortcut: shortcut,
            usageCount: 12,
            runtimeStatus: ShortcutRuntimeStatus(
                isRunning: true,
                isUnavailable: false
            ),
            accessibilityOptions: ShortcutRowAccessibilityOptions(
                differentiateWithoutColor: true,
                reduceMotion: false
            )
        )

        #expect(presentation.showsRunningIndicator == true)
        #expect(presentation.runningStatusText == "Running")
        #expect(presentation.unavailableStatusText == nil)
    }

    @Test @MainActor
    func shortcutsListRowPresentationOnlyDimsDisabledRows() {
        let shortcut = AppShortcut(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            keyEquivalent: "t",
            modifierFlags: ["command"],
            isEnabled: false
        )
        let presentation = ShortcutsListRowPresentation(
            shortcut: shortcut,
            usageCount: 4,
            runtimeStatus: ShortcutRuntimeStatus(
                isRunning: false,
                isUnavailable: true
            )
        )

        #expect(presentation.contentOpacity == 0.65)
        #expect(presentation.unavailableStatusText == "App unavailable")
    }

    @Test @MainActor
    func shortcutComposerUsesExpectedRecorderPlaceholderAndDashSpec() {
        #expect(ShortcutRecorderIdleField.placeholderText == "Press a key combination…")
        #expect(ShortcutRecorderIdleField.dashPattern == [4, 4])
    }
}

private actor StaticUsageTracker: UsageTracking {
    let shortcutId: UUID

    init(shortcutId: UUID) {
        self.shortcutId = shortcutId
    }

    func usageCounts(days: Int, relativeTo now: Date) async -> [UUID: Int] {
        [shortcutId: 1647]
    }

    func dailyCounts(days: Int, relativeTo now: Date) async -> [String: [(date: String, count: Int)]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        return [
            shortcutId.uuidString: [
                (date: formatter.string(from: now), count: 1647),
            ]
        ]
    }

    func totalSwitches(days: Int, relativeTo now: Date) async -> Int {
        1647
    }

    func hourlyCounts(days: Int, relativeTo now: Date) async -> [HourlyUsageBucket] {
        []
    }

    func previousPeriodTotal(days: Int, relativeTo now: Date) async -> Int {
        0
    }

    func streakDays(relativeTo now: Date) async -> Int {
        0
    }

    func usageTimeZone() async -> TimeZone {
        .current
    }
}

private struct CardWidthProbeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WinkCard(title: { Text("Startup") }) {
                Text("Launch at Login")
                    .padding(14)
            }

            Spacer()
        }
        .frame(width: 680, height: 180)
        .padding(20)
    }
}

@MainActor
private func makeHostingView<Content: View>(_ rootView: Content, size: NSSize) -> NSHostingView<Content> {
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = NSRect(origin: .zero, size: size)
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    hostingView.layoutSubtreeIfNeeded()
    return hostingView
}

@MainActor
private func containsDescendant(
    in view: NSView,
    where matches: (NSView) -> Bool
) -> Bool {
    if matches(view) {
        return true
    }

    for subview in view.subviews {
        if containsDescendant(in: subview, where: matches) {
            return true
        }
    }

    return false
}
