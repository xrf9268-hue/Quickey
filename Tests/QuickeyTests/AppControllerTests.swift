import Testing
@testable import Quickey

@Test @MainActor
func startupSequenceAppliesPersistedHyperStateBeforeStartingShortcutManager() {
    var events: [String] = []

    AppController.runStartupSequence(
        loadShortcuts: {
            events.append("load")
            return []
        },
        replaceShortcuts: { _ in
            events.append("replace")
        },
        reapplyHyperIfNeeded: {
            events.append("reapplyHyper")
        },
        isHyperEnabled: {
            events.append("readHyperEnabled")
            return true
        },
        setHyperKeyEnabled: { enabled in
            events.append("setHyper:\(enabled)")
        },
        startShortcutManager: {
            events.append("startShortcutManager")
        },
        installMenuBar: {
            events.append("installMenuBar")
        },
        isFirstLaunch: {
            events.append("isFirstLaunch")
            return false
        },
        markFirstLaunchComplete: {
            events.append("markFirstLaunchComplete")
        },
        openSettings: {
            events.append("openSettings")
        }
    )

    #expect(events == [
        "load",
        "replace",
        "reapplyHyper",
        "readHyperEnabled",
        "setHyper:true",
        "startShortcutManager",
        "installMenuBar",
        "isFirstLaunch"
    ])
}

@Test @MainActor
func startupSequenceOpensSettingsAndMarksCompleteOnFirstLaunch() {
    var events: [String] = []

    AppController.runStartupSequence(
        loadShortcuts: { [] },
        replaceShortcuts: { _ in },
        reapplyHyperIfNeeded: {},
        isHyperEnabled: { false },
        setHyperKeyEnabled: { _ in },
        startShortcutManager: {},
        installMenuBar: {
            events.append("installMenuBar")
        },
        isFirstLaunch: { true },
        markFirstLaunchComplete: {
            events.append("markFirstLaunchComplete")
        },
        openSettings: {
            events.append("openSettings")
        }
    )

    #expect(events == [
        "installMenuBar",
        "openSettings",
        "markFirstLaunchComplete"
    ])
}

@Test @MainActor
func startupSequenceSkipsOpeningSettingsOnSubsequentLaunches() {
    var openedSettings = false
    var markedComplete = false

    AppController.runStartupSequence(
        loadShortcuts: { [] },
        replaceShortcuts: { _ in },
        reapplyHyperIfNeeded: {},
        isHyperEnabled: { false },
        setHyperKeyEnabled: { _ in },
        startShortcutManager: {},
        installMenuBar: {},
        isFirstLaunch: { false },
        markFirstLaunchComplete: {
            markedComplete = true
        },
        openSettings: {
            openedSettings = true
        }
    )

    #expect(openedSettings == false)
    #expect(markedComplete == false)
}
