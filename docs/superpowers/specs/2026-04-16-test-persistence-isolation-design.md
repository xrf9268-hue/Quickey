# Test Persistence Isolation Design

## Summary

Quickey's unit tests currently allow some test helpers to instantiate `PersistenceService()` with its live default storage path. That path resolves to the real user Application Support directory, which lets `swift test` mutate `~/Library/Application Support/Quickey/shortcuts.json`. The fix must isolate test persistence without changing runtime storage semantics.

## Goals

- Prevent all Quickey tests from reading or writing the real user `shortcuts.json`.
- Keep production `PersistenceService` behavior unchanged for app runtime and packaged-app validation.
- Make isolated persistence the easy default for tests that exercise `ShortcutManager`, `AppPreferences`, and related save flows.

## Non-Goals

- Changing Quickey's runtime storage location.
- Introducing a global "test mode" branch in production code.
- Refactoring unrelated test helpers or persistence behavior.

## Recommended Approach

Add a shared test-only persistence harness under `Tests/QuickeyTests/TestSupport/` that creates a temporary directory and vends an isolated `PersistenceService` via its existing `storageURLProvider` injection point. Update test helpers that currently call `PersistenceService()` directly to accept or create an isolated service from that harness.

## Affected Test Surfaces

- `Tests/QuickeyTests/AppPreferencesTests.swift`
- `Tests/QuickeyTests/SettingsViewTests.swift`
- `Tests/QuickeyTests/ShortcutEditorStateTests.swift`
- `Tests/QuickeyTests/ShortcutManagerStatusTests.swift`

These files currently build live `ShortcutManager` instances that can save shortcuts through the default disk path.

## Design Details

### Shared Test Harness

Create a small helper that:

- allocates a unique temporary directory per test or per helper instance
- exposes `shortcutsURL`
- exposes `makePersistenceService(...)`
- removes the temporary directory in `cleanup()`

This mirrors the existing persistence disk tests, but makes the pattern reusable across all tests that need a `ShortcutManager`.

### Test Helper Integration

Update local helper constructors such as `makeShortcutManager(...)` and `makePreferences(...)` so they either:

- accept an injected `PersistenceService`, or
- internally create one from the shared harness when the caller does not provide one

The key requirement is that no test helper falls back to live disk.

### Verification

Verification should prove both behavior and isolation:

- targeted Swift tests still pass
- full `swift test` still passes
- the real `~/Library/Application Support/Quickey/shortcuts.json` remains byte-for-byte unchanged before and after `swift test`

## Risks

- If any helper still constructs a live `PersistenceService()`, the isolation hole remains.
- If cleanup is forgotten, temp directories will accumulate and mask future failures.

## Acceptance Criteria

- No Quickey tests write to the real user shortcuts file.
- The affected test files use the shared isolated persistence pattern.
- Fresh `swift test` passes without mutating the real Application Support shortcut payload.
