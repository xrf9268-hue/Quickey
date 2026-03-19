import AppKit
import Carbon.HIToolbox

struct KeyMatcher {
    func matches(_ keyPress: EventTapManager.KeyPress, shortcut: AppShortcut) -> Bool {
        keyPress.keyCode == keyCode(for: shortcut.keyEquivalent)
            && normalizedModifiers(from: keyPress.modifiers) == normalizedModifiers(from: shortcut.modifierFlags)
    }

    private func keyCode(for keyEquivalent: String) -> CGKeyCode {
        switch keyEquivalent.lowercased() {
        case "a": return CGKeyCode(kVK_ANSI_A)
        case "b": return CGKeyCode(kVK_ANSI_B)
        case "c": return CGKeyCode(kVK_ANSI_C)
        case "d": return CGKeyCode(kVK_ANSI_D)
        case "e": return CGKeyCode(kVK_ANSI_E)
        case "f": return CGKeyCode(kVK_ANSI_F)
        case "g": return CGKeyCode(kVK_ANSI_G)
        case "h": return CGKeyCode(kVK_ANSI_H)
        case "i": return CGKeyCode(kVK_ANSI_I)
        case "j": return CGKeyCode(kVK_ANSI_J)
        case "k": return CGKeyCode(kVK_ANSI_K)
        case "l": return CGKeyCode(kVK_ANSI_L)
        case "m": return CGKeyCode(kVK_ANSI_M)
        case "n": return CGKeyCode(kVK_ANSI_N)
        case "o": return CGKeyCode(kVK_ANSI_O)
        case "p": return CGKeyCode(kVK_ANSI_P)
        case "q": return CGKeyCode(kVK_ANSI_Q)
        case "r": return CGKeyCode(kVK_ANSI_R)
        case "s": return CGKeyCode(kVK_ANSI_S)
        case "t": return CGKeyCode(kVK_ANSI_T)
        case "u": return CGKeyCode(kVK_ANSI_U)
        case "v": return CGKeyCode(kVK_ANSI_V)
        case "w": return CGKeyCode(kVK_ANSI_W)
        case "x": return CGKeyCode(kVK_ANSI_X)
        case "y": return CGKeyCode(kVK_ANSI_Y)
        case "z": return CGKeyCode(kVK_ANSI_Z)
        default: return CGKeyCode(UInt16.max)
        }
    }

    private func normalizedModifiers(from flags: NSEvent.ModifierFlags) -> Set<String> {
        var result: Set<String> = []
        if flags.contains(.command) { result.insert("command") }
        if flags.contains(.option) { result.insert("option") }
        if flags.contains(.control) { result.insert("control") }
        if flags.contains(.shift) { result.insert("shift") }
        return result
    }

    private func normalizedModifiers(from modifiers: [String]) -> Set<String> {
        Set(modifiers.map { $0.lowercased() })
    }
}
