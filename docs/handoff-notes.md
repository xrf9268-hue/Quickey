# Handoff Notes

## Current State
Quickey was broadly validated on macOS 15.3.1 on 2026-03-20. On 2026-03-23, the runtime hardening follow-up added service-level test seams for permission, app discovery, frontmost-app restore, preferences, and activation fallback paths, and replaced the deprecated `activateIgnoringOtherApps` fallback with a modern `NSWorkspace` reopen request. Issue #67's launch-at-login approval-state UX also landed on 2026-03-23, including Settings foreground refresh coverage for launch-at-login state changes, and `swift test`, `swift build`, `swift build -c release`, and `./scripts/package-app.sh` were rerun afterward. Coverage for the newly targeted services is now measurable: `AccessibilityPermissionService` 64.29%, `AppListProvider` 40.78%, `AppPreferences` 72.50%, `FrontmostApplicationTracker` 43.64%, and `AppSwitcher` 10.55%. A deeper macOS runtime investigation later on 2026-03-23 found that toggle semantics are still not stable enough for some system apps such as Home: new post-action logs showed cases where the target app had visible windows while `NSWorkspace.shared.frontmostApplication` remained another bundle, and other cases where `NSRunningApplication.isActive` disagreed with the frontmost-app snapshot during restore. A design follow-up is now in progress to introduce stable activation gating, degraded-success rules for window-weird apps, and stricter event tap recovery observability. A signed and notarized distributable is still unresolved.

## Validated on macOS
- Broad real-device validation completed on macOS 15.3.1 on 2026-03-20
- `swift build`, `swift test`, release build, and `./scripts/package-app.sh` passed
- Dual permission gating, active capture startup, and end-to-end shortcut interception were validated
- Runtime toggle behavior, restore/hide fallback, and window recovery paths were exercised successfully
- Insights persistence and restart behavior were confirmed during the macOS pass

## Follow-up Requiring macOS Validation
- Launch-at-login approval flow after the 2026-03-23 issue #67 approval-state UX update, especially `.requiresApproval` -> `.enabled` foreground refresh and `.notFound` behavior on real installs
- Active event-tap startup and readiness reporting after permission or lifecycle changes
- AppSwitcher fallback behavior after SkyLight failure now that it re-requests activation via `NSWorkspace`
- App toggle stability after the 2026-03-23 Home/system-app investigation, especially "visible but not truly frontmost" states and second-trigger behavior during transitional activation
- Hyper Key failure handling, especially persistence only after `hidutil` succeeds
- Insights date-window and refresh-race fixes
- Signed/notarized distributable workflow once a Developer ID certificate is available

## Operational Caveats
- CGEvent tap readiness depends on both Accessibility and Input Monitoring, plus a successfully started active event tap
- Ad-hoc signing changes can invalidate TCC state; use `tccutil reset` during development when needed
- Launch the app with `open`, not by executing the binary directly, so TCC matches the correct app identity
- SkyLight is a private API dependency for reliable activation from LSUIElement apps and may block App Store submission
- If SkyLight activation fails, Quickey now falls back to an `NSWorkspace` reopen request instead of the deprecated `activateIgnoringOtherApps` path
- Unified logging can hide useful runtime details; file-based debug logs (`~/.config/Quickey/debug.log`) are more reliable for diagnosis

## Immediate Next Actions
1. Turn the approved toggle-stability and event-tap reliability design into an implementation plan before making further runtime behavior changes
2. Run a targeted macOS validation pass for normal apps and system apps after the stability redesign lands, especially Home, Clock, System Settings, and fast repeat-trigger flows
3. Produce a signed and notarized `.app` once a Developer ID certificate is available
4. Fold any new validation findings back into this note, not into the feature overview docs
