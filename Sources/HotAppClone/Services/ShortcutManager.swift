import Foundation

@MainActor
final class ShortcutManager {
    private let shortcutStore: ShortcutStore
    private let persistenceService: PersistenceService
    private let appSwitcher: AppSwitcher
    private let eventTapManager: EventTapManager
    private let permissionService: AccessibilityPermissionService
    private let keyMatcher = KeyMatcher()

    init(
        shortcutStore: ShortcutStore,
        persistenceService: PersistenceService,
        appSwitcher: AppSwitcher,
        eventTapManager: EventTapManager = EventTapManager(),
        permissionService: AccessibilityPermissionService = AccessibilityPermissionService()
    ) {
        self.shortcutStore = shortcutStore
        self.persistenceService = persistenceService
        self.appSwitcher = appSwitcher
        self.eventTapManager = eventTapManager
        self.permissionService = permissionService
    }

    func start() {
        guard permissionService.requestIfNeeded(prompt: true) else {
            return
        }

        eventTapManager.start { [weak self] keyPress in
            self?.handleKeyPress(keyPress)
        }
    }

    func stop() {
        eventTapManager.stop()
    }

    func save(shortcuts: [AppShortcut]) {
        shortcutStore.replaceAll(with: shortcuts)
        persistenceService.save(shortcuts)
    }

    @discardableResult
    func trigger(_ shortcut: AppShortcut) -> Bool {
        appSwitcher.toggleApplication(for: shortcut)
    }

    func hasAccessibilityAccess() -> Bool {
        permissionService.isTrusted()
    }

    private func handleKeyPress(_ keyPress: EventTapManager.KeyPress) {
        guard let match = shortcutStore.shortcuts.first(where: { keyMatcher.matches(keyPress, shortcut: $0) }) else {
            return
        }
        _ = trigger(match)
    }
}
