import AppKit

enum ActivationCommand: Sendable {
    case prepareRestoreContext(targetBundleIdentifier: String, previousBundleIdentifier: String?)
    case restorePreviousFast(RestoreContext)
    case restorePreviousCompatible(RestoreContext)
    case hideTarget(bundleIdentifier: String, pid: pid_t)
    case raiseWindow(bundleIdentifier: String, pid: pid_t, windowID: CGWindowID)
}

enum ActivationCommandResult: Sendable, Equatable {
    case completed(String)
    case needsFallback(String)
    case degraded(String)
    case cancelledByNewerGeneration(Int)
}

struct ActivationTimeoutBudget: Sendable, Equatable {
    var prepareRestoreContext: TimeInterval = 0.04
    var restorePreviousFast: TimeInterval = 0.12
    var hideTarget: TimeInterval = 0.08
    var restorePreviousCompatible: TimeInterval = 0.18
    var raiseWindow: TimeInterval = 0.08
}
