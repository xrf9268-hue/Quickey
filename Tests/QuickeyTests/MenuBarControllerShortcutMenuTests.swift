import AppKit
import Testing
@testable import Quickey

@Suite("Menu bar controller shortcut menu")
struct MenuBarControllerShortcutMenuTests {
    @Test @MainActor
    func rebuildShortcutSection_replacesPreviousDynamicSectionAndPreservesStaticItems() {
        let controller = MenuBarController(onOpenSettings: {}, onQuit: {})
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Settings", action: nil, keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: nil, keyEquivalent: "q"))

        let presentations = [
            MenuBarShortcutItemPresentation(
                bundleIdentifier: "com.apple.Safari",
                titleText: "Safari",
                shortcutText: "⌃⌥S",
                statusText: nil,
                isEnabled: true,
                isRunning: true,
                isPlaceholder: false
            )
        ]

        controller.rebuildShortcutSection(in: menu, presentations: presentations)
        controller.rebuildShortcutSection(in: menu, presentations: presentations)

        let shortcutRowMarkers = menu.items.filter {
            ($0.representedObject as? String) == MenuBarControllerMenuItemMarker.shortcutRow
        }
        let shortcutDividerMarkers = menu.items.filter {
            ($0.representedObject as? String) == MenuBarControllerMenuItemMarker.shortcutDivider
        }

        #expect(shortcutRowMarkers.count == 1)
        #expect(shortcutDividerMarkers.count == 1)
        #expect(menu.items.count == 7)
        #expect(menu.items[0].title == "Safari")
        #expect(menu.items[1].isSeparatorItem)
        #expect(menu.items[2].title == "Settings")
        #expect(menu.items[3].isSeparatorItem)
        #expect(menu.items[4].title == "Launch at Login")
        #expect(menu.items[5].isSeparatorItem)
        #expect(menu.items[6].title == "Quit")
    }
}
