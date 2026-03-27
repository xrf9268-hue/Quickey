import AppKit
import Carbon.HIToolbox

struct RestoreContext: Sendable {
    let targetBundleIdentifier: String
    let previousBundleIdentifier: String?
    let previousPID: pid_t?
    let previousPSNHint: ProcessSerialNumber?
    let previousWindowIDHint: CGWindowID?
    let previousBundleURL: URL?
    let capturedAt: CFAbsoluteTime
    let generation: Int
}
