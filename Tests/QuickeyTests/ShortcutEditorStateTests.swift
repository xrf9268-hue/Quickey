import Foundation
import Testing
@testable import Quickey

@Test @MainActor
func savingShortcutChangesInvokesConfigurationChangeHandler() {
    let shortcut = AppShortcut(
        appName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        keyEquivalent: "s",
        modifierFlags: ["command", "option", "control", "shift"]
    )
    let context = makeEditorContext(existingShortcuts: [shortcut])
    defer { context.harness.cleanup() }

    context.editor.toggleShortcutEnabled(id: shortcut.id)
    context.editor.setAllEnabled(true)

    #expect(context.callbackCount.value == 2)
}

@Test @MainActor
func beginImportBuildsPreviewWithoutPersistingChanges() throws {
    let context = makeEditorContext()
    defer { context.harness.cleanup() }

    let recipeData = try QuickeyRecipeCodec().encode(
        QuickeyRecipe(shortcuts: [
            QuickeyRecipeShortcut(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                keyEquivalent: "s",
                modifierFlags: ["command"],
                isEnabled: true
            )
        ])
    )

    try context.editor.beginImport(
        from: recipeData,
        installedApps: [
            AppEntry(
                id: "com.apple.Safari",
                name: "Safari",
                url: URL(fileURLWithPath: "/Applications/Safari.app")
            )
        ]
    )

    let persisted = try context.harness.makePersistenceService().load()

    #expect(context.editor.pendingRecipeImport?.entries.count == 1)
    #expect(persisted.isEmpty)
    #expect(context.callbackCount.value == 0)
}

@Test @MainActor
func applyPendingImportWithReplaceExistingPersistsUpdatedShortcuts() throws {
    let context = makeEditorContext(existingShortcuts: [
        AppShortcut(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            keyEquivalent: "s",
            modifierFlags: ["command"]
        )
    ])
    defer { context.harness.cleanup() }

    let recipeData = try QuickeyRecipeCodec().encode(
        QuickeyRecipe(shortcuts: [
            QuickeyRecipeShortcut(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                keyEquivalent: "s",
                modifierFlags: ["command"],
                isEnabled: true
            )
        ])
    )

    try context.editor.beginImport(
        from: recipeData,
        installedApps: [
            AppEntry(
                id: "com.apple.Safari",
                name: "Safari",
                url: URL(fileURLWithPath: "/Applications/Safari.app")
            )
        ]
    )

    context.editor.applyPendingImport(strategy: .replaceExisting)

    let saved = try context.harness.makePersistenceService().load()
    #expect(saved.count == 1)
    #expect(saved[0].bundleIdentifier == "com.apple.Safari")
    #expect(context.editor.pendingRecipeImport == nil)
    #expect(context.callbackCount.value == 1)
}

@Test @MainActor
func beginImportUsesBundleLocatorWhenScanCatalogMissesInstalledApp() throws {
    let locator = AppBundleLocator(applicationURLClient: { bundleIdentifier in
        guard bundleIdentifier == "com.apple.Safari" else {
            return nil
        }
        return URL(fileURLWithPath: "/Applications/Safari.app")
    })
    let context = makeEditorContext(appBundleLocator: locator)
    defer { context.harness.cleanup() }

    let recipeData = try QuickeyRecipeCodec().encode(
        QuickeyRecipe(shortcuts: [
            QuickeyRecipeShortcut(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                keyEquivalent: "s",
                modifierFlags: ["command"],
                isEnabled: true
            )
        ])
    )

    try context.editor.beginImport(from: recipeData, installedApps: [])

    let resolution = try #require(context.editor.pendingRecipeImport?.entries.first?.imported.resolution)
    #expect(resolution == .matchedByBundleIdentifier)
}

@Test @MainActor
func exportRecipeDataUsesShareableSchema() throws {
    let context = makeEditorContext(existingShortcuts: [
        AppShortcut(
            appName: "IINA",
            bundleIdentifier: "com.colliderli.iina",
            keyEquivalent: "i",
            modifierFlags: ["command", "option"],
            isEnabled: false
        )
    ])
    defer { context.harness.cleanup() }

    let data = try context.editor.exportRecipeData()
    let decoded = try QuickeyRecipeCodec().decode(data)

    #expect(decoded.schemaVersion == QuickeyRecipe.currentSchemaVersion)
    #expect(decoded.shortcuts == [
        QuickeyRecipeShortcut(
            appName: "IINA",
            bundleIdentifier: "com.colliderli.iina",
            keyEquivalent: "i",
            modifierFlags: ["command", "option"],
            isEnabled: false
        )
    ])
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
    func requestIfNeeded(prompt: Bool, inputMonitoringRequired: Bool) -> Bool {
        ax && (!inputMonitoringRequired || input)
    }
}

@MainActor
private final class FakeCaptureProvider: ShortcutCaptureProvider {
    var isRunning = false

    var registrationState: ShortcutCaptureRegistrationState {
        ShortcutCaptureRegistrationState(
            desiredShortcutCount: isRunning ? 1 : 0,
            registeredShortcutCount: isRunning ? 1 : 0,
            failures: []
        )
    }

    func start(onKeyPress: @escaping @MainActor @Sendable (KeyPress) -> Void) {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func updateRegisteredShortcuts(_ keyPresses: Set<KeyPress>) {}
}

@MainActor
private final class FakeHyperCaptureProvider: HyperShortcutCaptureProvider {
    var isRunning = false

    var registrationState: ShortcutCaptureRegistrationState {
        ShortcutCaptureRegistrationState(
            desiredShortcutCount: isRunning ? 1 : 0,
            registeredShortcutCount: isRunning ? 1 : 0,
            failures: []
        )
    }

    func start(onKeyPress: @escaping @MainActor @Sendable (KeyPress) -> Void) {
        isRunning = true
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

private final class CallbackCounter: @unchecked Sendable {
    var value = 0
}

@MainActor
private func makeEditorContext(
    existingShortcuts: [AppShortcut] = [],
    appBundleLocator: AppBundleLocator = makeTestAppBundleLocator()
) -> (
    editor: ShortcutEditorState,
    manager: ShortcutManager,
    shortcutStore: ShortcutStore,
    harness: TestPersistenceHarness,
    callbackCount: CallbackCounter
) {
    let shortcutStore = ShortcutStore()
    shortcutStore.replaceAll(with: existingShortcuts)

    let harness = TestPersistenceHarness()
    let manager = ShortcutManager(
        shortcutStore: shortcutStore,
        persistenceService: harness.makePersistenceService(),
        appSwitcher: FakeAppSwitcher(),
        captureCoordinator: ShortcutCaptureCoordinator(
            standardProvider: FakeCaptureProvider(),
            hyperProvider: FakeHyperCaptureProvider()
        ),
        permissionService: FakePermissionService(ax: true, input: false),
        appBundleLocator: appBundleLocator,
        diagnosticClient: .live
    )

    if !existingShortcuts.isEmpty {
        manager.save(shortcuts: existingShortcuts)
    }

    let callbackCount = CallbackCounter()
    let editor = ShortcutEditorState(
        shortcutStore: shortcutStore,
        shortcutManager: manager,
        appBundleLocator: appBundleLocator,
        onShortcutConfigurationChange: {
            callbackCount.value += 1
        }
    )

    return (editor, manager, shortcutStore, harness, callbackCount)
}
