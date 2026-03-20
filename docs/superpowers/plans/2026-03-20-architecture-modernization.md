# Architecture Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize Quickey's UI layer with @Observable, split SettingsViewModel into focused classes, and extract protocols for testability.

**Architecture:** Three-phase refactor: (1) extract KeyPress as standalone type and add protocols for AppSwitcher/EventTapManager, (2) migrate ViewModels to @Observable, (3) split SettingsViewModel into ShortcutEditorState + AppPreferences. Protocols use `any` to avoid generic propagation.

**Tech Stack:** Swift 6, macOS 14+, SPM, @Observable macro, AppKit + SwiftUI hybrid

**Spec:** `docs/superpowers/specs/2026-03-20-architecture-modernization-design.md`

---

### Task 1: Extract KeyPress as standalone type

**Files:**
- Create: `Sources/Quickey/Models/KeyPress.swift`
- Modify: `Sources/Quickey/Services/EventTapManager.swift`
- Modify: `Sources/Quickey/Services/KeyMatcher.swift`
- Modify: `Sources/Quickey/Services/ShortcutManager.swift`
- Modify: `Tests/QuickeyTests/QuickeyTests.swift`

- [ ] **Step 1: Create `Models/KeyPress.swift`**

```swift
import AppKit

struct KeyPress: Equatable, Hashable, Sendable {
    let keyCode: CGKeyCode
    let modifiers: NSEvent.ModifierFlags

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers.rawValue)
    }
}
```

- [ ] **Step 2: Remove nested KeyPress from EventTapManager**

In `Sources/Quickey/Services/EventTapManager.swift`:
- Delete the nested `struct KeyPress` definition (lines 13-16)
- Delete the `extension EventTapManager.KeyPress: Hashable` block (lines 253-260)
- Change the `typealias ShortcutHandler` from `(KeyPress) -> Bool` to `(Quickey.KeyPress) -> Bool` (only if disambiguation is needed; otherwise just `(KeyPress) -> Bool`)
- All internal references to `KeyPress` in EventTapManager already resolve to the new top-level type without changes

- [ ] **Step 3: Update EventTapBox references**

In the same file, `EventTapBox` class:
- Change `_registeredShortcuts: Set<EventTapManager.KeyPress>` to `Set<KeyPress>`
- Change `registeredShortcuts` computed property types to `Set<KeyPress>`
- Change `onKeyPress` closure type from `((EventTapManager.KeyPress) -> Void)?` to `((KeyPress) -> Void)?`

- [ ] **Step 4: Update KeyMatcher references**

In `Sources/Quickey/Services/KeyMatcher.swift`:
- Change `func matches(_ keyPress: EventTapManager.KeyPress, ...)` to `func matches(_ keyPress: KeyPress, ...)`
- Change `func trigger(for keyPress: EventTapManager.KeyPress)` to `func trigger(for keyPress: KeyPress)`

- [ ] **Step 5: Update ShortcutManager references**

In `Sources/Quickey/Services/ShortcutManager.swift` (3 occurrences):
- Change `Set<EventTapManager.KeyPress>` to `Set<KeyPress>` in `syncRegisteredShortcuts()`
- Change `EventTapManager.KeyPress(keyCode:modifiers:)` to `KeyPress(keyCode:modifiers:)` in the same method
- Change `private func handleKeyPress(_ keyPress: EventTapManager.KeyPress) -> Bool` to `private func handleKeyPress(_ keyPress: KeyPress) -> Bool`

- [ ] **Step 6: Update test references**

In `Tests/QuickeyTests/QuickeyTests.swift`:
- Replace all `EventTapManager.KeyPress(` with `KeyPress(` (16 occurrences)
- Replace all `Set<EventTapManager.KeyPress>` with `Set<KeyPress>` (1 occurrence)

- [ ] **Step 7: Build and test**

Run: `swift build && swift test`
Expected: All compile, all tests pass. Zero behavior change.

- [ ] **Step 8: Commit**

```bash
git add Sources/Quickey/Models/KeyPress.swift \
  Sources/Quickey/Services/EventTapManager.swift \
  Sources/Quickey/Services/KeyMatcher.swift \
  Sources/Quickey/Services/ShortcutManager.swift \
  Tests/QuickeyTests/QuickeyTests.swift
git commit -m "Extract KeyPress as standalone type for protocol decoupling"
```

---

### Task 2: Add AppSwitching and EventTapManaging protocols

**Files:**
- Create: `Sources/Quickey/Protocols/AppSwitching.swift`
- Create: `Sources/Quickey/Protocols/EventTapManaging.swift`
- Modify: `Sources/Quickey/Services/AppSwitcher.swift`
- Modify: `Sources/Quickey/Services/EventTapManager.swift`
- Modify: `Sources/Quickey/Services/ShortcutManager.swift`

- [ ] **Step 1: Create `Protocols/AppSwitching.swift`**

```swift
import Foundation

@MainActor
protocol AppSwitching {
    @discardableResult
    func toggleApplication(for shortcut: AppShortcut) -> Bool
}
```

- [ ] **Step 2: Create `Protocols/EventTapManaging.swift`**

```swift
import AppKit

@MainActor
protocol EventTapManaging {
    var isRunning: Bool { get }
    func start(onKeyPress: @escaping (KeyPress) -> Bool)
    func stop()
    func updateRegisteredShortcuts(_ keyPresses: Set<KeyPress>)
    func setHyperKeyEnabled(_ enabled: Bool)
}
```

- [ ] **Step 3: Conform AppSwitcher to AppSwitching**

In `Sources/Quickey/Services/AppSwitcher.swift`, change:
```swift
final class AppSwitcher {
```
to:
```swift
final class AppSwitcher: AppSwitching {
```

No other changes needed -- `toggleApplication(for:)` already matches the protocol signature.

- [ ] **Step 4: Conform EventTapManager to EventTapManaging**

In `Sources/Quickey/Services/EventTapManager.swift`, change:
```swift
final class EventTapManager {
```
to:
```swift
final class EventTapManager: EventTapManaging {
```

The existing `ShortcutHandler` typealias must stay (used internally by `onKeyPress`), but it now aligns with the protocol's `start(onKeyPress:)` signature since both use `(KeyPress) -> Bool`.

- [ ] **Step 5: Update ShortcutManager to use `any` protocol types**

In `Sources/Quickey/Services/ShortcutManager.swift`:

Change stored properties:
```swift
// Before
private let appSwitcher: AppSwitcher
private let eventTapManager: EventTapManager

// After
private let appSwitcher: any AppSwitching
private let eventTapManager: any EventTapManaging
```

Change init signature:
```swift
// Before
init(
    shortcutStore: ShortcutStore,
    persistenceService: PersistenceService,
    appSwitcher: AppSwitcher,
    eventTapManager: EventTapManager = EventTapManager(),
    permissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
    usageTracker: UsageTracker? = nil
)

// After
init(
    shortcutStore: ShortcutStore,
    persistenceService: PersistenceService,
    appSwitcher: any AppSwitching,
    eventTapManager: any EventTapManaging = EventTapManager(),
    permissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
    usageTracker: UsageTracker? = nil
)
```

- [ ] **Step 6: Build and test**

Run: `swift build && swift test`
Expected: All compile, all tests pass. Zero behavior change.

- [ ] **Step 7: Commit**

```bash
git add Sources/Quickey/Protocols/AppSwitching.swift \
  Sources/Quickey/Protocols/EventTapManaging.swift \
  Sources/Quickey/Services/AppSwitcher.swift \
  Sources/Quickey/Services/EventTapManager.swift \
  Sources/Quickey/Services/ShortcutManager.swift
git commit -m "Add AppSwitching and EventTapManaging protocols for testability"
```

---

### Task 3: Migrate InsightsViewModel to @Observable

Start with InsightsViewModel because it's simpler (46 lines, no permission polling, no complex bindings).

**Files:**
- Modify: `Sources/Quickey/UI/InsightsViewModel.swift`
- Modify: `Sources/Quickey/UI/InsightsTabView.swift`

- [ ] **Step 1: Migrate InsightsViewModel**

In `Sources/Quickey/UI/InsightsViewModel.swift`:

Change class declaration:
```swift
// Before
@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var period: InsightsPeriod = .week {

// After
import Observation

@MainActor
@Observable
final class InsightsViewModel {
    var period: InsightsPeriod = .week {
```

Remove `@Published` from all three remaining properties:
```swift
// Before
    @Published var totalCount: Int = 0
    @Published var bars: [DailyBar] = []
    @Published var ranking: [RankedShortcut] = []

// After
    var totalCount: Int = 0
    var bars: [DailyBar] = []
    var ranking: [RankedShortcut] = []
```

- [ ] **Step 2: Update InsightsTabView**

In `Sources/Quickey/UI/InsightsTabView.swift`:

Change property declaration (needs `@Bindable` because `$viewModel.period` is used in Picker binding):
```swift
// Before
    @ObservedObject var viewModel: InsightsViewModel

// After
    @Bindable var viewModel: InsightsViewModel
```

- [ ] **Step 3: Build and test**

Run: `swift build && swift test`
Expected: All compile, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Quickey/UI/InsightsViewModel.swift \
  Sources/Quickey/UI/InsightsTabView.swift
git commit -m "Migrate InsightsViewModel to @Observable"
```

---

### Task 4: Migrate SettingsViewModel to @Observable

**Files:**
- Modify: `Sources/Quickey/UI/SettingsViewModel.swift`
- Modify: `Sources/Quickey/UI/SettingsView.swift`
- Modify: `Sources/Quickey/UI/ShortcutsTabView.swift`
- Modify: `Sources/Quickey/UI/GeneralTabView.swift`

- [ ] **Step 1: Migrate SettingsViewModel class declaration**

In `Sources/Quickey/UI/SettingsViewModel.swift`:

```swift
// Before
import AppKit
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {

// After
import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
```

- [ ] **Step 2: Remove all @Published annotations**

Remove `@Published` from all 10 properties:
```swift
// Before
    @Published var shortcuts: [AppShortcut] = []
    @Published var selectedAppName: String = ""
    @Published var selectedBundleIdentifier: String = ""
    @Published var recordedShortcut: RecordedShortcut?
    @Published var isRecordingShortcut: Bool = false
    @Published var accessibilityGranted: Bool = false
    @Published var conflictMessage: String?
    @Published var launchAtLoginEnabled: Bool = false
    @Published var hyperKeyEnabled: Bool = false
    @Published var usageCounts: [UUID: Int] = [:]

// After (just remove @Published from each line)
    var shortcuts: [AppShortcut] = []
    var selectedAppName: String = ""
    var selectedBundleIdentifier: String = ""
    var recordedShortcut: RecordedShortcut?
    var isRecordingShortcut: Bool = false
    var accessibilityGranted: Bool = false
    var conflictMessage: String?
    var launchAtLoginEnabled: Bool = false
    var hyperKeyEnabled: Bool = false
    var usageCounts: [UUID: Int] = [:]
```

- [ ] **Step 3: Update SettingsView**

In `Sources/Quickey/UI/SettingsView.swift`:

```swift
// Before
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var insightsViewModel: InsightsViewModel

// After
    var viewModel: SettingsViewModel
    var insightsViewModel: InsightsViewModel
```

No `@Bindable` needed here -- SettingsView itself doesn't use `$viewModel.xxx` bindings (it passes viewModel to child views, and `$selectedTab` is `@State`).

- [ ] **Step 4: Update ShortcutsTabView**

In `Sources/Quickey/UI/ShortcutsTabView.swift`:

```swift
// Before
    @ObservedObject var viewModel: SettingsViewModel

// After
    @Bindable var viewModel: SettingsViewModel
```

`@Bindable` is required because this view uses `$viewModel.recordedShortcut` and `$viewModel.isRecordingShortcut` in `ShortcutRecorderView`.

- [ ] **Step 5: Update GeneralTabView**

In `Sources/Quickey/UI/GeneralTabView.swift`:

```swift
// Before
    @ObservedObject var viewModel: SettingsViewModel

// After
    var viewModel: SettingsViewModel
```

No `@Bindable` needed -- GeneralTabView uses manual `Binding(get:set:)` with side-effect setters, not `$viewModel.xxx`.

- [ ] **Step 6: Build and test**

Run: `swift build && swift test`
Expected: All compile, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Quickey/UI/SettingsViewModel.swift \
  Sources/Quickey/UI/SettingsView.swift \
  Sources/Quickey/UI/ShortcutsTabView.swift \
  Sources/Quickey/UI/GeneralTabView.swift
git commit -m "Migrate SettingsViewModel to @Observable"
```

---

### Task 5: Create ShortcutEditorState

Extract shortcut editing logic from SettingsViewModel into a focused class.

**Files:**
- Create: `Sources/Quickey/Services/ShortcutEditorState.swift`

- [ ] **Step 1: Create `Services/ShortcutEditorState.swift`**

```swift
import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ShortcutEditorState {
    var shortcuts: [AppShortcut] = []
    var selectedAppName: String = ""
    var selectedBundleIdentifier: String = ""
    var recordedShortcut: RecordedShortcut?
    var isRecordingShortcut: Bool = false
    var conflictMessage: String?
    var usageCounts: [UUID: Int] = [:]

    private let shortcutStore: ShortcutStore
    private let shortcutManager: ShortcutManager
    private let usageTracker: UsageTracker?
    private let appBundleLocator = AppBundleLocator()
    private let shortcutValidator = ShortcutValidator()

    init(shortcutStore: ShortcutStore, shortcutManager: ShortcutManager, usageTracker: UsageTracker? = nil) {
        self.shortcutStore = shortcutStore
        self.shortcutManager = shortcutManager
        self.usageTracker = usageTracker
        self.shortcuts = shortcutStore.shortcuts
        Task { await refreshUsageCounts() }
    }

    func addShortcut() {
        guard !selectedAppName.isEmpty,
              !selectedBundleIdentifier.isEmpty,
              let recordedShortcut else {
            return
        }

        let candidate = AppShortcut(
            appName: selectedAppName,
            bundleIdentifier: selectedBundleIdentifier,
            keyEquivalent: recordedShortcut.keyEquivalent,
            modifierFlags: recordedShortcut.modifierFlags
        )

        if let conflict = shortcutValidator.conflict(for: candidate, in: shortcuts) {
            conflictMessage = "Conflict: \(conflict.existingShortcut.appName) already uses \(conflict.existingShortcut.modifierFlags.joined(separator: "+"))+\(conflict.existingShortcut.keyEquivalent.uppercased())"
            return
        }

        var updated = shortcuts
        updated.append(candidate)
        shortcuts = updated
        shortcutManager.save(shortcuts: updated)
        conflictMessage = nil
        resetDraft()
        Task { await refreshUsageCounts() }
    }

    func removeShortcut(id: UUID) {
        let updated = shortcuts.filter { $0.id != id }
        shortcuts = updated
        shortcutManager.save(shortcuts: updated)
        if let usageTracker {
            Task {
                await usageTracker.deleteUsage(shortcutId: id)
                await refreshUsageCounts()
            }
        }
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return
        }

        selectedAppName = url.deletingPathExtension().lastPathComponent
        selectedBundleIdentifier = bundleIdentifier
    }

    func revealApplication() {
        guard let url = appBundleLocator.applicationURL(for: selectedBundleIdentifier) else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func clearRecordedShortcut() {
        recordedShortcut = nil
        isRecordingShortcut = false
    }

    func refreshUsageCounts() async {
        guard let usageTracker else { return }
        usageCounts = await usageTracker.usageCounts(days: 7)
    }

    private func resetDraft() {
        selectedAppName = ""
        selectedBundleIdentifier = ""
        recordedShortcut = nil
        isRecordingShortcut = false
    }
}
```

- [ ] **Step 2: Build to verify the new file compiles**

Run: `swift build`
Expected: Compiles (ShortcutEditorState is not yet used anywhere).

- [ ] **Step 3: Commit**

```bash
git add Sources/Quickey/Services/ShortcutEditorState.swift
git commit -m "Add ShortcutEditorState: extract shortcut editing from SettingsViewModel"
```

---

### Task 6: Create AppPreferences

Extract preference/permission logic from SettingsViewModel into a focused class.

**Files:**
- Create: `Sources/Quickey/Services/AppPreferences.swift`

- [ ] **Step 1: Create `Services/AppPreferences.swift`**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
    private(set) var accessibilityGranted: Bool = false
    var launchAtLoginEnabled: Bool = false
    var hyperKeyEnabled: Bool = false

    private let shortcutManager: ShortcutManager
    private let hyperKeyService: HyperKeyService?
    private let launchAtLoginService = LaunchAtLoginService()

    init(shortcutManager: ShortcutManager, hyperKeyService: HyperKeyService? = nil) {
        self.shortcutManager = shortcutManager
        self.hyperKeyService = hyperKeyService
        self.accessibilityGranted = shortcutManager.hasAccessibilityAccess()
        self.launchAtLoginEnabled = launchAtLoginService.isEnabled
        self.hyperKeyEnabled = hyperKeyService?.isEnabled ?? false
    }

    func refreshPermissions() {
        accessibilityGranted = shortcutManager.hasAccessibilityAccess()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginService.setEnabled(enabled)
        launchAtLoginEnabled = launchAtLoginService.isEnabled
    }

    func setHyperKeyEnabled(_ enabled: Bool) {
        guard let hyperKeyService else { return }
        if enabled {
            hyperKeyService.enable()
        } else {
            hyperKeyService.disable()
        }
        hyperKeyEnabled = hyperKeyService.isEnabled
        shortcutManager.setHyperKeyEnabled(hyperKeyEnabled)
    }
}
```

- [ ] **Step 2: Build to verify the new file compiles**

Run: `swift build`
Expected: Compiles (AppPreferences is not yet used anywhere).

- [ ] **Step 3: Commit**

```bash
git add Sources/Quickey/Services/AppPreferences.swift
git commit -m "Add AppPreferences: extract preferences from SettingsViewModel"
```

---

### Task 7: Wire up new classes and remove SettingsViewModel

Replace SettingsViewModel with ShortcutEditorState + AppPreferences in all Views and the SettingsWindowController.

**Files:**
- Modify: `Sources/Quickey/UI/SettingsWindowController.swift`
- Modify: `Sources/Quickey/UI/SettingsView.swift`
- Modify: `Sources/Quickey/UI/ShortcutsTabView.swift`
- Modify: `Sources/Quickey/UI/GeneralTabView.swift`
- Delete: `Sources/Quickey/UI/SettingsViewModel.swift`

- [ ] **Step 1: Update SettingsWindowController**

Replace the full `show()` method in `Sources/Quickey/UI/SettingsWindowController.swift`:

```swift
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let shortcutStore: ShortcutStore
    private let shortcutManager: ShortcutManager
    private let usageTracker: UsageTracker?
    private let hyperKeyService: HyperKeyService?
    private var window: NSWindow?

    init(shortcutStore: ShortcutStore, shortcutManager: ShortcutManager, usageTracker: UsageTracker? = nil, hyperKeyService: HyperKeyService? = nil) {
        self.shortcutStore = shortcutStore
        self.shortcutManager = shortcutManager
        self.usageTracker = usageTracker
        self.hyperKeyService = hyperKeyService
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let editor = ShortcutEditorState(shortcutStore: shortcutStore, shortcutManager: shortcutManager, usageTracker: usageTracker)
        let preferences = AppPreferences(shortcutManager: shortcutManager, hyperKeyService: hyperKeyService)
        let insightsViewModel = InsightsViewModel(usageTracker: usageTracker, shortcutStore: shortcutStore)
        let contentView = SettingsView(editor: editor, preferences: preferences, insightsViewModel: insightsViewModel)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Quickey"
        window.setContentSize(NSSize(width: 720, height: 480))
        window.styleMask.insert(.titled)
        window.styleMask.insert(.closable)
        window.styleMask.insert(.miniaturizable)
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 2: Update SettingsView**

Replace the full file `Sources/Quickey/UI/SettingsView.swift`:

```swift
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case shortcuts = "Shortcuts"
    case general = "General"
    case insights = "Insights"
}

struct SettingsView: View {
    var editor: ShortcutEditorState
    var preferences: AppPreferences
    var insightsViewModel: InsightsViewModel
    @State private var selectedTab: SettingsTab = .shortcuts

    var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch selectedTab {
            case .shortcuts:
                ShortcutsTabView(editor: editor, preferences: preferences)
            case .general:
                GeneralTabView(preferences: preferences)
            case .insights:
                InsightsTabView(viewModel: insightsViewModel)
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 420)
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .insights {
                Task { await insightsViewModel.refresh() }
            }
        }
        .onAppear {
            preferences.refreshPermissions()
        }
    }
}
```

Note: `.onAppear { preferences.refreshPermissions() }` replaces the old 3-second polling timer. Permissions refresh when the settings window opens.

- [ ] **Step 3: Update ShortcutsTabView**

Replace the full file `Sources/Quickey/UI/ShortcutsTabView.swift`:

```swift
import SwiftUI

struct ShortcutsTabView: View {
    @Bindable var editor: ShortcutEditorState
    var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(preferences.accessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(preferences.accessibilityGranted ? "Accessibility granted" : "Accessibility required for global shortcuts")
                    .foregroundStyle(.secondary)
                Button("Refresh") {
                    preferences.refreshPermissions()
                }
                Spacer()
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
                        HStack(spacing: 4) {
                            Text(recordedShortcut.displayText)
                                .font(.system(.body, design: .monospaced))
                            if recordedShortcut.isHyper {
                                Text("Hyper")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.purple.opacity(0.2))
                                    .foregroundStyle(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    } else if editor.isRecordingShortcut {
                        Text("Listening...")
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
                            Text("\(editor.usageCounts[shortcut.id, default: 0])x past 7 days")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text(shortcut.displayText)
                                .font(.system(.body, design: .monospaced))
                            if shortcut.isHyper {
                                Text("Hyper")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.purple.opacity(0.2))
                                    .foregroundStyle(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
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
```

- [ ] **Step 4: Update GeneralTabView**

Replace the full file `Sources/Quickey/UI/GeneralTabView.swift`:

```swift
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
                Toggle("Enable Hyper Key (Caps Lock -> Control+Option+Shift+Command)", isOn: Binding(
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
```

- [ ] **Step 5: Delete SettingsViewModel**

```bash
git rm Sources/Quickey/UI/SettingsViewModel.swift
```

- [ ] **Step 6: Build and test**

Run: `swift build && swift test`
Expected: All compile, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Quickey/UI/SettingsWindowController.swift \
  Sources/Quickey/UI/SettingsView.swift \
  Sources/Quickey/UI/ShortcutsTabView.swift \
  Sources/Quickey/UI/GeneralTabView.swift
git commit -m "Split SettingsViewModel into ShortcutEditorState + AppPreferences

Replace the monolithic SettingsViewModel with two focused @Observable
classes: ShortcutEditorState (editing CRUD) and AppPreferences
(permissions, launch-at-login, hyper key). Remove 3-second permission
polling timer from UI layer (ShortcutManager's polling still active)."
```

---

### Task 8: Final verification

**Files:** None (verification only)

- [ ] **Step 1: Full build**

Run: `swift build -c release`
Expected: Release build succeeds with no warnings related to our changes.

- [ ] **Step 2: Full test suite**

Run: `swift test`
Expected: All tests pass.

- [ ] **Step 3: Verify file structure**

Run: `find Sources/Quickey -name "*.swift" | sort`

Expected new files:
- `Sources/Quickey/Models/KeyPress.swift`
- `Sources/Quickey/Protocols/AppSwitching.swift`
- `Sources/Quickey/Protocols/EventTapManaging.swift`
- `Sources/Quickey/Services/AppPreferences.swift`
- `Sources/Quickey/Services/ShortcutEditorState.swift`

Expected deleted file:
- `Sources/Quickey/UI/SettingsViewModel.swift` (gone)

- [ ] **Step 4: Document in handoff notes**

Note for macOS real-device testing (cannot be verified in CI):
- Settings window opens, all 3 tabs work
- Shortcut add/remove/conflict detection
- Permission indicator shows correct state
- Launch at Login toggle
- Hyper Key toggle
- Insights data loads
- Global shortcuts still trigger correctly
