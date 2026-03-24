import AppKit
import ApplicationServices
import Testing
@testable import Quickey

@Test @MainActor
func activateProcessFallsBackWhenProcessLookupFails() {
    let switcher = AppSwitcher(
        frontmostTracker: makeTrackerForAppSwitcherTests(),
        activationClient: .init(activateFrontProcess: { _, _ in
            .processLookupFailed(-600)
        })
    )
    var fallbackCallCount = 0

    let result = switcher.activateProcess(pid: 42, windowID: 11) {
        fallbackCallCount += 1
        return true
    }

    if case .fallback(let activated) = result {
        #expect(activated == true)
    } else {
        Issue.record("Expected fallback activation when process lookup fails")
    }
    #expect(fallbackCallCount == 1)
}

@Test @MainActor
func activateProcessFallsBackWhenSkyLightActivationFails() {
    let switcher = AppSwitcher(
        frontmostTracker: makeTrackerForAppSwitcherTests(),
        activationClient: .init(activateFrontProcess: { _, _ in
            .activationFailed(.failure)
        })
    )
    var fallbackCallCount = 0

    let result = switcher.activateProcess(pid: 42, windowID: 11) {
        fallbackCallCount += 1
        return false
    }

    if case .fallback(let activated) = result {
        #expect(activated == false)
    } else {
        Issue.record("Expected fallback activation when SkyLight activation fails")
    }
    #expect(fallbackCallCount == 1)
}

@Test @MainActor
func activateProcessReturnsSkyLightResultWhenActivationSucceeds() {
    var psn = ProcessSerialNumber()
    psn.highLongOfPSN = 1
    psn.lowLongOfPSN = 2
    let switcher = AppSwitcher(
        frontmostTracker: makeTrackerForAppSwitcherTests(),
        activationClient: .init(activateFrontProcess: { _, _ in
            .success(psn)
        })
    )
    var fallbackCallCount = 0

    let result = switcher.activateProcess(pid: 42, windowID: nil) {
        fallbackCallCount += 1
        return false
    }

    if case .skyLight(let receivedPSN) = result {
        #expect(receivedPSN.highLongOfPSN == 1)
        #expect(receivedPSN.lowLongOfPSN == 2)
    } else {
        Issue.record("Expected SkyLight activation result")
    }
    #expect(fallbackCallCount == 0)
}

@Test @MainActor
func requestFallbackActivationReopensApplicationViaWorkspaceWhenBundleURLExists() {
    let recorder = FallbackActivationRecorder()
    let bundleURL = URL(fileURLWithPath: "/Applications/Terminal.app")
    let switcher = AppSwitcher(
        frontmostTracker: makeTrackerForAppSwitcherTests(),
        fallbackActivationClient: .init(openApplication: { url, configuration, completion in
            recorder.openedURLs.append(url)
            recorder.activatesFlags.append(configuration.activates)
            completion(nil)
        })
    )
    var plainActivateCalls = 0

    let result = switcher.requestFallbackActivation(
        bundleURL: bundleURL,
        bundleIdentifier: "com.apple.Terminal"
    ) {
        plainActivateCalls += 1
        return false
    }

    #expect(result == true)
    #expect(recorder.openedURLs == [bundleURL])
    #expect(recorder.activatesFlags == [true])
    #expect(plainActivateCalls == 0)
}

@Test @MainActor
func requestFallbackActivationUsesPlainActivationWhenBundleURLIsMissing() {
    let recorder = FallbackActivationRecorder()
    let switcher = AppSwitcher(
        frontmostTracker: makeTrackerForAppSwitcherTests(),
        fallbackActivationClient: .init(openApplication: { url, configuration, completion in
            recorder.openedURLs.append(url)
            recorder.activatesFlags.append(configuration.activates)
            completion(nil)
        })
    )
    var plainActivateCalls = 0

    let result = switcher.requestFallbackActivation(
        bundleURL: nil,
        bundleIdentifier: "com.apple.Terminal"
    ) {
        plainActivateCalls += 1
        return true
    }

    #expect(result == true)
    #expect(recorder.openedURLs.isEmpty)
    #expect(plainActivateCalls == 1)
}

@Test
func togglePostActionStateLogDetailsIncludesFrontmostAndTargetFlags() {
    let state = TogglePostActionState(
        frontmostBundleIdentifier: "com.openai.codex",
        targetBundleIdentifier: "com.apple.Safari",
        targetFrontmost: false,
        targetHidden: true,
        targetVisibleWindows: false
    )

    #expect(
        state.logDetails ==
        "postFrontmost=com.openai.codex, targetBundle=com.apple.Safari, targetFrontmost=false, targetHidden=true, targetVisibleWindows=false"
    )
}

@Test @MainActor
func postActionLogMessageUsesObservationSnapshotForFrontmostState() {
    let switcher = AppSwitcher(frontmostTracker: makeTrackerForAppSwitcherTests())
    let shortcut = AppShortcut(
        appName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        keyEquivalent: "s",
        modifierFlags: ["command"]
    )
    let snapshot = ActivationObservationSnapshot(
        targetBundleIdentifier: "com.apple.Safari",
        observedFrontmostBundleIdentifier: "com.openai.codex",
        targetIsActive: true,
        targetIsHidden: false,
        visibleWindowCount: 1,
        hasFocusedWindow: false,
        hasMainWindow: true,
        windowObservationSucceeded: true,
        windowObservationFailureReason: nil,
        classification: .regularWindowed,
        classificationReason: "visible window but frontmost mismatch"
    )

    let message = switcher.postActionLogMessage(
        for: shortcut,
        phase: "POST_ACTIVATE_STATE",
        snapshot: snapshot
    )

    #expect(message.contains("postFrontmost=com.openai.codex"))
    #expect(message.contains("targetFrontmost=false"))
}

@Test @MainActor
func toggleLifecycleLogMessageIncludesStructuredObservationFields() {
    let switcher = AppSwitcher(frontmostTracker: makeTrackerForAppSwitcherTests())
    let shortcut = AppShortcut(
        appName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        keyEquivalent: "s",
        modifierFlags: ["command"]
    )
    let snapshot = ActivationObservationSnapshot(
        targetBundleIdentifier: "com.apple.Safari",
        observedFrontmostBundleIdentifier: "com.openai.codex",
        targetIsActive: true,
        targetIsHidden: false,
        visibleWindowCount: 1,
        hasFocusedWindow: false,
        hasMainWindow: true,
        windowObservationSucceeded: true,
        windowObservationFailureReason: nil,
        classification: .regularWindowed,
        classificationReason: "visible window but frontmost mismatch"
    )

    let message = switcher.toggleLifecycleLogMessage(
        for: shortcut,
        lifecycle: "TOGGLE_CONFIRMATION",
        previousBundle: "com.openai.codex",
        activationPath: "activate",
        snapshot: snapshot,
        elapsedMilliseconds: 75
    )

    #expect(message.contains("TOGGLE_CONFIRMATION"))
    #expect(message.contains("previous=com.openai.codex"))
    #expect(message.contains("activationPath=activate"))
    #expect(message.contains("elapsedMs=75"))
    #expect(message.contains("classification=\"regularWindowed\""))
}

@MainActor
private func makeTrackerForAppSwitcherTests() -> FrontmostApplicationTracker {
    FrontmostApplicationTracker(client: .init(
        currentFrontmostBundleIdentifier: { nil },
        processIdentifierForRunningApplication: { _ in nil },
        activateRunningApplication: { _ in false },
        setFrontProcess: { _ in false }
    ))
}

private final class FallbackActivationRecorder: @unchecked Sendable {
    var openedURLs: [URL] = []
    var activatesFlags: [Bool] = []
}
