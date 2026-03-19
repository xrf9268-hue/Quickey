# Issue Priority Plan

This plan groups the existing GitHub issues into a practical execution order.

## Tier 0 — prove the project is real on macOS
These issues should go first because they convert the current scaffold into a validated macOS app.

1. **#1 Compile and validate Quickey on macOS**
2. **#2 Fix compile/runtime issues discovered during first macOS build**

Why first:
Without real macOS validation, architecture and UX improvements remain partially theoretical.

## Tier 1 — highest-value architecture and runtime reliability upgrades
These issues align the implementation with the actual runtime model and improve long-term stability.

3. **#10 Align permission model with CGEvent tap listen-event access APIs**
4. **#12 Tighten EventTap lifecycle ownership and cleanup**
5. **#16 Handle CGEvent tap disabled/timeout recovery**
6. **#17 Recover shortcut monitoring after permission changes without relaunch**
7. **#11 Replace linear shortcut scans with a precompiled trigger index**
8. **#13 Reduce MainActor pressure in runtime shortcut services**

Why second:
These are the strongest improvements for platform alignment, hot-path correctness, runtime resilience, and long-term reliability.

## Tier 2 — tests should move earlier than before
These issues now move up because runtime-core changes should be protected by focused verification.

9. **#7 Add tests for key mapping, conflicts, and toggle logic**
10. **#19 Add macOS CI or repeatable build validation path**

Why here:
Codex review highlighted that tests and repeatable validation should not wait until the very end once runtime changes begin.

## Tier 3 — product behavior and interaction quality
These issues improve the actual user experience once the project is validated and the runtime core is safer.

11. **#3 Polish shortcut recorder UX and unsupported-key handling**
12. **#4 Improve toggle semantics for minimized/full-screen/multi-window apps**
13. **#5 Add stronger Hyper-style shortcut support and validation**
14. **#18 Decide app structure direction: SwiftUI scene-based vs deliberate AppKit-first**

Why here:
They matter a lot, but they should rest on a more trustworthy macOS-validated and architecturally tightened baseline.

## Tier 4 — packaging and daily-utility readiness
These issues move the project closer to something people can run regularly.

15. **#6 Automate .app packaging end to end**
16. **#14 Add launch-at-login support with modern ServiceManagement APIs**
17. **#15 Add app icon, bundle polish, and release metadata**

Why here:
These improve daily use and product quality once core functionality is sound.

## Tier 5 — release hardening and identity
These issues remain important but should follow a stronger product baseline.

18. **#8 Document signing/notarization and release workflow**
19. **#9 Rename project from HotAppClone to Quickey**

Why here:
These matter, but renaming or release-hardening too early increases churn before the architecture and runtime are stable.

## Recommended execution path
If choosing only the most important next eight issues, do them in this order:
1. #1
2. #2
3. #10
4. #12
5. #16
6. #17
7. #11
8. #7
