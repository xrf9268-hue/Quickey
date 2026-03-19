# Architecture Remediation Plan

This document captures the next architectural improvements needed to move HotApp Clone from a good scaffold to a stronger macOS-native design.

## P0 — correctness, lifecycle, and hot-path fixes

### 1. Align permissions with the actual CGEvent tap model
**Problem**
The current implementation checks Accessibility-style trust APIs, while the event pipeline is built around `CGEventTap`.

**Target**
Use the most appropriate listen-event access APIs for the actual event-monitoring path.

**Why it matters**
Permission semantics should match the real implementation path, especially for macOS privacy behavior.

### 2. Replace linear shortcut scans with a precompiled O(1) lookup index
**Problem**
Hot-path matching currently scans the saved shortcuts linearly.

**Target**
Create a `ShortcutSignature` model and a prebuilt dictionary keyed by keycode + modifiers.

**Why it matters**
This is the simplest and highest-value performance upgrade for shortcut triggering.

### 3. Tighten event tap lifecycle ownership and cleanup
**Problem**
The current event tap callback context and retained box ownership should be made more explicit and auditable.

**Target**
Ensure callback context allocation, retention, teardown, and run-loop removal all have a clear lifecycle contract.

**Why it matters**
Menu bar utilities are long-lived processes. Lifecycle ambiguity becomes reliability debt.

### 4. Reduce unnecessary MainActor pressure in runtime services
**Problem**
Too much of the runtime path currently lives under `@MainActor`.

**Target**
Keep UI-facing code on the main actor, but reduce main-thread coupling for matching, indexing, and non-UI runtime logic where safe.

**Why it matters**
This improves scalability, responsiveness, and future maintainability.

## P1 — architecture quality and product behavior

### 5. Introduce clearer state boundaries
**Problem**
App shell state, settings state, and runtime shortcut state are still fairly controller-centric.

**Target**
Separate app shell orchestration from persistent settings state and live runtime state.

### 6. Upgrade toggle behavior beyond a single global previous-app memory
**Problem**
Current toggle behavior is best-effort and tracks only one previous non-target app.

**Target**
Move toward per-shortcut or richer restoration heuristics.

### 7. Promote the recorder into a more native-feeling shortcut capture component
**Problem**
The current recorder is functional but still basic.

**Target**
Improve unsupported-key handling, capture clarity, and shortcut presentation.

### 8. Add test seams around event-independent core logic
**Problem**
Core matching and toggle logic should be easier to test without requiring the full macOS event environment.

**Target**
Introduce boundaries or protocols where needed so core logic can be validated with focused tests.

## P2 — productization and modern macOS integration

### 9. Re-evaluate whether MenuBarExtra should own more of the menu bar UI
**Note**
This is optional, not mandatory. The current AppKit-led path is valid, but a future refactor can assess whether newer SwiftUI menu bar patterns are worth adopting.

### 10. Add launch-at-login architecture using modern ServiceManagement APIs
**Target**
Adopt `SMAppService` when the app is ready for real daily use.

### 11. Turn packaging from scaffold into a real release flow
**Target**
Reduce manual app-bundle steps and make packaging reproducible.

### 12. Define the signing and notarization path early
**Target**
Avoid late-stage release friction by planning bundle identity, signing, and notarization clearly.

## Recommended execution order
1. Permission model alignment
2. O(1) shortcut index
3. Event tap lifecycle cleanup
4. Test seams and focused tests
5. Toggle behavior upgrade
6. Recorder polish
7. Launch-at-login and release hardening
