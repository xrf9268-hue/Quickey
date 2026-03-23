import Foundation
import ServiceManagement
import Testing
@testable import Quickey

@Test @MainActor
func initSnapshotsShortcutAndLaunchAtLoginState() {
    let suiteName = "AppPreferencesTests.initSnapshotsShortcutAndLaunchAtLoginState"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(true, forKey: "hyperKeyEnabled")

    let preferences = AppPreferences(
        shortcutManager: makeShortcutManager(
            permissionService: FakePermissionService(ax: true, input: false),
            eventTapManager: FakeEventTapManager()
        ),
        hyperKeyService: HyperKeyService(runner: { _ in true }, defaults: defaults),
        launchAtLoginService: makeLaunchAtLoginService(state: MutableLaunchAtLoginState(status: .requiresApproval))
    )

    #expect(preferences.shortcutCaptureStatus == ShortcutCaptureStatus(
        accessibilityGranted: true,
        inputMonitoringGranted: false,
        eventTapActive: false
    ))
    #expect(preferences.launchAtLoginStatus == .requiresApproval)
    #expect(preferences.launchAtLoginEnabled == false)
    #expect(preferences.hyperKeyEnabled == true)
}

@Test @MainActor
func setLaunchAtLoginDoesNotUpdateStateWhenRegistrationFails() {
    let state = MutableLaunchAtLoginState(status: .notRegistered)
    state.registerError = TestError.registerFailed
    let preferences = AppPreferences(
        shortcutManager: makeShortcutManager(
            permissionService: FakePermissionService(ax: true, input: true),
            eventTapManager: FakeEventTapManager()
        ),
        launchAtLoginService: makeLaunchAtLoginService(state: state)
    )

    preferences.setLaunchAtLogin(true)

    #expect(preferences.launchAtLoginStatus == .disabled)
    #expect(preferences.launchAtLoginEnabled == false)
}

@Test @MainActor
func setHyperKeyEnabledTracksActualServiceStateAfterFailure() {
    let suiteName = "AppPreferencesTests.setHyperKeyEnabledTracksActualServiceStateAfterFailure"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let preferences = AppPreferences(
        shortcutManager: makeShortcutManager(
            permissionService: FakePermissionService(ax: true, input: true),
            eventTapManager: FakeEventTapManager()
        ),
        hyperKeyService: HyperKeyService(runner: { _ in false }, defaults: defaults)
    )

    preferences.setHyperKeyEnabled(true)

    #expect(preferences.hyperKeyEnabled == false)
}

private struct FakePermissionService: PermissionServicing {
    let ax: Bool
    let input: Bool

    func isTrusted() -> Bool {
        ax && input
    }

    func isAccessibilityTrusted() -> Bool {
        ax
    }

    func isInputMonitoringTrusted() -> Bool {
        input
    }

    @discardableResult
    func requestIfNeeded(prompt: Bool) -> Bool {
        isTrusted()
    }
}

@MainActor
private final class FakeEventTapManager: EventTapManaging {
    var isRunning = false

    func start(onKeyPress: @escaping (KeyPress) -> Bool) -> EventTapStartResult {
        isRunning = true
        return .started
    }

    func stop() {
        isRunning = false
    }

    func updateRegisteredShortcuts(_ keyPresses: Set<KeyPress>) {}

    func setHyperKeyEnabled(_ enabled: Bool) {}
}

@MainActor
private struct FakeAppSwitcher: AppSwitching {
    @discardableResult
    func toggleApplication(for shortcut: AppShortcut) -> Bool {
        true
    }
}

@MainActor
private func makeShortcutManager(
    permissionService: some PermissionServicing,
    eventTapManager: some EventTapManaging
) -> ShortcutManager {
    ShortcutManager(
        shortcutStore: ShortcutStore(),
        persistenceService: PersistenceService(),
        appSwitcher: FakeAppSwitcher(),
        eventTapManager: eventTapManager,
        permissionService: permissionService
    )
}

private enum TestError: Error {
    case registerFailed
    case unregisterFailed
}

private final class MutableLaunchAtLoginState: @unchecked Sendable {
    var status: SMAppService.Status
    var registerError: Error?
    var unregisterError: Error?

    init(status: SMAppService.Status) {
        self.status = status
    }
}

private func makeLaunchAtLoginService(state: MutableLaunchAtLoginState) -> LaunchAtLoginService {
    LaunchAtLoginService(client: .init(
        status: { state.statusValue },
        register: {
            if let registerError = state.registerError {
                throw registerError
            }
            state.statusValue = .enabled
        },
        unregister: {
            if let unregisterError = state.unregisterError {
                throw unregisterError
            }
            state.statusValue = .notRegistered
        },
        openSystemSettingsLoginItems: {}
    ))
}

private extension MutableLaunchAtLoginState {
    var statusValue: SMAppService.Status {
        get { status }
        set { status = newValue }
    }
}
