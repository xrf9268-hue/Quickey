# Test Persistence Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent Quickey tests from mutating the real user `shortcuts.json` by routing test persistence through isolated temporary storage.

**Architecture:** Reuse `PersistenceService`'s existing `storageURLProvider` injection point from test code only. Add a shared test harness in `Tests/QuickeyTests/TestSupport/` and update all affected test helpers to use it instead of constructing live `PersistenceService()` instances.

**Tech Stack:** Swift 6, Swift Testing, Foundation temporary directories, existing `PersistenceService`

---

### Task 1: Add shared isolated persistence harness

**Files:**
- Create: `Tests/QuickeyTests/TestSupport/TestPersistenceHarness.swift`
- Modify: `Tests/QuickeyTests/PersistenceServiceTests.swift`

- [ ] **Step 1: Write the failing test**

Add a new test helper usage assertion in `Tests/QuickeyTests/PersistenceServiceTests.swift` that creates a reusable harness service, saves a shortcut, and verifies the file lands under a temporary directory rather than the real Application Support path.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PersistenceServiceDiskLoadingTests`
Expected: FAIL because the shared harness type does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `Tests/QuickeyTests/TestSupport/TestPersistenceHarness.swift` with a small harness that owns a temporary directory, exposes `shortcutsURL`, creates an injected `PersistenceService`, and cleans up afterward. Update `PersistenceServiceTests.swift` to reuse the shared harness instead of its private copy.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PersistenceServiceDiskLoadingTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Tests/QuickeyTests/TestSupport/TestPersistenceHarness.swift Tests/QuickeyTests/PersistenceServiceTests.swift
git commit -m "test: add isolated persistence harness"
```

### Task 2: Route affected test helpers through isolated persistence

**Files:**
- Modify: `Tests/QuickeyTests/AppPreferencesTests.swift`
- Modify: `Tests/QuickeyTests/SettingsViewTests.swift`
- Modify: `Tests/QuickeyTests/ShortcutEditorStateTests.swift`
- Modify: `Tests/QuickeyTests/ShortcutManagerStatusTests.swift`

- [ ] **Step 1: Write the failing test**

Add targeted assertions in one affected suite that save shortcuts through a helper-built `ShortcutManager` and verify the shared harness file changes while the real user shortcuts path does not need to be referenced.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ShortcutManagerStatusTests`
Expected: FAIL because the helper still constructs `PersistenceService()` directly.

- [ ] **Step 3: Write minimal implementation**

Update local helper builders to accept a `PersistenceService` parameter or a `TestPersistenceHarness`, and replace every direct `PersistenceService()` in those files with the isolated harness-backed service.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ShortcutManagerStatusTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Tests/QuickeyTests/AppPreferencesTests.swift Tests/QuickeyTests/SettingsViewTests.swift Tests/QuickeyTests/ShortcutEditorStateTests.swift Tests/QuickeyTests/ShortcutManagerStatusTests.swift
git commit -m "test: isolate shortcut manager persistence"
```

### Task 3: Verify repo-wide isolation

**Files:**
- Modify: none

- [ ] **Step 1: Capture baseline checksum**

Run:

```bash
shasum "$HOME/Library/Application Support/Quickey/shortcuts.json"
```

- [ ] **Step 2: Run full verification**

Run:

```bash
swift test
```

Expected: PASS

- [ ] **Step 3: Re-check checksum**

Run:

```bash
shasum "$HOME/Library/Application Support/Quickey/shortcuts.json"
```

Expected: identical checksum before and after `swift test`

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "test: prevent live shortcut persistence writes"
```
