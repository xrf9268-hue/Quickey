import Foundation

struct ShortcutValidator {
    func conflict(for candidate: AppShortcut, in shortcuts: [AppShortcut]) -> ShortcutConflict? {
        guard let existing = shortcuts.first(where: {
            $0.id != candidate.id
            && $0.keyEquivalent.caseInsensitiveCompare(candidate.keyEquivalent) == .orderedSame
            && Set($0.modifierFlags.map { $0.lowercased() }) == Set(candidate.modifierFlags.map { $0.lowercased() })
        }) else {
            return nil
        }

        return ShortcutConflict(existingShortcut: existing, attemptedShortcut: candidate)
    }

    func normalizedKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
