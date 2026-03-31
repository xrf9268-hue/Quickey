# macOS Runtime Validation Policy

## Runtime-Sensitive Changes

Any change touching: event taps, app activation, permissions/TCC, Accessibility or Input Monitoring behavior, login items, launch behavior, packaging/signing, or other macOS-only runtime behavior.

## Tracking Rules

- Runtime-sensitive PRs must carry `macOS runtime validation pending` until validated on macOS, then update to `macOS runtime validation complete`.
- On non-macOS hosts: implement, review, and merge after automated checks, but add `macOS runtime validation pending` to both the issue and PR.
- On macOS hosts with actual runtime verification: add `macOS runtime validation complete`.

## Merge vs Release Gate

- **Development merge gate**: CI passes + review gates clean. Runtime validation is NOT required for merge.
- **Release-readiness gate**: All open `macOS runtime validation pending` items must be validated before release, packaging/signing handoff, or release-candidate signoff.
- Never rewrite history or PR descriptions to imply a pending validation was completed when it was not.
