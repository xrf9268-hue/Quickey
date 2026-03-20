import Foundation

// MARK: - Shared modifier helpers

private let hyperModifiers: Set<String> = ["command", "option", "control", "shift"]

func modifierSymbol(for modifier: String) -> String {
    switch modifier.lowercased() {
    case "command": return "⌘"
    case "option": return "⌥"
    case "control": return "⌃"
    case "shift": return "⇧"
    case "function": return "fn"
    default: return modifier
    }
}

func isHyperCombo(_ modifierFlags: [String]) -> Bool {
    Set(modifierFlags.map { $0.lowercased() }).isSuperset(of: hyperModifiers)
}

func modifierDisplayText(modifierFlags: [String], keyEquivalent: String) -> String {
    modifierFlags.map(modifierSymbol(for:)).joined() + keyEquivalent.uppercased()
}

// MARK: - RecordedShortcut

struct RecordedShortcut: Equatable {
    var keyEquivalent: String
    var modifierFlags: [String]

    var isHyper: Bool { isHyperCombo(modifierFlags) }
    var displayText: String { modifierDisplayText(modifierFlags: modifierFlags, keyEquivalent: keyEquivalent) }
}

// MARK: - AppShortcut display extensions

extension AppShortcut {
    var isHyper: Bool { isHyperCombo(modifierFlags) }
    var displayText: String { modifierDisplayText(modifierFlags: modifierFlags, keyEquivalent: keyEquivalent) }
}
