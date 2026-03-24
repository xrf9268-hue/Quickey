import AppKit
import os.log

private let logger = Logger(subsystem: DiagnosticLog.subsystem, category: "FrontmostTracker")

@MainActor
final class FrontmostApplicationTracker {
    struct PreviousAppRestoreAttempt: Sendable, Equatable {
        let bundleIdentifier: String?
        let restoreAccepted: Bool
    }

    struct Client: Sendable {
        let currentFrontmostBundleIdentifier: @MainActor () -> String?
        let processIdentifierForRunningApplication: @MainActor (String) -> pid_t?
        let activateRunningApplication: @MainActor (String) -> Bool
        let setFrontProcess: @Sendable (pid_t) -> Bool
    }

    private(set) var lastNonTargetBundleIdentifier: String?
    private(set) var lastRestoreAttempt: PreviousAppRestoreAttempt?
    private let client: Client

    init(client: Client = .live) {
        self.client = client
    }

    func currentFrontmostBundleIdentifier() -> String? {
        client.currentFrontmostBundleIdentifier()
    }

    func noteCurrentFrontmostApp(excluding targetBundleIdentifier: String) {
        guard let current = currentFrontmostBundleIdentifier(), current != targetBundleIdentifier else {
            return
        }
        lastNonTargetBundleIdentifier = current
        lastRestoreAttempt = nil
    }

    /// Restore the previous app using SkyLight for reliable activation (consistent with AppSwitcher).
    @discardableResult
    func restorePreviousAppIfPossible() -> PreviousAppRestoreAttempt {
        guard let bundleIdentifier = lastNonTargetBundleIdentifier else {
            let attempt = PreviousAppRestoreAttempt(bundleIdentifier: nil, restoreAccepted: false)
            lastRestoreAttempt = attempt
            return attempt
        }

        guard let pid = client.processIdentifierForRunningApplication(bundleIdentifier) else {
            let attempt = PreviousAppRestoreAttempt(bundleIdentifier: bundleIdentifier, restoreAccepted: false)
            lastRestoreAttempt = attempt
            return attempt
        }

        if !client.setFrontProcess(pid) {
            logger.warning("restorePrevious: SkyLight failed for \(bundleIdentifier), falling back")
            let attempt = PreviousAppRestoreAttempt(
                bundleIdentifier: bundleIdentifier,
                restoreAccepted: client.activateRunningApplication(bundleIdentifier)
            )
            lastRestoreAttempt = attempt
            return attempt
        }

        let attempt = PreviousAppRestoreAttempt(bundleIdentifier: bundleIdentifier, restoreAccepted: true)
        lastRestoreAttempt = attempt
        return attempt
    }

    func confirmRestoreAttempt() {
        guard let lastRestoreAttempt else { return }
        if lastRestoreAttempt.restoreAccepted {
            lastNonTargetBundleIdentifier = nil
        }
        self.lastRestoreAttempt = nil
    }

    func resetPreviousAppTracking() {
        lastNonTargetBundleIdentifier = nil
        lastRestoreAttempt = nil
    }
}

extension FrontmostApplicationTracker.Client {
    static let live = FrontmostApplicationTracker.Client(
        currentFrontmostBundleIdentifier: {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        processIdentifierForRunningApplication: { bundleIdentifier in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.processIdentifier
        },
        activateRunningApplication: { bundleIdentifier in
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
                return false
            }
            return app.activate()
        },
        setFrontProcess: { pid in
            var psn = ProcessSerialNumber()
            let status = GetProcessForPID(pid, &psn)
            guard status == noErr else {
                logger.warning("restorePrevious: GetProcessForPID failed for pid \(pid), falling back")
                return false
            }
            let result = _SLPSSetFrontProcessWithOptions(&psn, 0, SLPSMode.userGenerated.rawValue)
            if result != .success {
                logger.warning("restorePrevious: SkyLight failed for pid \(pid), falling back")
                return false
            }
            return true
        }
    )
}
