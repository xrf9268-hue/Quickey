import SwiftUI

struct GeneralTabView: View {
    var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Launch at Login", isOn: Binding(
                get: { preferences.launchAtLoginEnabled },
                set: { preferences.setLaunchAtLogin($0) }
            ))

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Enable Hyper Key (Caps Lock → ⌃⌥⇧⌘)", isOn: Binding(
                    get: { preferences.hyperKeyEnabled },
                    set: { preferences.setHyperKeyEnabled($0) }
                ))
                Text("将 Caps Lock 映射为 Hyper Key。按住 Caps Lock 再按其他键，等同于 ⌃⌥⇧⌘ 组合。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Text("Quickey v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }
}
