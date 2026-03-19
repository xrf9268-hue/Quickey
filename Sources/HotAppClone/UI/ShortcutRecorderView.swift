import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var recordedShortcut: RecordedShortcut?
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> RecorderField {
        let field = RecorderField()
        field.onCapture = { shortcut in
            recordedShortcut = shortcut
            isRecording = false
        }
        field.onRecordingChange = { recording in
            isRecording = recording
        }
        return field
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.placeholderString = isRecording ? "Press shortcut" : "Click to record shortcut"
        nsView.stringValue = recordedShortcut?.displayText ?? ""
    }
}

final class RecorderField: NSTextField {
    var onCapture: ((RecordedShortcut) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?
    private let keySymbolMapper = KeySymbolMapper()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isBordered = true
        isBezeled = true
        focusRingType = .default
        placeholderString = "Click to record shortcut"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onRecordingChange?(true)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = normalizedModifiers(from: event.modifierFlags)
        guard !modifiers.isEmpty,
              let keyEquivalent = keySymbolMapper.keyEquivalent(for: CGKeyCode(event.keyCode)) else {
            NSSound.beep()
            return
        }

        onCapture?(RecordedShortcut(keyEquivalent: keyEquivalent, modifierFlags: modifiers))
        stringValue = RecordedShortcut(keyEquivalent: keyEquivalent, modifierFlags: modifiers).displayText
    }

    private func normalizedModifiers(from flags: NSEvent.ModifierFlags) -> [String] {
        var result: [String] = []
        if flags.contains(.control) { result.append("control") }
        if flags.contains(.option) { result.append("option") }
        if flags.contains(.shift) { result.append("shift") }
        if flags.contains(.command) { result.append("command") }
        if flags.contains(.function) { result.append("function") }
        return result
    }
}
