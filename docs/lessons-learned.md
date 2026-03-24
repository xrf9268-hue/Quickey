# Quickey Troubleshooting Guidance

## CGEvent Tap Permissions

**Issue**
`AXIsProcessTrusted()` can return true while `CGEvent.tapCreate()` still fails.

**Cause**
On macOS 15, a working event tap requires both Accessibility and Input Monitoring. Either permission alone is not enough.

**Practical guidance**
Check both `AXIsProcessTrusted()` and `CGPreflightListenEventAccess()` as prerequisites, but treat shortcut capture as ready only after the active event tap starts successfully. When validating on a clean machine, request and confirm both permissions, then verify the tap startup path.

## Ad-hoc Signing and TCC

**Issue**
Permissions appear enabled in System Settings, but Quickey is still not trusted after a rebuild.

**Cause**
TCC binds permissions to the app's code signature. Ad-hoc signatures change between builds, so a new binary no longer matches the old TCC record.

**Practical guidance**
After rebuilding locally, reset and regrant permissions if the app stops matching its previous TCC state:

```bash
tccutil reset Accessibility com.quickey.app
tccutil reset ListenEvent com.quickey.app
```

For long-lived releases, use a stable Developer ID signature.

## Launch Via `open`

**Issue**
Launching the app binary directly can produce different permission behavior than launching the app bundle.

**Cause**
TCC and app identity matching are tied to the bundle launch path. Directly running `./Quickey.app/Contents/MacOS/Quickey` can bypass the launch context used during permission registration.

**Practical guidance**
Validate permission-sensitive behavior by starting the app with `open Quickey.app`, not by executing the binary directly.

## File-Based Diagnostics

**Issue**
`log stream` and `log show` may not expose the diagnostics needed during local debugging.

**Cause**
Unified logging is filtered and can hide the messages you expect to see.

**Practical guidance**
Use a file-backed log for troubleshooting, such as `~/.config/Quickey/debug.log`. Create the parent directory first, then append short diagnostic lines there.

## `@Sendable` Completion Handlers

**Issue**
`NSWorkspace.openApplication` can crash or assert when its completion handler touches main-actor state.

**Cause**
The completion callback may arrive on a background queue, while captured values from `@MainActor` context remain isolated unless they are extracted safely.

**Practical guidance**
Copy any needed values before the call, and mark the completion handler `@Sendable`. Keep the closure free of implicit main-actor assumptions.

## SkyLight Activation

**Issue**
`NSRunningApplication.activate()` is unreliable for bringing an LSUIElement app to the foreground on macOS 14+.

**Cause**
The cooperative activation path can report success without actually activating the app.

**Practical guidance**
Use the SkyLight-based activation path when Quickey must reliably front the target app. Treat it as the validated route for LSUIElement activation behavior.

## Frontmost Truth for Toggle Semantics

**Issue**
An app can appear visually present while Quickey still should not treat it as safely toggleable.

**Cause**
App activation on macOS is transitional. `NSRunningApplication.activate()` only attempts activation, and `NSRunningApplication.isActive` can briefly disagree with `NSWorkspace.shared.frontmostApplication` during odd system-app or window-recovery flows.

**Practical guidance**
For app-level toggle behavior, treat `NSWorkspace.shared.frontmostApplication` as the primary truth because Apple defines it as the app receiving key events. Use `isActive`, `isHidden`, and window visibility as supporting signals, not as the sole toggle-off gate.

## Stable Activation Beats Instantaneous Activation

**Issue**
Repeated shortcut presses can flap between "activate" and "toggle off" if Quickey decides from a single immediate state snapshot.

**Cause**
The first trigger may only have started activation, while the second trigger arrives before the app has reached a stable frontmost state with a usable window.

**Practical guidance**
Do not let "activation requested" mean "activation complete". Require a short post-activation confirmation pass and only allow toggle-off from a stable active state. During pending or degraded activation, a repeat trigger should re-confirm or re-attempt activation instead of restoring away immediately.

## System Apps Need Honest Downgrade Rules

**Issue**
Apps such as Home can produce visible windows without behaving like normal key-window-driven document apps.

**Cause**
Some system utilities use nonstandard scene, hide/unhide, or window activation behavior that does not match assumptions baked into regular AppKit apps.

**Practical guidance**
Do not force all apps through one generic "front app with visible window means success" rule. Keep a degraded-success path for system or window-weird apps, log why the app is degraded, and avoid counting degraded activation as safe toggle-off state.

## Event Tap Timeout Recovery Needs Escalation

**Issue**
Re-enabling an event tap after a timeout is necessary but not always sufficient.

**Cause**
macOS can repeatedly disable the tap with `tapDisabledByTimeout`, which indicates sustained callback or lifecycle pressure rather than a one-off interruption.

**Practical guidance**
Keep the callback path light and re-enable in place first, but track rolling timeout counts. If repeated timeouts cluster together, escalate from in-place re-enable to full tap recreation and log the recovery tier so later diagnosis does not start from scratch.
