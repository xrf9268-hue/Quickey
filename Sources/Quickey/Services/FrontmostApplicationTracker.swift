import AppKit
import os.log

private let logger = Logger(subsystem: DiagnosticLog.subsystem, category: "FrontmostTracker")

@MainActor
final class FrontmostApplicationTracker {
    private(set) var lastNonTargetBundleIdentifier: String?

    func currentFrontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func noteCurrentFrontmostApp(excluding targetBundleIdentifier: String) {
        guard let current = currentFrontmostBundleIdentifier(), current != targetBundleIdentifier else {
            return
        }
        lastNonTargetBundleIdentifier = current
    }

    /// Restore the previous app using SkyLight for reliable activation (consistent with AppSwitcher).
    @discardableResult
    func restorePreviousAppIfPossible() -> Bool {
        guard let bundleIdentifier = lastNonTargetBundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            lastNonTargetBundleIdentifier = nil
            return false
        }
        lastNonTargetBundleIdentifier = nil

        // Use SkyLight activation for consistency with AppSwitcher
        let pid = app.processIdentifier
        var psn = ProcessSerialNumber()
        let status = GetProcessForPID(pid, &psn)
        guard status == noErr else {
            logger.warning("restorePrevious: GetProcessForPID failed for \(bundleIdentifier), falling back")
            return app.activate()
        }
        let result = _SLPSSetFrontProcessWithOptions(&psn, 0, SLPSMode.userGenerated.rawValue)
        if result != .success {
            logger.warning("restorePrevious: SkyLight failed for \(bundleIdentifier), falling back")
            return app.activate()
        }
        return true
    }
}
