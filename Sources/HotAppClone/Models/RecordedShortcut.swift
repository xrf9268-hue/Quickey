import Foundation

struct RecordedShortcut: Equatable {
    var keyEquivalent: String
    var modifierFlags: [String]

    var displayText: String {
        let modifiers = modifierFlags.map(Self.symbol(for:)).joined()
        return modifiers + keyEquivalent.uppercased()
    }

    private static func symbol(for modifier: String) -> String {
        switch modifier.lowercased() {
        case "command": return "⌘"
        case "option": return "⌥"
        case "control": return "⌃"
        case "shift": return "⇧"
        case "function": return "fn"
        default: return modifier
        }
    }
}
