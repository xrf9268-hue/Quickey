import AppKit
import Carbon.HIToolbox

struct RestoreContext: Sendable, Equatable {
    let targetBundleIdentifier: String
    let previousBundleIdentifier: String?
    let previousPID: pid_t?
    let previousPSNHint: ProcessSerialNumber?
    let previousWindowIDHint: CGWindowID?
    let previousBundleURL: URL?
    let capturedAt: CFAbsoluteTime
    let generation: Int

    static func == (lhs: RestoreContext, rhs: RestoreContext) -> Bool {
        lhs.targetBundleIdentifier == rhs.targetBundleIdentifier
            && lhs.previousBundleIdentifier == rhs.previousBundleIdentifier
            && lhs.previousPID == rhs.previousPID
            && lhs.previousPSNHint?.highLongOfPSN == rhs.previousPSNHint?.highLongOfPSN
            && lhs.previousPSNHint?.lowLongOfPSN == rhs.previousPSNHint?.lowLongOfPSN
            && lhs.previousWindowIDHint == rhs.previousWindowIDHint
            && lhs.previousBundleURL == rhs.previousBundleURL
            && lhs.capturedAt == rhs.capturedAt
            && lhs.generation == rhs.generation
    }
}
