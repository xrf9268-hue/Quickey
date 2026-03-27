import Foundation

enum ToggleExecutionMode: Sendable, Equatable {
    case legacyOnly
    case shadowMode
    case pipelineEnabled
}

struct ToggleRuntimeConfiguration: Sendable, Equatable {
    var executionMode: ToggleExecutionMode = .legacyOnly
    var fastConfirmationWindow: TimeInterval = 0.075
    var contextPreparationConcurrencyLimit: Int = 2
    var fastLaneMissThreshold: Int = 3
    var fastLaneMissWindow: TimeInterval = 600
    var temporaryCompatibilityWindow: TimeInterval = 300
}

@MainActor
final class ToggleRuntime {
    let configuration: ToggleRuntimeConfiguration

    init(configuration: ToggleRuntimeConfiguration = .init()) {
        self.configuration = configuration
    }
}

@MainActor
func normalizedPreviousBundle(
    targetBundleIdentifier: String,
    previousBundleIdentifier: String?
) -> String? {
    guard previousBundleIdentifier != targetBundleIdentifier else {
        return nil
    }
    return previousBundleIdentifier
}
