import Testing
@testable import HotAppClone

@Test
func appShortcutStoresBundleIdentifier() {
    let shortcut = AppShortcut(
        appName: "Slack",
        bundleIdentifier: "com.tinyspeck.slackmacgap",
        keyEquivalent: "s",
        modifierFlags: ["command", "option", "control", "shift"]
    )

    #expect(shortcut.bundleIdentifier == "com.tinyspeck.slackmacgap")
}

@Suite("EventTapManager lifecycle")
struct EventTapManagerLifecycleTests {
    @Test @MainActor
    func isRunningStartsFalse() {
        let manager = EventTapManager()
        #expect(manager.isRunning == false)
    }

    @Test @MainActor
    func stopIsIdempotentWhenNotRunning() {
        let manager = EventTapManager()
        manager.stop()
        manager.stop()
        #expect(manager.isRunning == false)
    }
}
