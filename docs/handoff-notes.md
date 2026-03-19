# Handoff Notes

## Current state
HotApp Clone is a strong prototype scaffold, not yet a validated macOS product.

Already in place:
- SPM-only Swift project structure
- menu bar app baseline
- settings window and recorder-style shortcut capture
- persistence, event tap baseline, and initial toggle behavior
- packaging scaffold and planning docs
- issue tracker with prioritized execution order

## Most important unresolved facts
- The app has **not** been compiled and validated on a real macOS Swift toolchain yet.
- Global shortcut capture, permission behavior, and toggle behavior still require real macOS verification.
- Runtime reliability work remains higher priority than adding more speculative features.

## Immediate next action
Use a macOS machine to run `docs/macos-validation-checklist.md`.

## If continuing implementation before full product polish
Prefer work in this order:
1. macOS validation
2. runtime reliability and architecture correctness
3. focused tests and repeatable validation
4. interaction quality and behavior improvements
5. packaging / release polish later
