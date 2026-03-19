import AppKit
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var shortcuts: [AppShortcut] = []
    @Published var selectedAppName: String = ""
    @Published var selectedBundleIdentifier: String = ""
    @Published var keyEquivalent: String = ""
    @Published var modifierFlagsText: String = "command,option"
    @Published var accessibilityGranted: Bool = false
    @Published var conflictMessage: String?

    private let shortcutStore: ShortcutStore
    private let shortcutManager: ShortcutManager
    private let appBundleLocator = AppBundleLocator()
    private let shortcutValidator = ShortcutValidator()

    init(shortcutStore: ShortcutStore, shortcutManager: ShortcutManager) {
        self.shortcutStore = shortcutStore
        self.shortcutManager = shortcutManager
        self.shortcuts = shortcutStore.shortcuts
        self.accessibilityGranted = shortcutManager.hasAccessibilityAccess()
    }

    func addShortcut() {
        let modifiers = modifierFlagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let normalizedKey = shortcutValidator.normalizedKey(keyEquivalent)

        guard !selectedAppName.isEmpty,
              !selectedBundleIdentifier.isEmpty,
              !normalizedKey.isEmpty else {
            return
        }

        let candidate = AppShortcut(
            appName: selectedAppName,
            bundleIdentifier: selectedBundleIdentifier,
            keyEquivalent: normalizedKey,
            modifierFlags: modifiers
        )

        if let conflict = shortcutValidator.conflict(for: candidate, in: shortcuts) {
            conflictMessage = "Conflict: \(conflict.existingShortcut.appName) already uses \(conflict.existingShortcut.modifierFlags.joined(separator: "+"))+\(conflict.existingShortcut.keyEquivalent.uppercased())"
            return
        }

        var updated = shortcuts
        updated.append(candidate)
        shortcuts = updated
        shortcutManager.save(shortcuts: updated)
        conflictMessage = nil
        resetDraft()
    }

    func removeShortcut(id: UUID) {
        let updated = shortcuts.filter { $0.id != id }
        shortcuts = updated
        shortcutManager.save(shortcuts: updated)
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return
        }

        selectedAppName = url.deletingPathExtension().lastPathComponent
        selectedBundleIdentifier = bundleIdentifier
    }

    func revealApplication() {
        guard let url = appBundleLocator.applicationURL(for: selectedBundleIdentifier) else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func refreshPermissions() {
        accessibilityGranted = shortcutManager.hasAccessibilityAccess()
    }

    private func resetDraft() {
        selectedAppName = ""
        selectedBundleIdentifier = ""
        keyEquivalent = ""
        modifierFlagsText = "command,option"
    }
}
