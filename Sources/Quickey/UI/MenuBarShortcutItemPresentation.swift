import Foundation

struct MenuBarShortcutItemPresentation: Equatable {
    let bundleIdentifier: String?
    let titleText: String
    let shortcutText: String?
    let statusText: String?
    let isEnabled: Bool
    let isRunning: Bool
    let isPlaceholder: Bool

    static func build(
        from shortcuts: [AppShortcut],
        runningBundleIdentifiers: Set<String>
    ) -> [MenuBarShortcutItemPresentation] {
        guard !shortcuts.isEmpty else {
            return [
                MenuBarShortcutItemPresentation(
                    bundleIdentifier: nil,
                    titleText: "No shortcuts configured",
                    shortcutText: nil,
                    statusText: nil,
                    isEnabled: false,
                    isRunning: false,
                    isPlaceholder: true
                )
            ]
        }

        return shortcuts.map { shortcut in
            MenuBarShortcutItemPresentation(
                bundleIdentifier: shortcut.bundleIdentifier,
                titleText: shortcut.appName,
                shortcutText: shortcut.displayText,
                statusText: shortcut.isEnabled ? nil : "disabled",
                isEnabled: shortcut.isEnabled,
                isRunning: runningBundleIdentifiers.contains(shortcut.bundleIdentifier),
                isPlaceholder: false
            )
        }
    }
}
