# Issue #183 Evaluation: Rename `Quickey` to `Wink`

Date: 2026-04-18  
Issue: https://github.com/xrf9268-hue/Quickey/issues/183

## Decision

Current decision: **clean-break rename applied**.

## Why

The proposal is strong from a naming/branding perspective, but a full rename is currently high-risk for reliability and user continuity because it changes multiple runtime-sensitive identities at once:

- app name (`Wink.app`)
- bundle identifier (`com.wink.app`)
- persisted state locations (for example `~/.config/Wink`, and user support/config paths)
- macOS permission (TCC) identity anchoring tied to app signature + bundle id + path
- login item identity and launch-at-login expectations

Given the project's current focus on capture/activation correctness and runtime validation, a rename now would introduce a large migration surface that is mostly orthogonal to the active stability work.

## Guardrails for a future rename

If we choose to rename later, ship it as a dedicated migration release with explicit scope:

1. No compatibility layer is preserved for legacy `Quickey` paths or bundle identifiers.
2. Validate the clean-break rename on macOS using the packaged app and the live permission / event-tap flow.
3. Update any remaining docs or release notes that still describe the old identity as current state.

## Implementation status for Issue #183

- Clean-break product rename applied.
- Bundle identifier renamed to `com.wink.app`.
- User data paths renamed to `Wink`.
- Legacy `Quickey` compatibility paths are intentionally not preserved.
