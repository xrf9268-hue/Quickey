# Hotkey Recipes Design

**Date:** 2026-04-18
**Scope:** Shortcut recipe export/import in Settings, app matching, conflict preview, unresolved-app persistence

## Summary

Quickey currently persists shortcuts only as the internal `shortcuts.json` payload under Application Support. Issue #176 adds a user-facing recipe format that can be exported, shared, and imported on another machine without exposing the internal persistence schema directly.

The feature should follow the interaction described in Shun's April 18, 2026 release post: export a readable recipe file, import by matching Bundle ID first and app name second, and detect shortcut conflicts before saving. Quickey should additionally preserve unresolved apps as truthful-but-disabled-looking entries instead of failing import or silently discarding them.

## Goals

- Export the current shortcut configuration as a readable, shareable `.quickeyrecipe` JSON file.
- Import recipe files through the Settings UI.
- Match imported apps by Bundle ID first, then by app name as a fallback.
- Preview conflicts before mutating stored shortcuts.
- Preserve unresolved imported entries instead of rejecting them.
- Keep the existing runtime save path and `ShortcutManager.save()` flow as the only persistence write path.

## Non-Goals

- Replacing or relaxing the strict internal `shortcuts.json` schema.
- Auto-merging conflicts without user confirmation.
- Attempting fuzzy app matching beyond exact Bundle ID or exact case-insensitive app-name matching.
- Adding sync, cloud storage, drag-and-drop import, or menu-bar import/export actions in this issue.

## Recommended Approach

Introduce a separate recipe domain for import/export instead of reusing `AppShortcut` as the public file format.

- `PersistenceService` remains responsible only for the internal `[AppShortcut]` runtime payload.
- A new recipe codec/service handles `.quickeyrecipe` read/write.
- `ShortcutEditorState` owns the UI workflow: export action, import file selection, import preview state, conflict resolution choice, and final apply.
- Final writes still go through `ShortcutManager.save(shortcuts:)` so the in-memory store, trigger index, and capture refresh behavior remain unchanged.

## Recipe Format

Use a human-readable JSON envelope with an explicit schema version:

```json
{
  "schemaVersion": 1,
  "shortcuts": [
    {
      "appName": "Safari",
      "bundleIdentifier": "com.apple.Safari",
      "keyEquivalent": "s",
      "modifierFlags": ["command", "shift"],
      "isEnabled": true
    }
  ]
}
```

Design notes:

- Do not expose internal `AppShortcut.id` values in the recipe format.
- Import generates fresh UUIDs for imported shortcuts.
- `schemaVersion` belongs only to recipes and must not change the existing `shortcuts.json` contract.

## App Matching

Imported recipe entries resolve against the current app catalog in this order:

1. Exact `bundleIdentifier` match.
2. Exact case-insensitive `appName` match if Bundle ID lookup fails.
3. If app-name lookup returns multiple candidates, treat the entry as unresolved.
4. If no match is found, keep the recipe values and mark the entry as unresolved.

`AppListProvider` already maintains the necessary installed-app catalog and is the correct source for import matching.

## Import Workflow

Import should be a two-phase flow:

1. User chooses a `.quickeyrecipe` file from `ShortcutsTabView`.
2. Recipe file is decoded and analyzed into a preview result.
3. Preview groups entries into:
   - `ready`: can be imported immediately
   - `conflict`: shortcut trigger collides with an existing shortcut
   - `unresolved`: app was not resolved on this machine but the entry remains importable
4. User sees a preview dialog/sheet with counts and conflict details.
5. User chooses one of the supported conflict actions:
   - `Skip Conflicts`
   - `Replace Existing`
6. Only after confirmation does Quickey construct the new `[AppShortcut]` set and call `ShortcutManager.save(shortcuts:)`.

Conflict detection should reuse `ShortcutValidator` and existing trigger semantics rather than creating a second definition of "same shortcut."

## Conflict Semantics

Conflict handling was explicitly chosen as preview-first, not auto-merge:

- `Skip Conflicts`: import `ready` and `unresolved` entries only; leave existing conflicting bindings untouched.
- `Replace Existing`: remove existing bindings whose trigger matches an imported conflicting entry, then import the recipe entry.

The preview UI should show both sides of each conflict:

- imported app + shortcut
- existing app + shortcut

## Export Workflow

Export is direct:

1. User clicks `Export...` from the Shortcuts settings UI.
2. Quickey opens `NSSavePanel` with default extension `.quickeyrecipe`.
3. Current `ShortcutEditorState.shortcuts` are converted to recipe items and encoded as pretty-printed JSON.
4. Success/failure is surfaced with lightweight user feedback.

Export should include unresolved entries exactly as currently configured so users can round-trip a full setup between machines.

## Unresolved Imported Apps

Unresolved entries are still imported and persisted. They should not masquerade as fully usable.

UI expectations:

- Show unresolved entries in the shortcuts list with subdued styling and a warning affordance.
- Explain that the target app is not currently installed or could not be uniquely matched.
- Preserve the original `appName` and `bundleIdentifier` from the recipe.

This keeps import truthful while supporting the new-machine restore use case.

## UI Changes

`ShortcutsTabView` gains import/export controls near the shortcut list.

- `Export...` button
- `Import...` button
- Import preview presentation for conflict review and result summary

The shortcut list row presentation should gain an unresolved-app treatment, but the rest of the editor flow stays unchanged.

## Testing Strategy

Add focused automated coverage for the non-UI logic:

- recipe encode/decode round-trip
- schema-version and malformed-file rejection
- Bundle ID match, app-name fallback, ambiguous-name unresolved, and missing-app unresolved
- import preview classification into `ready`, `conflict`, and `unresolved`
- apply behavior for `Skip Conflicts` vs `Replace Existing`
- `ShortcutEditorState` only calling `ShortcutManager.save()` after import confirmation

Manual macOS validation remains required for:

- `NSOpenPanel` / `NSSavePanel`
- import preview presentation and button behavior
- unresolved-row rendering in the Settings window

## Risks

- If recipe handling reuses internal persistence types too directly, future internal schema changes will leak into the public file format.
- If unresolved entries are styled like normal entries, users will believe imported shortcuts are active when they are not.
- If conflict replacement is applied before user confirmation, import becomes destructive and violates the approved interaction.

## Acceptance Criteria

- Users can export a readable `.quickeyrecipe` file from Settings.
- Users can import a recipe file from Settings.
- Import matches apps by Bundle ID first, then app name.
- Import previews conflicts before saving.
- Users can choose `Skip Conflicts` or `Replace Existing`.
- Unresolved apps still import and remain visible with truthful UI treatment.
- Runtime persistence still flows through `ShortcutManager.save(shortcuts:)`.
