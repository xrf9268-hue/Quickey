# DMG Release Pipeline Design

**Date:** 2026-04-08
**Branch:** main
**Issue:** none assigned
**Scope:** Add a local DMG packaging path and a GitHub Release workflow that produces a signed, notarized, stapled Quickey DMG following Apple's recommended macOS distribution workflow

## Overview

Quickey already has a working `.app` packaging script and maintainer documentation for signing and notarization, but it still stops at a raw app bundle and ZIP-based distribution guidance. That leaves two gaps:

- there is no local drag-to-Applications installer artifact for maintainers to test
- there is no release automation that signs, notarizes, staples, and publishes the final distributable

This design adds a native `DMG` packaging path on top of the existing `.app` bundle flow, keeps `.app` creation as the single packaging source of truth, and introduces a dedicated GitHub Release workflow that only publishes artifacts after Apple-compatible signing and notarization succeed.

## Goals

- Produce a local drag-install DMG from the existing packaged `Quickey.app`
- Keep `.app` creation centralized in the existing packaging path
- Follow Apple's recommended Developer ID plus notarization workflow for macOS app distribution
- Add a release-only GitHub Actions workflow that signs, notarizes, staples, validates, and publishes the DMG
- Preserve a lighter-weight CI path for ordinary push and PR verification without release credentials

## Non-Goals

- Building a `.pkg` installer
- Adding custom installer logic or post-install scripts
- Introducing third-party DMG tooling when native macOS tooling is sufficient
- Claiming Linux validation for DMG generation, Developer ID signing, notarization, or stapling

## Current Context

- [scripts/package-app.sh](/Users/yvan/developer/Quickey/scripts/package-app.sh) already builds and wraps `build/Quickey.app`
- [docs/signing-and-release.md](/Users/yvan/developer/Quickey/docs/signing-and-release.md) documents a manual signing/notarization flow, but still ends with ZIP distribution
- [.github/workflows/ci.yml](/Users/yvan/developer/Quickey/.github/workflows/ci.yml) builds, tests, and verifies the packaged app bundle, but does not produce or publish a DMG
- Quickey is a single LSUIElement app, so distribution does not require a multi-component installer
- Launch-at-login validation now depends on the app being installed in `/Applications` or `~/Applications`, which makes a drag-install DMG directly useful to users and maintainers

## Approved Product Decisions

| Topic | Decision |
|------|----------|
| Distribution artifact | Use `DMG`, not `PKG` |
| Local packaging | Add a native `hdiutil`-based DMG script in-repo |
| `.app` responsibility | Keep `scripts/package-app.sh` as the single `.app` bundle entrypoint |
| Release automation | Add a separate release workflow instead of overloading normal CI |
| Signing path | Use `Developer ID Application` for the app and final DMG |
| Notarization client | Use `xcrun notarytool`, not legacy `altool` |
| Publish gate | Never upload a release DMG unless signing, notarization, stapling, and validation all succeed |

## Approaches Considered

### 1. Native `hdiutil` DMG packaging plus dedicated release workflow

Use the existing `.app` packaging script, add a repo-local DMG script built on native macOS tools, and add a release-only workflow for signing, notarization, and GitHub Release publishing.

Pros:
- Matches the current lightweight SPM-first repository style
- Uses Apple's standard command-line tooling only
- Keeps local packaging and release signing concerns separate
- Lowest long-term maintenance overhead

Cons:
- Finder presentation will be simpler unless explicitly customized in a future visual-polish pass

### 2. Third-party DMG tooling such as `create-dmg` or `appdmg`

Use a third-party utility to generate a more polished DMG and wire that into CI.

Pros:
- Easier visual customization
- Prebuilt conventions for drag-install layouts

Cons:
- Adds external dependencies and more CI setup
- Increases maintenance and breakage risk for a relatively small benefit

### 3. Full release automation through Fastlane

Move packaging, signing, notarization, and GitHub release publication into a Fastlane lane.

Pros:
- Centralized release workflow
- Familiar pattern for some macOS teams

Cons:
- Overly heavy for the current repository
- Adds Ruby tooling and another layer of maintenance

### Recommendation

Use approach 1. It gives Quickey a maintainable native DMG path, follows Apple's recommended distribution model for a single app bundle, and keeps the release-only signing and notarization logic isolated from everyday CI.

## Design

### 1. Packaging Architecture

The packaging pipeline should become a layered flow:

1. `scripts/package-app.sh`
2. `scripts/package-dmg.sh`
3. release-only signing, notarization, stapling, and publication

`scripts/package-app.sh` remains the only script responsible for producing `build/Quickey.app`. It continues to build the release binary, assemble the bundle, copy `Info.plist`, and sign the app. This script should be extended so it can operate in two modes:

- local/dev mode:
  keep the current stable local signing fallback behavior for maintainers
- release mode:
  sign with `Developer ID Application`, hardened runtime, timestamp, and the checked-in entitlements file so the bundle is valid for notarization

`scripts/package-dmg.sh` becomes a thin wrapper around the packaged app:

- verify `build/Quickey.app` exists or call `scripts/package-app.sh`
- read `CFBundleShortVersionString` from the canonical `Info.plist`
- create a temporary staging directory
- copy `Quickey.app` into staging
- create an `Applications` symlink or alias in staging
- use `hdiutil create` to generate `build/Quickey-<version>.dmg`
- clean up the staging directory

The DMG script should not perform notarization itself. Local maintainers need to be able to build a DMG without requiring release credentials.

### 2. Signing and Entitlements

Release signing should follow the standard Developer ID app path:

- app bundle signed with `Developer ID Application`
- hardened runtime enabled
- timestamp enabled
- explicit entitlements checked into the repository

Add a root-level [entitlements.plist](/Users/yvan/developer/Quickey/entitlements.plist) that contains only the runtime entitlements Quickey actually needs for release distribution. The design expectation is:

- no development-only entitlements
- no speculative permissions
- keep the file intentionally minimal

`scripts/package-app.sh` should accept a release identity through environment configuration rather than hardcoding it. That keeps the local developer default intact while allowing CI to inject the real signing identity.

The DMG itself should also be signed in the release workflow before notarization so the final outer container matches Apple's distribution guidance for a DMG-delivered app.

### 3. CI and Release Workflow Split

The existing [ci.yml](/Users/yvan/developer/Quickey/.github/workflows/ci.yml) remains the normal validation workflow for:

- pull requests
- regular pushes
- manual CI runs

It should be extended to verify the new local packaging path:

- `swift build`
- `swift test`
- `scripts/package-app.sh`
- `scripts/package-dmg.sh`
- assert the DMG exists at the expected path

This CI workflow must not require release secrets. It is a structure-and-regression gate, not a publishing flow.

Add a new `.github/workflows/release.yml` for actual publication. It should trigger on:

- `push` tags matching `v*`
- optional `workflow_dispatch`

Its job sequence should be:

1. checkout
2. import Developer ID certificate into a temporary keychain
3. run `swift test`
4. run `scripts/package-app.sh` in release-signing mode
5. run `scripts/package-dmg.sh`
6. sign the DMG if needed by the chosen packaging order
7. submit the final DMG to `xcrun notarytool submit --wait`
8. staple the notarization ticket to the DMG
9. validate with `stapler` and `spctl`
10. create or update a GitHub Release for the tag
11. upload the DMG as the release asset

The release workflow should fail closed. If any signing, notarization, stapling, or validation step fails, the workflow must stop without publishing a GitHub Release asset.

### 4. Credentials and Secrets

Release automation needs two credential groups:

- Developer ID signing credentials
- notarization credentials

Recommended signing inputs:

- base64-encoded Developer ID Application certificate
- certificate password
- temporary keychain password
- signing identity name

Recommended notarization inputs:

- App Store Connect API key
- API key ID
- issuer ID

The release design intentionally prefers `notarytool` with App Store Connect API credentials over older Apple ID plus app-specific-password flows. This is a better fit for CI automation and aligns with Apple's current recommendations.

No release secret should be referenced from the normal CI workflow.

### 5. Versioning and Artifact Naming

The packaging scripts should use the canonical bundle version information from [Info.plist](/Users/yvan/developer/Quickey/Sources/Quickey/Resources/Info.plist):

- `CFBundleShortVersionString` for human-readable release naming
- `CFBundleVersion` for build metadata where needed

The DMG naming convention should be:

- `build/Quickey-<CFBundleShortVersionString>.dmg`

The Git tag convention should be:

- `v<CFBundleShortVersionString>`

This keeps the version source of truth in one place and avoids a second version registry in scripts or workflows.

### 6. Validation and Failure Gates

Local validation commands should be:

- `swift test`
- `bash scripts/package-app.sh`
- `bash scripts/package-dmg.sh`

Release validation commands should additionally include:

- `codesign --verify --deep --strict --verbose=2 build/Quickey.app`
- `spctl --assess --type exec --verbose build/Quickey.app`
- `xcrun stapler validate build/Quickey-<version>.dmg`

If practical, a final `spctl` check should also be run against the stapled DMG or the mounted/staged app path used for release verification.

Release failure policy:

- if certificate import fails, abort
- if app signing fails, abort
- if DMG creation fails, abort
- if notarization fails, abort
- if stapling fails, abort
- if validation fails, abort
- do not upload a non-notarized DMG as a release asset

Ordinary CI may upload non-release artifacts for debugging in a separate follow-up if needed, but those artifacts are not part of this initial design and must not be presented as official releases.

### 7. Documentation Updates

The following docs must be updated when implementation lands:

- [README.md](/Users/yvan/developer/Quickey/README.md)
- [docs/README.md](/Users/yvan/developer/Quickey/docs/README.md)
- [docs/signing-and-release.md](/Users/yvan/developer/Quickey/docs/signing-and-release.md)
- [docs/handoff-notes.md](/Users/yvan/developer/Quickey/docs/handoff-notes.md)

Required documentation changes:

- replace ZIP-first release guidance with DMG-first distribution guidance
- document the new `scripts/package-dmg.sh` entrypoint
- document the release workflow trigger and tag format
- document required GitHub secrets
- state clearly that DMG generation, Developer ID signing, notarization, and stapling require macOS validation

## Testing Strategy

Highest-value automated coverage for this work:

- script-level CI verification that `build/Quickey.app` and `build/Quickey-<version>.dmg` are both produced
- workflow-level checks that the release job references the expected secrets and validation steps
- if script behavior becomes non-trivial, focused tests around version extraction and artifact naming logic should live in shell-level smoke checks rather than force-fitting the behavior into Swift tests

The primary safety net remains command-level validation in CI and release jobs.

## Validation Requirements

This feature is packaging- and distribution-sensitive and therefore requires real macOS validation.

Required macOS validation targets:

- local `scripts/package-dmg.sh` produces a mountable DMG containing `Quickey.app` and `Applications`
- the packaged app can be dragged into `/Applications` and launched successfully
- release-mode signing produces a valid Developer ID signed app bundle
- notarization and stapling succeed on a macOS runner with real credentials
- the resulting DMG is accepted by Gatekeeper on a clean macOS machine
- launch-at-login behavior can be exercised from an installed copy in `/Applications`

Linux-only inspection is insufficient for claiming correctness of the DMG, Developer ID signing, notarization, stapling, or Gatekeeper behavior.

## Acceptance Criteria

- Maintainers can create a local Quickey DMG using a repo script and native macOS tools
- Normal CI verifies the DMG packaging path without requiring release secrets
- A release workflow can publish a signed, notarized, stapled DMG on `v*` tags
- No official release asset is published if notarization or validation fails
- Documentation reflects DMG-first distribution and the new release process

## Implementation Notes For Planning

- Prefer environment variables over hardcoded signing identities in scripts
- Keep `scripts/package-dmg.sh` dependency-free aside from native macOS tooling
- Avoid DMG visual customization work in the first implementation unless it is nearly free
- Structure the release workflow so local packaging and release publication can evolve independently
- Treat notarization credentials and certificate import as isolated workflow concerns rather than baking them into local scripts
