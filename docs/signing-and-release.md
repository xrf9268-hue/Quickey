# Signing, Notarization, and Release Workflow

## Overview

HotApp Clone is an SPM-based macOS menu-bar app. Distribution requires:
1. Building a release binary
2. Packaging into an `.app` bundle
3. Code signing
4. Notarization with Apple
5. Creating a distributable archive

## Prerequisites

- Apple Developer account (Individual or Organization)
- Xcode command-line tools installed
- A Developer ID Application certificate in your keychain
- An app-specific password for notarization (or App Store Connect API key)

## 1. Build Release Binary

```bash
swift build -c release
```

The binary is produced at `.build/release/HotAppClone`.

## 2. Package App Bundle

Use the included packaging script:

```bash
./scripts/package-app.sh
```

This creates `build/HotAppClone.app` with:
- `Contents/MacOS/HotAppClone` (release binary)
- `Contents/Info.plist` (from `Sources/HotAppClone/Resources/Info.plist`)
- `Contents/Resources/` (empty, ready for icons)

## 3. Code Signing

Sign the app bundle with your Developer ID certificate:

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --entitlements entitlements.plist \
  build/HotAppClone.app
```

### Entitlements

Create `entitlements.plist` at the project root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.automation.apple-events</key>
  <true/>
</dict>
</plist>
```

**Note:** The app uses Accessibility APIs (CGEvent tap) which require user-granted permission at runtime, not an entitlement. The `com.apple.security.automation.apple-events` entitlement enables the `NSWorkspace` app-activation calls.

### Verify Signing

```bash
codesign --verify --deep --strict --verbose=2 build/HotAppClone.app
spctl --assess --type exec --verbose build/HotAppClone.app
```

## 4. Notarization

### Create a ZIP for Upload

```bash
ditto -c -k --keepParent build/HotAppClone.app build/HotAppClone.zip
```

### Submit for Notarization

Using an App Store Connect API key (recommended):

```bash
xcrun notarytool submit build/HotAppClone.zip \
  --key ~/.private_keys/AuthKey_KEYID.p8 \
  --key-id KEYID \
  --issuer ISSUER_UUID \
  --wait
```

Or using an app-specific password:

```bash
xcrun notarytool submit build/HotAppClone.zip \
  --apple-id "your@email.com" \
  --team-id TEAM_ID \
  --password "@keychain:notarytool-password" \
  --wait
```

### Staple the Ticket

After notarization succeeds:

```bash
xcrun stapler staple build/HotAppClone.app
```

### Verify Notarization

```bash
xcrun stapler validate build/HotAppClone.app
spctl --assess --type exec --verbose build/HotAppClone.app
```

## 5. Create Distributable Archive

```bash
ditto -c -k --keepParent build/HotAppClone.app build/HotAppClone.zip
```

This ZIP can be distributed via GitHub Releases or direct download.

## Release Checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Sources/HotAppClone/Resources/Info.plist`
2. Ensure all tests pass: `swift test`
3. Run `./scripts/package-app.sh`
4. Code sign with `--options runtime`
5. Submit for notarization and wait for approval
6. Staple the notarization ticket
7. Create the distributable ZIP
8. Tag the release: `git tag v0.X.0 && git push origin v0.X.0`
9. Create a GitHub Release with the ZIP attached

## Troubleshooting

### "not valid for use in Developer ID" error
Your certificate may be expired or not a Developer ID Application certificate. Check `security find-identity -v -p codesigning`.

### Notarization rejected
Run `xcrun notarytool log <submission-id>` to see the detailed rejection reasons. Common issues:
- Missing hardened runtime (`--options runtime`)
- Unsigned nested frameworks or libraries
- Use of private/restricted APIs

### Accessibility permission lost after re-signing
macOS ties Accessibility permission to the code signature. After re-signing, users need to re-grant permission in System Settings > Privacy & Security > Accessibility.

## CI Integration

The GitHub Actions workflow (`.github/workflows/ci.yml`) currently builds and tests on every push. A release workflow can be added to automate steps 1-7 when a version tag is pushed. See the existing CI configuration as a starting point.
