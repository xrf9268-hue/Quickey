import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Shortcuts")
                .font(.title2)
                .bold()

            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.accessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(viewModel.accessibilityGranted ? "Accessibility granted" : "Accessibility required for global shortcuts")
                    .foregroundStyle(.secondary)
                Button("Refresh") {
                    viewModel.refreshPermissions()
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button("Choose App") {
                    viewModel.chooseApplication()
                }
                if !viewModel.selectedBundleIdentifier.isEmpty {
                    Button("Reveal App") {
                        viewModel.revealApplication()
                    }
                }
                Text(viewModel.selectedAppName.isEmpty ? "No app selected" : viewModel.selectedAppName)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Bundle Identifier", text: $viewModel.selectedBundleIdentifier)

                HStack(spacing: 12) {
                    ShortcutRecorderView(
                        recordedShortcut: $viewModel.recordedShortcut,
                        isRecording: $viewModel.isRecordingShortcut
                    )
                    .frame(width: 240, height: 28)

                    if let recordedShortcut = viewModel.recordedShortcut {
                        Text(recordedShortcut.displayText)
                            .font(.system(.body, design: .monospaced))
                    } else if viewModel.isRecordingShortcut {
                        Text("Listening…")
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear") {
                        viewModel.clearRecordedShortcut()
                    }
                    .disabled(viewModel.recordedShortcut == nil && !viewModel.isRecordingShortcut)
                }
            }

            if let conflictMessage = viewModel.conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Add Shortcut") {
                viewModel.addShortcut()
            }
            .disabled(viewModel.selectedBundleIdentifier.isEmpty || viewModel.recordedShortcut == nil)

            List {
                ForEach(viewModel.shortcuts) { shortcut in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(shortcut.appName)
                            Text(shortcut.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(shortcut.modifierFlags.joined(separator: "+") + "+" + shortcut.keyEquivalent.uppercased())
                            .font(.system(.body, design: .monospaced))
                        Button(role: .destructive) {
                            viewModel.removeShortcut(id: shortcut.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 420)
    }
}
