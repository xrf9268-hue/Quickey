# Issues Backlog

This file is a lightweight companion to the GitHub issue tracker.

## Use these as the primary execution sources
1. GitHub issues
2. `docs/issue-priority-plan.md`
3. `TODO.md`

## Why this file still exists
It records the main backlog themes at a glance, without repeating the full issue tracker.

## Main backlog themes
- macOS validation
- runtime reliability and architecture correctness
- trigger-path performance improvements
- tests and repeatable validation
- interaction quality and behavior polish
- packaging, launch-at-login, and release hardening
- product naming and identity only after the runtime core is stable

## Architecture-specific themes already tracked
- align permission handling with the real CGEvent tap monitoring model
- tighten event tap lifecycle ownership and disabled/timeout recovery
- recover monitoring after permission changes without relaunch
- replace linear scans with a precompiled trigger index
- reduce unnecessary MainActor pressure in runtime services
- clarify runtime state ownership boundaries

## Rule of thumb
If a task is already represented clearly in GitHub issues or `docs/issue-priority-plan.md`, do not duplicate its full details here.
