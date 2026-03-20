import SwiftUI

struct ShortcutsTabView: View {
    @Bindable var editor: ShortcutEditorState
    var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(preferences.shortcutCaptureStatus.ready ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(captureStatusText(for: preferences.shortcutCaptureStatus))
                        .foregroundStyle(.secondary)
                    Button("Refresh") {
                        preferences.refreshPermissions()
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    PermissionBadge(title: "Accessibility", granted: preferences.shortcutCaptureStatus.accessibilityGranted)
                    PermissionBadge(title: "Input Monitoring", granted: preferences.shortcutCaptureStatus.inputMonitoringGranted)
                    PermissionBadge(title: "Event Tap", granted: preferences.shortcutCaptureStatus.eventTapActive)
                    Spacer()
                }
            }

            HStack(spacing: 12) {
                Button("Choose App") {
                    editor.chooseApplication()
                }
                if !editor.selectedBundleIdentifier.isEmpty {
                    Button("Reveal App") {
                        editor.revealApplication()
                    }
                }
                Text(editor.selectedAppName.isEmpty ? "No app selected" : editor.selectedAppName)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Bundle Identifier", text: $editor.selectedBundleIdentifier)

                HStack(spacing: 12) {
                    ShortcutRecorderView(
                        recordedShortcut: $editor.recordedShortcut,
                        isRecording: $editor.isRecordingShortcut
                    )
                    .frame(width: 240, height: 28)

                    if let recordedShortcut = editor.recordedShortcut {
                        ShortcutLabel(displayText: recordedShortcut.displayText, isHyper: recordedShortcut.isHyper)
                    } else if editor.isRecordingShortcut {
                        Text("Listening…")
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear") {
                        editor.clearRecordedShortcut()
                    }
                    .disabled(editor.recordedShortcut == nil && !editor.isRecordingShortcut)
                }
            }

            if let conflictMessage = editor.conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Add Shortcut") {
                editor.addShortcut()
            }
            .disabled(editor.selectedBundleIdentifier.isEmpty || editor.recordedShortcut == nil)

            List {
                ForEach(editor.shortcuts) { shortcut in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(shortcut.appName)
                            Text(shortcut.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(editor.usageCounts[shortcut.id, default: 0])× past 7 days")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        ShortcutLabel(displayText: shortcut.displayText, isHyper: shortcut.isHyper)
                        Button(role: .destructive) {
                            editor.removeShortcut(id: shortcut.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}
