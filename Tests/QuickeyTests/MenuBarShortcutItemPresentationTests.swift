import Testing
@testable import Quickey

@Suite("MenuBar shortcut item presentation")
struct MenuBarShortcutItemPresentationTests {
    @Test
    func preservesShortcutOrderAndMarksRunningBundles() {
        let shortcuts = [
            AppShortcut(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                keyEquivalent: "s",
                modifierFlags: ["control", "option"]
            ),
            AppShortcut(
                appName: "IINA",
                bundleIdentifier: "com.colliderli.iina",
                keyEquivalent: "i",
                modifierFlags: ["control", "option"],
                isEnabled: false
            )
        ]

        let presentations = MenuBarShortcutItemPresentation.build(
            from: shortcuts,
            runningBundleIdentifiers: ["com.apple.Safari"]
        )

        #expect(presentations.map(\.titleText) == ["Safari", "IINA"])
        #expect(presentations.map(\.isRunning) == [true, false])
        #expect(presentations.map(\.statusText) == [nil, "disabled"])
    }

    @Test
    func returnsPlaceholderWhenShortcutListIsEmpty() {
        let presentations = MenuBarShortcutItemPresentation.build(
            from: [],
            runningBundleIdentifiers: []
        )

        #expect(presentations.count == 1)
        #expect(presentations[0].isPlaceholder == true)
        #expect(presentations[0].titleText == "No shortcuts configured")
    }
}
