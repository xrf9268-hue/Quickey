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
    let restored = tracker.restorePreviousAppIfPossible()

    #expect(restored == true)
    #expect(recorder.lookupBundleIdentifiers == ["com.apple.Terminal"])
    #expect(recorder.setFrontProcessPIDs == [42])
    #expect(recorder.activatedBundleIdentifiers == ["com.apple.Terminal"])
    #expect(tracker.lastNonTargetBundleIdentifier == nil)
}

private final class FrontmostTrackerRecorder: @unchecked Sendable {
    var lookupBundleIdentifiers: [String] = []
    var activatedBundleIdentifiers: [String] = []
    var setFrontProcessPIDs: [pid_t] = []
}
