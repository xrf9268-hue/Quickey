import AppKit
import os.log

private let logger = Logger(subsystem: DiagnosticLog.subsystem, category: "FrontmostTracker")

@MainActor
final class FrontmostApplicationTracker {
    struct Client: Sendable {
        let currentFrontmostBundleIdentifier: @MainActor () -> String?
        let processIdentifierForRunningApplication: @MainActor (String) -> pid_t?
        let activateRunningApplication: @MainActor (String) -> Bool
        let setFrontProcess: @Sendable (pid_t) -> Bool
    }

    private(set) var lastNonTargetBundleIdentifier: String?
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
    }

    /// Restore the previous app using SkyLight for reliable activation (consistent with AppSwitcher).
    @discardableResult
    func restorePreviousAppIfPossible() -> Bool {
        guard let bundleIdentifier = lastNonTargetBundleIdentifier,
              let pid = client.processIdentifierForRunningApplication(bundleIdentifier) else {
            lastNonTargetBundleIdentifier = nil
            return false
        }
        lastNonTargetBundleIdentifier = nil

        if !client.setFrontProcess(pid) {
            logger.warning("restorePrevious: SkyLight failed for \(bundleIdentifier), falling back")
            return client.activateRunningApplication(bundleIdentifier)
        }
        return true
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
