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
+---------+----------+
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
- `SettingsView`
- `SettingsViewModel`
- `ShortcutRecorderView`

Responsibilities:
- choose target applications
- record shortcuts
- display saved bindings
- surface permission state
- show conflicts before saving

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
- normalize captured key events
- map between key codes and human-readable shortcut symbols
- match incoming events against stored bindings

### Activation and toggle logic
- `AppSwitcher`
- `FrontmostApplicationTracker`
- `AppBundleLocator`

Responsibilities:
- activate target apps
- launch installed apps if not already running
- restore previous app when toggling away
- hide target app as fallback
- reveal selected application in Finder when needed

### Permissions and packaging
- `AccessibilityPermissionService`
- `scripts/package-app.sh`
- `Sources/Quickey/Resources/Info.plist`

Responsibilities:
- request/check Accessibility trust
- provide LSUIElement app bundle scaffold
- establish the baseline packaging path

## Runtime event flow

### 1. Startup flow
```text
App launch
  -> AppController.start()
  -> PersistenceService.load()
  -> ShortcutStore.replaceAll()
  -> ShortcutManager.start()
  -> AccessibilityPermissionService.requestIfNeeded()
  -> EventTapManager.start()
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
  -> activate / restore previous app / hide fallback
```

## Current design choices
- **SPM-first**: simple repo layout and source organization
- **SwiftUI + AppKit hybrid**: SwiftUI for settings, AppKit where window/control behavior needs it
- **Public API baseline first**: avoid private SkyLight dependency in the first deliverable
- **Best-effort toggle semantics**: restore previous app when possible, otherwise hide target app
- **Linux-authored, macOS-targeted**: architecture is prepared here, but final validation must happen on macOS

## Known architectural gaps
- Recorder control is functional but basic
- No dedicated abstraction for per-shortcut trigger history yet
- No test seam around event-tap capture
- No signed release pipeline yet
- No private low-latency activation tier yet
