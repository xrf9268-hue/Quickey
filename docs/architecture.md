# Architecture

## High-level overview
Quickey is a menu bar macOS utility that stores app-shortcut bindings, captures global key events, matches them to stored shortcuts, and toggles target apps.

```text
+--------------------+
|   Menu Bar App     |
|  AppDelegate/Main  |
+---------+----------+
          |
          v
+--------------------+
|   AppController    |
| bootstraps modules |
+----+----+----+-----+
     |    |    |
     |    |    +-----------------------------+
     |    |                                  |
     v    v                                  v
+---------+--------+              +----------------------+
| ShortcutManager  |<------------>|    ShortcutStore     |
| event + trigger  |              | in-memory shortcuts  |
+----+--------+----+              +----------+-----------+
     |        |                              |
     |        v                              v
     |   +------------------+        +-------------------+
     |   | Persistence      |        | Settings UI       |
     |   | JSON save/load   |        | SwiftUI + AppKit  |
     |   +------------------+        +-------------------+
     |
     v
+--------------------+
|  EventTapManager   |
| CGEvent tap input  |
+---------+----------+
          |
          v
+--------------------+
|    KeyMatcher      |
| key/modifier match |
+---------+----------+
          |
          v
+--------------------+
|    AppSwitcher     |
| activate/toggle    |
+----+---------+-----------+
     |         |
     |         +-----------------------+
     |                                 |
     v                                 v
+---------------------------+   +------------------------+
| ToggleSessionCoordinator  |   | ApplicationObservation |
| per-target runtime state  |   | frontmost/window truth |
+------------+--------------+   +------------------------+
             |
             v
+---------------------------+
| FrontmostApplicationTracker |
| previous app restore state |
+---------------------------+
```

## Main modules

### App lifecycle
- `main.swift`
- `AppDelegate`
- `AppController`

Responsibilities:
- start the accessory/menu bar app
- load persisted shortcuts
- start global shortcut handling
- install menu bar UI
- open settings window

### Settings and user interaction
- `SettingsWindowController`
- `SettingsView` (tabbed: Shortcuts / General / Insights)
- `ShortcutEditorState`
- `AppPreferences`
- `ShortcutRecorderView`
- `ShortcutsTabView`
- `GeneralTabView`
- `InsightsTabView`
- `InsightsViewModel`
- `BarChartView`

Responsibilities:
- choose target applications
- record shortcuts
- display saved bindings with inline usage stats
- surface truthful shortcut readiness via `ShortcutCaptureStatus`
- surface launch-at-login state via `LaunchAtLoginStatus`
- show conflicts before saving
- display usage trends and app ranking via Insights tab

### Shortcut domain
- `AppShortcut`
- `RecordedShortcut`
- `ShortcutConflict`
- `ShortcutStore`
- `ShortcutValidator`

Responsibilities:
- represent saved shortcut bindings
- represent recorder output
- detect duplicate/conflicting bindings
- hold in-memory state used by the event path and UI

### Event capture and matching
- `EventTapManager`
- `KeyMatcher`
- `KeySymbolMapper`

Responsibilities:
- listen for global keyDown events via `CGEvent.tapCreate`
- host the active event tap on a dedicated background RunLoop thread
- normalize captured key events
- map between key codes and human-readable shortcut symbols
- match incoming events against stored bindings
- keep callback work lightweight and dispatch recovery work off the callback path
- track lifecycle state and escalation thresholds:
  - first timeout -> in-place re-enable
  - 3 timeouts within 30 seconds -> full recreation
  - 2 recreation failures within 120 seconds -> degraded readiness state
- recreate the tap on the same background thread using a reusable readiness mechanism instead of a one-shot startup handshake

### Activation and toggle logic
- `AppSwitcher`
- `ApplicationObservation`
- `ToggleSessionCoordinator`
- `FrontmostApplicationTracker`
- `AppBundleLocator`

Responsibilities:
- activate target apps
- launch installed apps if not already running
- fall back to `NSWorkspace` reopen requests before plain AppKit activation requests when SkyLight activation cannot complete
- build `ActivationObservationSnapshot` values from frontmost-app, active/hidden, visible-window, focused-window, main-window, and app-classification evidence
- re-evaluate app classification per toggle attempt instead of caching it globally
- keep per-target toggle sessions on the main actor and let `ToggleSessionCoordinator` own the durable `previousBundle` for `activating`, `activeStable`, `degraded`, and `deactivating` phases
- invalidate or clear sessions from `NSWorkspace.didActivateApplicationNotification` and `NSWorkspace.didTerminateApplicationNotification` instead of polling
- only allow toggle-off from a confirmed stable state; repeat triggers during pending or degraded activation re-confirm the session instead of restoring away
- use `FrontmostApplicationTracker` for current-frontmost capture and restore attempts, while session-owned `previousBundle` remains the source of truth during confirmation and deactivation
- restore previous app when toggling away, then hide the target app as a fallback if post-restore observation is still contradictory
- reveal selected application in Finder when needed

### Usage tracking
- `UsageTracker`

Responsibilities:
- record shortcut activations with SQLite daily aggregation
- provide usage counts per shortcut for Insights UI
- run off the main actor via Swift actor isolation

### Permissions and packaging
- `AccessibilityPermissionService`
- `LaunchAtLoginService`
- `ShortcutCaptureStatus`
- `scripts/package-app.sh`
- `Sources/Quickey/Resources/Info.plist`

Responsibilities:
- request/check Accessibility + Input Monitoring permission for global shortcuts
- report shortcut readiness from both permissions plus active event-tap state
- recover monitoring after permission changes without relaunch
- manage launch-at-login state via `SMAppService`, including approval-needed state
- provide LSUIElement app bundle scaffold
- automate `.app` packaging via script

## Runtime event flow

### 1. Startup flow
```text
App launch
  -> AppController.start()
  -> PersistenceService.load()
  -> ShortcutStore.replaceAll()
  -> ShortcutManager.start()
  -> AccessibilityPermissionService.requestIfNeeded()
  -> EventTapManager.start() // active tap only, no passive listenOnly fallback
  -> MenuBarController.install()
```

### 2. Add shortcut flow
```text
User opens settings
  -> choose app
  -> record shortcut
  -> SettingsViewModel builds AppShortcut
  -> ShortcutValidator checks conflicts
  -> ShortcutManager.save()
  -> ShortcutStore.replaceAll()
  -> PersistenceService.save()
```

### 3. Trigger flow
```text
Global keyDown event
  -> EventTapManager emits KeyPress
  -> ShortcutManager.handleKeyPress()
  -> KeyMatcher finds matching AppShortcut
  -> AppSwitcher.toggleApplication()
  -> ToggleSessionCoordinator records bundle-keyed session + previousBundle
  -> ApplicationObservation captures frontmost/window evidence
  -> activate / confirm / recover stage-by-stage
  -> restore previous app / hide fallback only from activeStable
```

### 4. Event tap recovery flow
```text
CGEvent callback receives tapDisabledByTimeout / tapDisabledByUserInput
  -> EventTapManager captures callback-safe snapshot
  -> in-place re-enable happens immediately
  -> lifecycle tracker updates counters
  -> repeated timeout threshold reached
  -> same-thread tap recreation on the dedicated background RunLoop
  -> recreation success returns readiness to running
  -> repeated recreation failure escalates readiness to degraded
```

## Current design choices
- **SPM-first**: simple repo layout and source organization
- **AppKit-first with selective SwiftUI**: deliberate architectural decision documented in `docs/archive/app-structure-direction.md`; hard AppKit requirements (`.accessory` policy, raw key capture, CGEvent tap, NSWorkspace) prevent a pure SwiftUI scene-based approach
- **Truthful shortcut readiness**: `ShortcutCaptureStatus` reports Accessibility, Input Monitoring, and active event-tap state separately
- **O(1) trigger index**: `ShortcutSignature` dictionary replaces linear scans in the hot path
- **Observation-first toggle truth**: `ApplicationObservation` snapshots gate stable-state promotion from frontmost/window evidence instead of trusting `isActive` alone
- **Session-owned previous-app memory**: `ToggleSessionCoordinator` holds the durable `previousBundle` once a toggle session is accepted; `FrontmostApplicationTracker` remains the restore executor
- **Notification-driven invalidation**: `NSWorkspace` activation and termination notifications clear or expire stable/deactivating sessions without polling
- **Hardened EventTap lifecycle**: explicit ownership, callback-safe timeout snapshots, threshold-based escalation, and same-thread run-loop recreation
- **Active tap only**: passive `.listenOnly` mode is not used in the normal interception path because it cannot consume shortcut events
- **SkyLight primary activation path**: private API is used for reliable foreground switching from LSUIElement context
- **Modern AppKit fallback**: when SkyLight activation fails, Quickey re-requests activation via `NSWorkspace.OpenConfiguration` (`activates = true`) and only falls back to a plain AppKit activation request if no bundle URL is available
- **Stable-state toggle semantics**: activate immediately, confirm asynchronously, allow toggle-off only from `activeStable`, and avoid restore-away rollback on confirmation failure
- **Service-level test seams**: system-facing services use small injected clients or existing collaborators so runtime decision logic can be covered without live TCC or app-launch side effects
- **UsageTracker**: SQLite-backed daily usage aggregation off the main actor
- **Launch-at-login status modeling**: `LaunchAtLoginStatus` preserves enabled / approval-needed / disabled / not-found states

## Known architectural gaps
- No dedicated per-shortcut toggle history stack (single global previous-app memory is current approach)
- No test seam around event-tap capture itself (core logic is testable; tap infrastructure requires real macOS)
- Signed/notarized release build not yet produced (workflow documented in `docs/signing-and-release.md`)
- Targeted manual macOS validation is still required for the 2026-03-24 toggle-stability and event-tap recovery redesign, especially system apps, hidden/minimized window paths, and timeout-stress behavior
