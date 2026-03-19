# Packaging and Permissions

## Accessibility
HotApp Clone uses a CGEvent tap for global shortcut capture. On macOS this requires Accessibility permission.

Expected flow:
1. Launch the app
2. The app requests Accessibility access on first shortcut-manager start
3. If not yet granted, the user opens System Settings > Privacy & Security > Accessibility
4. Enable the app and relaunch if needed

## Development caveat
Repeatedly changing the bundle identity or code signature can cause repeated permission prompts. Keep the bundle identifier stable during local iteration.

## Packaging baseline
This repo is SPM-first, but a distributable `.app` still needs an app bundle wrapper.

Recommended baseline:
- keep source in SPM
- generate a macOS app bundle via Xcode or a dedicated packaging script
- use a stable bundle identifier
- add `LSUIElement=1` in the app bundle Info.plist so the app stays out of the Dock

## Info.plist keys
- `LSUIElement` = `1`
- stable `CFBundleIdentifier`
- standard display name and version keys

## Future hardening
- login item support
- notarization/signing workflow
- release packaging script
- permission diagnostics in settings UI
