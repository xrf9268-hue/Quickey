# Documentation Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework Quickey's documentation so the repository homepage reads like a polished external-facing project while maintainer notes and historical process docs remain available but clearly de-emphasized.

**Architecture:** Treat documentation as a three-layer information architecture. Keep `README.md`, `docs/architecture.md`, and `docs/signing-and-release.md` as the stable public-facing set; use `docs/README.md`, `AGENTS.md`, `docs/handoff-notes.md`, and `docs/lessons-learned.md` for maintainer context; keep `docs/archive/` and `docs/superpowers/` as historical/process storage. This is a docs-only change, so verification is done with structural and content checks rather than unit tests.

**Tech Stack:** Markdown, Git, `rg`, `sed`, shell verification commands

**Spec:** `docs/superpowers/specs/2026-03-21-documentation-architecture-design.md`

---

## File Structure

- `README.md`
  Public-facing landing page. Should explain what Quickey is, its main capabilities, platform constraints, build/run commands, and where stable documentation lives.

- `docs/README.md`
  Maintainer-facing documentation map. Should categorize documents by role instead of presenting a flat list.

- `AGENTS.md`
  Agent operating guide. Must stop referring to `TODO.md` and should point planning/continuation guidance to GitHub Issues plus maintainer docs.

- `docs/handoff-notes.md`
  Maintainer-only operational status note. Should keep validation state, unresolved macOS follow-up work, and operational caveats.

- `docs/lessons-learned.md`
  Troubleshooting and validation reference. Should be rewritten in English and organized as concise issue/cause/guidance notes.

- `docs/archive/README.md`
  Archive disclaimer. Should say these documents are historical and not the current source of truth.

- `TODO.md`
  Remove. GitHub Issues becomes the only active task tracker.

## Scope Guardrails

- Do not rewrite `docs/architecture.md` unless a stale `TODO.md` or navigation reference is discovered there.
- Do not edit `docs/superpowers/` history files other than adding this plan document.
- Do not rewrite archived historical documents just to remove old mentions of `TODO.md`; keep historical text intact unless it appears in active documentation.
- Prefer short, stable prose over date-heavy status narration in public-facing docs.

### Task 1: Rewrite the Root README as a Product Landing Page

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the current README structure with the approved public-facing outline**

Use this outline as the target structure:

````md
# Quickey

<1 short positioning paragraph>

## Highlights
- <5-7 concise bullets>

## Requirements and Constraints
- macOS 14+
- Swift 6 / SPM-first
- macOS runtime behavior must be validated on macOS
- SkyLight is a private API dependency for activation reliability

## Build and Run
```bash
swift build
swift test
swift build -c release
./scripts/package-app.sh
cp .build/release/Quickey build/Quickey.app/Contents/MacOS/Quickey
```

## Documentation
- `AGENTS.md`
- `docs/README.md`
- `docs/architecture.md`
- `docs/signing-and-release.md`

## Project Status
<1 short paragraph: feature-complete, validated on macOS, signed/notarized release still pending>
````

Constraints for the new content:
- Remove direct links to `TODO.md`
- Remove the large "Current status" checklist style section
- Remove `docs/lessons-learned.md` from the primary navigation list
- Keep permission and launch-at-login details compact; do not turn the README into an operational playbook

- [ ] **Step 2: Review the README diff for tone and audience**

Run:

```bash
git diff -- README.md
```

Expected:
- the diff reads like a landing-page rewrite, not a minor wording shuffle
- section count is smaller and more stable than before
- no internal handoff phrasing remains

- [ ] **Step 3: Verify the README structure**

Run:

```bash
rg -n "^## " README.md
```

Expected headings include:
- `Highlights`
- `Requirements and Constraints`
- `Build and Run`
- `Documentation`
- `Project Status`

- [ ] **Step 4: Verify removed content stays removed**

Run:

```bash
rg -n "TODO\\.md|Lessons learned|^## Current status$" README.md
```

Expected:
- no match for `TODO.md`
- no `Lessons learned` navigation entry
- no `## Current status` heading

- [ ] **Step 5: Commit the README rewrite**

```bash
git add README.md
git commit -m "docs: rewrite README for external readers"
```

### Task 2: Rebuild the Docs Index and Agent Guide Around the New Navigation Model

**Files:**
- Modify: `docs/README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Rewrite `docs/README.md` as a categorized documentation map**

Use this target structure:

```md
# Docs Index

<1 short sentence about this directory>

## Core Docs
- `architecture.md`
- `signing-and-release.md`

## Maintainer Notes
- `../AGENTS.md`
- `handoff-notes.md`
- `lessons-learned.md`

## Historical and Process Docs
- `archive/`
- `superpowers/`

## Suggested Reading Order
1. `../AGENTS.md`
2. `architecture.md`
3. `handoff-notes.md`
4. `lessons-learned.md`
5. `signing-and-release.md`
```

Content rules:
- remove all references to `TODO.md`
- make it obvious that `archive/` and `superpowers/` are not the current source of truth
- keep the audience contributor/maintainer-focused

- [ ] **Step 2: Update `AGENTS.md` to remove `TODO.md` from active guidance**

Make these exact conceptual changes:
- in the project overview references, replace `TODO.md` with a maintainer-facing doc reference such as `docs/README.md` or `docs/handoff-notes.md`
- in "Documentation rules", remove `TODO.md` from the always-update list
- remove the instruction to keep `TODO.md` high-level
- in "Source of truth for planning", make GitHub Issues primary and use maintainer docs as secondary context

Do not change platform or architecture guidance in `AGENTS.md`.

- [ ] **Step 3: Review the navigation diff together**

Run:

```bash
git diff -- docs/README.md AGENTS.md
```

Expected:
- `docs/README.md` reads like a clean map, not a status note
- `AGENTS.md` no longer depends on `TODO.md`
- no unrelated guidance changes slipped in

- [ ] **Step 4: Verify active navigation files no longer mention `TODO.md`**

Run:

```bash
rg -n "TODO\\.md" docs/README.md AGENTS.md
```

Expected:
- no output

- [ ] **Step 5: Commit the navigation updates**

```bash
git add docs/README.md AGENTS.md
git commit -m "docs: update maintainer navigation"
```

### Task 3: Tighten `docs/handoff-notes.md` into a Maintainer Status Note

**Files:**
- Modify: `docs/handoff-notes.md`

- [ ] **Step 1: Replace the current long-form product recap with a tighter maintainer structure**

Use this outline:

```md
# Handoff Notes

## Current State
<short summary of validated state and current limitation>

## Validated on macOS
- <compact bullets>

## Follow-up Requiring macOS Validation
- <targeted unresolved checks>

## Operational Caveats
- <short bullets for TCC, `open` vs direct launch, SkyLight, active tap readiness>

## Immediate Next Actions
1. ...
2. ...
3. ...
```

Editing rules:
- preserve the specific dated validation references that still matter
- keep unresolved items concrete and actionable
- remove broad feature inventory already covered by `README.md` and `docs/architecture.md`
- keep this file useful for a maintainer returning after a break

- [ ] **Step 2: Review the handoff diff for duplication**

Run:

```bash
git diff -- docs/handoff-notes.md
```

Expected:
- the file is shorter and denser
- architecture and scope repetition has been cut down
- the remaining sections are operational, not promotional

- [ ] **Step 3: Verify the target section structure**

Run:

```bash
rg -n "^## " docs/handoff-notes.md
```

Expected headings include:
- `Current State`
- `Validated on macOS`
- `Follow-up Requiring macOS Validation`
- `Operational Caveats`
- `Immediate Next Actions`

- [ ] **Step 4: Commit the handoff rewrite**

```bash
git add docs/handoff-notes.md
git commit -m "docs: tighten maintainer handoff notes"
```

### Task 4: Rewrite `docs/lessons-learned.md` in English as Troubleshooting Guidance

**Files:**
- Modify: `docs/lessons-learned.md`

- [ ] **Step 1: Rewrite the file in English with a troubleshooting structure**

Keep these topics:
- dual permission requirement for CGEvent taps
- ad-hoc signing and TCC invalidation
- launching via `open` for correct permission matching
- unified logging limitations and file-based diagnostics
- `@Sendable` completion-handler isolation
- SkyLight as the reliable activation path from an LSUIElement app

Use this per-section pattern:

```md
## <Short topic title>

**Issue**
<what went wrong>

**Cause**
<why it happened>

**Practical guidance**
<what to do in Quickey or when validating it>
```

Editing rules:
- write in English only
- prefer short commands over long code samples unless the command itself is the key guidance
- keep the tone as a reference note, not a personal narrative

- [ ] **Step 2: Review the rewrite for language consistency and signal density**

Run:

```bash
git diff -- docs/lessons-learned.md
```

Expected:
- the diff is a real rewrite, not a line-by-line translation artifact
- sections are shorter and easier to scan
- the document still preserves the important macOS lessons

- [ ] **Step 3: Verify the file is English-only and structurally consistent**

Run:

```bash
LC_ALL=C grep -n '[^ -~[:space:]]' docs/lessons-learned.md
rg -n "^## |\\*\\*Issue\\*\\*|\\*\\*Cause\\*\\*|\\*\\*Practical guidance\\*\\*" docs/lessons-learned.md
```

Expected:
- the `grep` command returns no output
- each section contains `Issue`, `Cause`, and `Practical guidance`

- [ ] **Step 4: Commit the lessons rewrite**

```bash
git add docs/lessons-learned.md
git commit -m "docs: rewrite validation lessons in English"
```

### Task 5: Update the Archive Disclaimer and Remove `TODO.md`

**Files:**
- Modify: `docs/archive/README.md`
- Delete: `TODO.md`

- [ ] **Step 1: Tighten `docs/archive/README.md`**

Rewrite it so it clearly says:
- archived docs are historical
- they may describe completed or superseded states
- they are not the current source of truth for the project

Keep it short, ideally 3-5 lines total.

- [ ] **Step 2: Delete `TODO.md`**

Run:

```bash
rm TODO.md
```

Expected:
- the file is removed from the working tree

- [ ] **Step 3: Verify the file is gone and active docs do not point to it**

Run:

```bash
test ! -e TODO.md
rg -n "TODO\\.md" README.md AGENTS.md docs/README.md docs/handoff-notes.md docs/lessons-learned.md docs/archive/README.md
```

Expected:
- `test ! -e TODO.md` exits successfully
- `rg` prints no output

- [ ] **Step 4: Commit the archive cleanup**

```bash
git add docs/archive/README.md TODO.md
git commit -m "docs: remove obsolete todo board"
```

### Task 6: Run a Final Documentation Verification Pass

**Files:**
- Verify: `README.md`
- Verify: `docs/README.md`
- Verify: `AGENTS.md`
- Verify: `docs/handoff-notes.md`
- Verify: `docs/lessons-learned.md`
- Verify: `docs/archive/README.md`

- [ ] **Step 1: Review the full docs diff**

Run:

```bash
git diff -- README.md docs/README.md AGENTS.md docs/handoff-notes.md docs/lessons-learned.md docs/archive/README.md
```

Expected:
- the docs tell a consistent story
- public-facing files are concise and professional
- maintainer files are operational rather than promotional

- [ ] **Step 2: Run the active-doc navigation checks**

Run:

```bash
rg -n "TODO\\.md" README.md AGENTS.md docs/README.md docs/handoff-notes.md docs/lessons-learned.md docs/archive/README.md
rg -n "^## " README.md docs/README.md docs/handoff-notes.md
```

Expected:
- no `TODO.md` references in active docs
- the heading structure matches the intended public-vs-maintainer split

- [ ] **Step 3: Inspect repo status before handoff**

Run:

```bash
git status --short
git log --oneline -n 6
```

Expected:
- working tree is clean
- recent commits correspond to the task sequence above

- [ ] **Step 4: Prepare execution notes for the final response**

Capture these points for the completion message:
- `TODO.md` was removed
- public-facing docs now center on `README.md`
- maintainer-only notes were kept but downgraded
- macOS runtime validation is still pending where documentation already says so
