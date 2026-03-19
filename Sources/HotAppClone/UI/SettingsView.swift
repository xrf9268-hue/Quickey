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

            HStack {
                TextField("Bundle Identifier", text: $viewModel.selectedBundleIdentifier)
                TextField("Key", text: $viewModel.keyEquivalent)
                    .frame(width: 80)
                TextField("Modifiers (comma separated)", text: $viewModel.modifierFlagsText)
            }

            if let conflictMessage = viewModel.conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Add Shortcut") {
                viewModel.addShortcut()
            }
            .disabled(viewModel.selectedBundleIdentifier.isEmpty || viewModel.keyEquivalent.isEmpty)

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
