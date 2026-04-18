# Hotkey Recipes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add import/export of shareable shortcut recipe files to Quickey's Settings UI, with Bundle ID then app-name matching, preview-first conflict handling, and truthful unresolved-app persistence.

**Architecture:** Keep the public recipe file format separate from Quickey's internal `shortcuts.json` runtime persistence. Add a small recipe domain and import planner that produce deterministic preview/apply results, then let `ShortcutEditorState` drive AppKit panels and reuse `ShortcutManager.save(shortcuts:)` as the only write path.

**Tech Stack:** Swift 6, AppKit panels and alerts, SwiftUI settings UI, Swift Testing, existing `ShortcutValidator` and `AppListProvider`

---

## File Map

- Create: `Sources/Quickey/Models/QuickeyRecipe.swift` - public recipe schema and item model
- Create: `Sources/Quickey/Services/QuickeyRecipeCodec.swift` - encode/decode `.quickeyrecipe` payloads
- Create: `Sources/Quickey/Services/QuickeyRecipeImportPlanner.swift` - app resolution, conflict preview, and apply logic
- Modify: `Sources/Quickey/Services/AppListProvider.swift` - expose deterministic lookup helpers for Bundle ID and app name
- Modify: `Sources/Quickey/Services/ShortcutEditorState.swift` - own import/export actions, preview state, and final apply via `ShortcutManager.save(shortcuts:)`
- Modify: `Sources/Quickey/UI/ShortcutsTabView.swift` - add `Export...` / `Import...` controls, preview/decision UI, and unresolved-row treatment
- Modify: `Sources/Quickey/Models/AppShortcut.swift` - add derived unresolved-state helpers if needed for truthful row rendering
- Modify: `Tests/QuickeyTests/AppListProviderTests.swift` - lock matching behavior
- Modify: `Tests/QuickeyTests/ShortcutEditorStateTests.swift` - lock export/import confirmation behavior
- Create: `Tests/QuickeyTests/QuickeyRecipeCodecTests.swift` - recipe encode/decode coverage
- Create: `Tests/QuickeyTests/QuickeyRecipeImportPlannerTests.swift` - preview/apply coverage
- Modify: `docs/architecture.md` - document the new recipe import/export path
- Modify: `docs/handoff-notes.md` - record Linux-vs-macOS verification limits for the new AppKit flows

## Task 1: Add The Recipe Schema And Codec

**Files:**
- Create: `Sources/Quickey/Models/QuickeyRecipe.swift`
- Create: `Sources/Quickey/Services/QuickeyRecipeCodec.swift`
- Create: `Tests/QuickeyTests/QuickeyRecipeCodecTests.swift`

- [ ] **Step 1: Write the failing codec tests**

Create `Tests/QuickeyTests/QuickeyRecipeCodecTests.swift` with coverage for round-trip encoding and malformed schema rejection:

```swift
import Foundation
import Testing
@testable import Quickey

@Suite("QuickeyRecipeCodec")
struct QuickeyRecipeCodecTests {
    @Test
    func encodesAndDecodesVersionOneRecipes() throws {
        let recipe = QuickeyRecipe(
            schemaVersion: 1,
            shortcuts: [
                .init(
                    appName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    keyEquivalent: "s",
                    modifierFlags: ["command", "shift"],
                    isEnabled: true
                )
            ]
        )

        let codec = QuickeyRecipeCodec()
        let data = try codec.encode(recipe)
        let decoded = try codec.decode(data)

        #expect(decoded == recipe)
    }

    @Test
    func rejectsUnsupportedSchemaVersion() {
        let payload = Data(
            """
            {
              "schemaVersion": 2,
              "shortcuts": []
            }
            """.utf8
        )

        let codec = QuickeyRecipeCodec()

        #expect(throws: QuickeyRecipeCodec.Error.self) {
            try codec.decode(payload)
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter QuickeyRecipeCodecTests`
Expected: FAIL because the recipe model and codec do not exist yet.

- [ ] **Step 3: Implement the minimal recipe schema and codec**

Add a versioned recipe model and codec:

```swift
struct QuickeyRecipe: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var shortcuts: [QuickeyRecipeShortcut]
}

struct QuickeyRecipeShortcut: Codable, Equatable, Sendable {
    var appName: String
    var bundleIdentifier: String
    var keyEquivalent: String
    var modifierFlags: [String]
    var isEnabled: Bool
}

struct QuickeyRecipeCodec {
    enum Error: Swift.Error {
        case unsupportedSchemaVersion(Int)
    }

    func decode(_ data: Data) throws -> QuickeyRecipe {
        let recipe = try JSONDecoder().decode(QuickeyRecipe.self, from: data)
        guard recipe.schemaVersion == 1 else {
            throw Error.unsupportedSchemaVersion(recipe.schemaVersion)
        }
        return recipe
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter QuickeyRecipeCodecTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Quickey/Models/QuickeyRecipe.swift Sources/Quickey/Services/QuickeyRecipeCodec.swift Tests/QuickeyTests/QuickeyRecipeCodecTests.swift
git commit -m "feat: add quickey recipe codec"
```

## Task 2: Build Deterministic Import Preview And Apply Logic

**Files:**
- Create: `Sources/Quickey/Services/QuickeyRecipeImportPlanner.swift`
- Modify: `Sources/Quickey/Services/AppListProvider.swift`
- Create: `Tests/QuickeyTests/QuickeyRecipeImportPlannerTests.swift`
- Modify: `Tests/QuickeyTests/AppListProviderTests.swift`

- [ ] **Step 1: Write the failing planner tests**

Create `Tests/QuickeyTests/QuickeyRecipeImportPlannerTests.swift` covering Bundle ID lookup, app-name fallback, unresolved results, and conflict application:

```swift
import Foundation
import Testing
@testable import Quickey

@Suite("QuickeyRecipeImportPlanner")
struct QuickeyRecipeImportPlannerTests {
    @Test
    func plansReadyConflictAndUnresolvedEntries() {
        let planner = QuickeyRecipeImportPlanner()
        let installedApps = [
            AppEntry(id: "com.apple.Safari", name: "Safari", url: URL(fileURLWithPath: "/Applications/Safari.app"))
        ]
        let existing = [
            AppShortcut(
                appName: "Terminal",
                bundleIdentifier: "com.apple.Terminal",
                keyEquivalent: "s",
                modifierFlags: ["command", "shift"]
            )
        ]
        let recipe = QuickeyRecipe(schemaVersion: 1, shortcuts: [
            .init(appName: "Safari", bundleIdentifier: "com.apple.Safari", keyEquivalent: "a", modifierFlags: ["command"], isEnabled: true),
            .init(appName: "Terminal", bundleIdentifier: "com.apple.Terminal.missing", keyEquivalent: "s", modifierFlags: ["command", "shift"], isEnabled: true),
            .init(appName: "Ghostty", bundleIdentifier: "com.mitchellh.ghostty", keyEquivalent: "g", modifierFlags: ["command"], isEnabled: true),
        ])

        let plan = planner.planImport(recipe: recipe, existingShortcuts: existing, installedApps: installedApps)

        #expect(plan.ready.count == 1)
        #expect(plan.conflicts.count == 1)
        #expect(plan.unresolved.count == 1)
    }

    @Test
    func replaceExistingSwapsConflictingBindings() {
        let planner = QuickeyRecipeImportPlanner()
        let existing = [
            AppShortcut(
                appName: "Terminal",
                bundleIdentifier: "com.apple.Terminal",
                keyEquivalent: "s",
                modifierFlags: ["command", "shift"]
            )
        ]
        let conflict = PlannedImportedShortcut(
            resolvedAppName: "Safari",
            resolvedBundleIdentifier: "com.apple.Safari",
            sourceAppName: "Safari",
            sourceBundleIdentifier: "com.apple.Safari",
            keyEquivalent: "s",
            modifierFlags: ["command", "shift"],
            isEnabled: true,
            resolution: .matchedByBundleIdentifier
        )

        let updated = planner.applying(
            ready: [],
            unresolved: [],
            conflicts: [.init(imported: conflict, existing: existing[0])],
            to: existing,
            strategy: .replaceExisting
        )

        #expect(updated.count == 1)
        #expect(updated[0].bundleIdentifier == "com.apple.Safari")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter QuickeyRecipeImportPlannerTests`
Expected: FAIL because the planner types and logic do not exist yet.

- [ ] **Step 3: Implement the import planner and app lookups**

Add:

- `AppListProvider` helpers for exact Bundle ID lookup and exact case-insensitive name lookup.
- `QuickeyRecipeImportPlanner` that:
  - resolves each recipe item
  - classifies it as `ready`, `conflict`, or `unresolved`
  - applies `skipConflicts` or `replaceExisting`
  - converts planned items into fresh `AppShortcut` values

Minimal shape:

```swift
enum ImportedAppResolution: Equatable {
    case matchedByBundleIdentifier
    case matchedByAppName
    case unresolved
}

enum RecipeConflictResolutionStrategy {
    case skipConflicts
    case replaceExisting
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter QuickeyRecipeImportPlannerTests`
Expected: PASS

- [ ] **Step 5: Extend `AppListProvider` tests**

Add one focused `AppListProviderTests.swift` case that proves ambiguous name matches do not resolve automatically.

- [ ] **Step 6: Run provider tests**

Run: `swift test --filter AppListProviderTests`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add Sources/Quickey/Services/AppListProvider.swift Sources/Quickey/Services/QuickeyRecipeImportPlanner.swift Tests/QuickeyTests/AppListProviderTests.swift Tests/QuickeyTests/QuickeyRecipeImportPlannerTests.swift
git commit -m "feat: add recipe import planning"
```

## Task 3: Wire Import/Export Into `ShortcutEditorState`

**Files:**
- Modify: `Sources/Quickey/Services/ShortcutEditorState.swift`
- Modify: `Tests/QuickeyTests/ShortcutEditorStateTests.swift`

- [ ] **Step 1: Write the failing editor-state tests**

Add tests proving:

- export uses the current shortcuts and only writes recipe data
- import preview does not call `ShortcutManager.save(shortcuts:)`
- confirmed import does call `ShortcutManager.save(shortcuts:)`

Sketch:

```swift
@Test @MainActor
func confirmingReplaceExistingImportSavesUpdatedShortcuts() throws {
    let recorder = RecipeEditorRecorder()
    let context = makeEditorContext(recorder: recorder)

    try context.editor.beginImport(from: sampleRecipeData)

    #expect(recorder.savedShortcutSnapshots.isEmpty)

    context.editor.applyPendingImport(strategy: .replaceExisting)

    #expect(recorder.savedShortcutSnapshots.count == 1)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter ShortcutEditorStateTests`
Expected: FAIL because import/export state and hooks do not exist yet.

- [ ] **Step 3: Implement editor-state import/export workflow**

Add minimal dependencies to `ShortcutEditorState`:

- recipe codec
- import planner
- file read/write hooks or small AppKit panel wrappers

Behavior:

- `exportRecipes()`
- `beginImport(from data: Data)`
- `applyPendingImport(strategy:)`
- `discardPendingImport()`

Do not save during preview creation.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter ShortcutEditorStateTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Quickey/Services/ShortcutEditorState.swift Tests/QuickeyTests/ShortcutEditorStateTests.swift
git commit -m "feat: add recipe workflow to editor state"
```

## Task 4: Add Settings UI And Truthful Unresolved Presentation

**Files:**
- Modify: `Sources/Quickey/UI/ShortcutsTabView.swift`
- Modify: `Sources/Quickey/Models/AppShortcut.swift`
- Modify: `docs/architecture.md`
- Modify: `docs/handoff-notes.md`

- [ ] **Step 1: Write the smallest failing UI/state regression tests that are practical**

If the existing Settings tests can cover any state-driven text, add one assertion for unresolved-row messaging there. Keep AppKit panel behavior out of Linux claims.

- [ ] **Step 2: Run the targeted tests to verify the new expectation fails**

Run: `swift test --filter SettingsViewTests`
Expected: FAIL if a new unresolved-state assertion was added; otherwise document that UI panel behavior is macOS-manual-only and proceed.

- [ ] **Step 3: Implement the UI**

Add:

- `Export...` and `Import...` controls in `ShortcutsTabView`
- preview presentation summarizing ready/conflict/unresolved counts
- buttons for `Skip Conflicts` and `Replace Existing`
- unresolved shortcut row treatment, for example:

```swift
if shortcut.isUnresolvedTarget {
    Label("App not currently installed", systemImage: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.orange)
}
```

- [ ] **Step 4: Run the targeted tests again**

Run: `swift test --filter SettingsViewTests`
Expected: PASS for any automated state coverage that was added.

- [ ] **Step 5: Update docs**

Document the new flow in `docs/architecture.md` and record the remaining macOS-only validation for panels and preview UX in `docs/handoff-notes.md`.

- [ ] **Step 6: Run the focused documentation-adjacent test sweep**

Run: `swift test --filter "QuickeyRecipeCodecTests|QuickeyRecipeImportPlannerTests|ShortcutEditorStateTests|AppListProviderTests|SettingsViewTests"`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add Sources/Quickey/UI/ShortcutsTabView.swift Sources/Quickey/Models/AppShortcut.swift docs/architecture.md docs/handoff-notes.md
git commit -m "feat: add hotkey recipe settings UI"
```

## Final Verification

- [ ] **Step 1: Run the focused test sweep**

Run: `swift test --filter "QuickeyRecipeCodecTests|QuickeyRecipeImportPlannerTests|ShortcutEditorStateTests|AppListProviderTests|SettingsViewTests"`
Expected: PASS

- [ ] **Step 2: Run the full test suite if the host can support it**

Run: `swift test`
Expected: PASS on macOS; if run from Linux or a non-macOS host, report the limitation instead of claiming success.

- [ ] **Step 3: Manual macOS validation checklist**

Validate on macOS:

1. Export writes a readable `.quickeyrecipe` file.
2. Import preview shows ready/conflict/unresolved counts.
3. `Skip Conflicts` preserves existing conflicting shortcuts.
4. `Replace Existing` swaps conflicting shortcuts.
5. Unresolved imported apps remain visible with warning styling.

