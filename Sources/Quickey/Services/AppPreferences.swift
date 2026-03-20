import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
    private(set) var accessibilityGranted: Bool = false
    var launchAtLoginEnabled: Bool = false
    var hyperKeyEnabled: Bool = false

    private let shortcutManager: ShortcutManager
    private let hyperKeyService: HyperKeyService?
    private let launchAtLoginService = LaunchAtLoginService()

    init(shortcutManager: ShortcutManager, hyperKeyService: HyperKeyService? = nil) {
        self.shortcutManager = shortcutManager
        self.hyperKeyService = hyperKeyService
        self.accessibilityGranted = shortcutManager.hasAccessibilityAccess()
        self.launchAtLoginEnabled = launchAtLoginService.isEnabled
        self.hyperKeyEnabled = hyperKeyService?.isEnabled ?? false
    }

    func refreshPermissions() {
        accessibilityGranted = shortcutManager.hasAccessibilityAccess()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginService.setEnabled(enabled)
        launchAtLoginEnabled = launchAtLoginService.isEnabled
    }

    func setHyperKeyEnabled(_ enabled: Bool) {
        guard let hyperKeyService else { return }
        if enabled {
            hyperKeyService.enable()
        } else {
            hyperKeyService.disable()
        }
        hyperKeyEnabled = hyperKeyService.isEnabled
        shortcutManager.setHyperKeyEnabled(hyperKeyEnabled)
    }
}
