# Issues Backlog

This backlog turns the current roadmap into concrete execution tickets.

## 1. Compile and validate HotApp Clone on macOS
**Goal**
Prove the project builds and runs on a real macOS machine.

**Done when**
- `swift build` works on macOS
- `swift test` works on macOS
- the `.app` launches as an LSUIElement menu bar app
- one shortcut works end to end

## 2. Fix compile/runtime issues discovered during first macOS build
**Goal**
Resolve the first round of real compile or runtime failures found during validation.

**Done when**
- the initial macOS validation blockers are fixed
- the validation checklist can progress past first-run errors

## 3. Polish shortcut recorder UX and unsupported-key handling
**Goal**
Make shortcut capture feel reliable and understandable.

**Done when**
- unsupported keys are explained cleanly
- recorder state is visually clearer
- special key display is more polished

## 4. Improve toggle semantics for minimized/full-screen/multi-window apps
**Goal**
Make app switching behavior more consistent across real-world app states.

**Done when**
- toggle behavior handles common edge cases better
- previous-app restoration is more dependable

## 5. Add stronger Hyper-style shortcut support and validation
**Goal**
Improve capture and matching for heavy modifier combinations.

**Done when**
- at least one Hyper-style shortcut is validated successfully
- known modifier edge cases are documented or fixed

## 6. Automate `.app` packaging end to end
**Goal**
Reduce manual packaging steps.

**Done when**
- one command produces a runnable app bundle from a successful build
- bundle metadata is applied consistently

## 7. Add tests for key mapping, conflicts, and toggle logic
**Goal**
Increase confidence in the project’s core logic.

**Done when**
- key mapping coverage exists
- conflict detection coverage exists
- toggle logic has focused tests

## 8. Document signing/notarization and release workflow
**Goal**
Define the path from local app bundle to distributable build.

**Done when**
- signing expectations are documented
- notarization steps are documented
- release packaging notes are coherent
