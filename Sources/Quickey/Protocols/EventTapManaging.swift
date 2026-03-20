import AppKit

@MainActor
protocol EventTapManaging {
    var isRunning: Bool { get }
    func start(onKeyPress: @escaping (KeyPress) -> Bool)
    func stop()
    func updateRegisteredShortcuts(_ keyPresses: Set<KeyPress>)
    func setHyperKeyEnabled(_ enabled: Bool)
}
