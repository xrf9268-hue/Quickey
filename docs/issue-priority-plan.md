# Issue Priority Plan

This plan groups the existing GitHub issues into a practical execution order.

## Tier 0 — prove the project is real on macOS
These issues should go first because they convert the current scaffold into a validated macOS app.

1. **#1 Compile and validate HotApp Clone on macOS**
2. **#2 Fix compile/runtime issues discovered during first macOS build**

Why first:
Without real macOS validation, architecture and UX improvements remain partially theoretical.

## Tier 1 — highest-value architecture and correctness upgrades
These issues align the implementation with the actual runtime model and improve long-term stability.

3. **#10 Align permission model with CGEvent tap listen-event access APIs**
4. **#11 Replace linear shortcut scans with a precompiled trigger index**
5. **#12 Tighten EventTap lifecycle ownership and cleanup**
6. **#13 Reduce MainActor pressure in runtime shortcut services**

Why second:
These are the strongest improvements for platform alignment, hot-path correctness, and long-term reliability.

## Tier 2 — product behavior and interaction quality
These issues improve the actual user experience once the project is validated and the runtime core is safer.

7. **#3 Polish shortcut recorder UX and unsupported-key handling**
8. **#4 Improve toggle semantics for minimized/full-screen/multi-window apps**
9. **#5 Add stronger Hyper-style shortcut support and validation**

Why here:
They matter a lot, but they should rest on a more trustworthy macOS-validated and architecturally tightened baseline.

## Tier 3 — packaging and daily-utility readiness
These issues move the project closer to something people can run regularly.

10. **#6 Automate .app packaging end to end**
11. **#14 Add launch-at-login support with modern ServiceManagement APIs**
12. **#15 Add app icon, bundle polish, and release metadata**

Why here:
These improve daily use and product quality once core functionality is sound.

## Tier 4 — quality and release hardening
These issues strengthen confidence and make the project easier to ship and maintain.

13. **#7 Add tests for key mapping, conflicts, and toggle logic**
14. **#8 Document signing/notarization and release workflow**
15. **#9 Rename project from HotAppClone to a stronger product name**

Why here:
These are important, but they should follow real validation, core architecture fixes, and product-shape improvements.

## Notes on issue #9 (rename)
The rename issue is intentionally late in this sequence.
A better product name matters, but renaming too early increases churn across:
- repo naming
- bundle identifiers
- docs
- packaging assets
- signing/notarization assumptions

## Recommended execution path
If choosing only the most important next six issues, do them in this order:
1. #1
2. #2
3. #10
4. #11
5. #12
6. #3
