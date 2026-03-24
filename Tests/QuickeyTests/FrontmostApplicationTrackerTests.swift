import Darwin
import Testing
@testable import Quickey

@Test @MainActor
func noteCurrentFrontmostAppSkipsTargetBundleIdentifier() {
    let tracker = FrontmostApplicationTracker(client: .init(
        currentFrontmostBundleIdentifier: { "com.apple.Terminal" },
        processIdentifierForRunningApplication: { _ in nil },
        activateRunningApplication: { _ in false },
        setFrontProcess: { _ in false }
    ))

    tracker.noteCurrentFrontmostApp(excluding: "com.apple.Terminal")

    #expect(tracker.lastNonTargetBundleIdentifier == nil)
}

@Test @MainActor
func restorePreviousAppFallsBackToActivationWhenSkyLightFails() {
    let recorder = FrontmostTrackerRecorder()
    let tracker = FrontmostApplicationTracker(client: .init(
        currentFrontmostBundleIdentifier: { "com.apple.Terminal" },
        processIdentifierForRunningApplication: { bundleIdentifier in
            recorder.lookupBundleIdentifiers.append(bundleIdentifier)
            return 42
        },
        activateRunningApplication: { bundleIdentifier in
            recorder.activatedBundleIdentifiers.append(bundleIdentifier)
            return true
        },
        setFrontProcess: { pid in
            recorder.setFrontProcessPIDs.append(pid)
            return false
        }
    ))

    tracker.noteCurrentFrontmostApp(excluding: "com.apple.Safari")
    let restoreAttempt = tracker.restorePreviousAppIfPossible()

    #expect(restoreAttempt.bundleIdentifier == "com.apple.Terminal")
    #expect(restoreAttempt.restoreAccepted == true)
    #expect(recorder.lookupBundleIdentifiers == ["com.apple.Terminal"])
    #expect(recorder.setFrontProcessPIDs == [42])
    #expect(recorder.activatedBundleIdentifiers == ["com.apple.Terminal"])
    #expect(tracker.lastNonTargetBundleIdentifier == "com.apple.Terminal")

    tracker.confirmRestoreAttempt()

    #expect(tracker.lastNonTargetBundleIdentifier == nil)
}

@Test @MainActor
func restoreAttemptDoesNotDiscardPreviousBundleBeforeConfirmation() {
    let tracker = FrontmostApplicationTracker(client: .init(
        currentFrontmostBundleIdentifier: { "com.apple.Terminal" },
        processIdentifierForRunningApplication: { _ in 42 },
        activateRunningApplication: { _ in true },
        setFrontProcess: { _ in true }
    ))

    tracker.noteCurrentFrontmostApp(excluding: "com.apple.Safari")
    let restoreAttempt = tracker.restorePreviousAppIfPossible()

    #expect(restoreAttempt.bundleIdentifier == "com.apple.Terminal")
    #expect(restoreAttempt.restoreAccepted == true)
    #expect(tracker.lastNonTargetBundleIdentifier == "com.apple.Terminal")
}

@Test @MainActor
func resetPreviousBundleAllowsFreshActivationToCaptureNewFrontmostApp() {
    let frontmostState = MutableFrontmostState(bundleIdentifier: "com.apple.Terminal")
    let tracker = FrontmostApplicationTracker(client: .init(
        currentFrontmostBundleIdentifier: { frontmostState.bundleIdentifier },
        processIdentifierForRunningApplication: { _ in 42 },
        activateRunningApplication: { _ in true },
        setFrontProcess: { _ in true }
    ))

    tracker.noteCurrentFrontmostApp(excluding: "com.apple.Safari")
    _ = tracker.restorePreviousAppIfPossible()

    frontmostState.bundleIdentifier = "com.openai.codex"
    tracker.resetPreviousAppTracking()
    tracker.noteCurrentFrontmostApp(excluding: "com.apple.Safari")

    #expect(tracker.lastNonTargetBundleIdentifier == "com.openai.codex")
}

private final class FrontmostTrackerRecorder: @unchecked Sendable {
    var lookupBundleIdentifiers: [String] = []
    var activatedBundleIdentifiers: [String] = []
    var setFrontProcessPIDs: [pid_t] = []
}

private final class MutableFrontmostState: @unchecked Sendable {
    var bundleIdentifier: String

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }
}
