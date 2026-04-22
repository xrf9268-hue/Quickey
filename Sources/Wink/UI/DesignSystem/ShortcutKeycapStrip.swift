import SwiftUI

struct ShortcutKeycapStrip: View {
    let labels: [String]
    var size: WinkKeycap.Size = .small

    init(shortcut: AppShortcut, size: WinkKeycap.Size = .small) {
        self.labels = Self.labels(
            keyEquivalent: shortcut.keyEquivalent,
            modifierFlags: shortcut.modifierFlags
        )
        self.size = size
    }

    init(shortcut: RecordedShortcut, size: WinkKeycap.Size = .small) {
        self.labels = Self.labels(
            keyEquivalent: shortcut.keyEquivalent,
            modifierFlags: shortcut.modifierFlags
        )
        self.size = size
    }

    init(labels: [String], size: WinkKeycap.Size = .small) {
        self.labels = labels
        self.size = size
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(labels, id: \.self) { label in
                WinkKeycap(label, size: size)
            }
        }
    }

    nonisolated static func labels(keyEquivalent: String, modifierFlags: [String]) -> [String] {
        modifierFlags.map(symbol(for:)) + [keyLabel(for: keyEquivalent)]
    }

    nonisolated private static func symbol(for modifier: String) -> String {
        switch modifier {
        case "command": return "⌘"
        case "option": return "⌥"
        case "control": return "⌃"
        case "shift": return "⇧"
        case "function": return "fn"
        default: return modifier.uppercased()
        }
    }

    nonisolated private static func keyLabel(for keyEquivalent: String) -> String {
        keyEquivalent.count == 1 ? keyEquivalent.uppercased() : keyEquivalent
    }
}
