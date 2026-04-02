---
name: babysit-prs
description: >-
  Autonomous PR/issue triage and implementation loop for the current repository.
  Use when the user sets up a /loop interval for automated PR processing,
  issue selection, implementation, and review-gated submission.
  Do not use for one-off PR reviews or manual issue work.
---

# Babysit PRs

Autonomous iteration: process PRs → select issue → implement → review gate → submit. Each iteration is self-contained; leave clear breadcrumbs for the next one.

## Terminology

- **NEXT ITERATION**: End the current iteration. Return control to the /loop scheduler.
- **STOP LOOP**: Halt all work. Only if a safety constraint is violated or the repo is unrecoverably broken.

## Safety Constraints

- NEVER push directly to main. Always use feature branches.
- NEVER delete unmerged branches.
- NEVER modify CLAUDE.md or AGENTS.md core rules and architecture sections.
- NEVER run destructive commands (rm -rf, git reset --hard, git clean -f).
- NEVER modify CI/CD workflows or GitHub Actions configs.
- NEVER merge a PR in the same iteration that created it or pushed new commits to it.
- NEVER treat a missing review tool as a clean review. Missing tooling is a degraded gate — record it explicitly on the PR.
- If an issue is ambiguous or requires architectural decisions, add label `arch-decision` and skip it.

## Turn Budget

Each iteration has **25 turns**. Track your approximate count. At 25 turns without completion: comment on the issue/PR describing what remains, then NEXT ITERATION.

## Pipeline

### Iteration Guard

Before any work, check for duplicate fires:

```bash
gh pr list --search "author:@me" --state open --json updatedAt --limit 5
```

If any PR was updated < 5 minutes ago, this may be a duplicate fire. Proceed to **NEXT ITERATION** without changes.

### Session Init (first iteration only)

If this is the first iteration in the session (no prior `/loop` history in session memory):

1. `gh auth status` — if fails, **STOP LOOP**
2. `git status --short --branch` — if worktree is dirty with unrelated changes, **STOP LOOP**
3. Check review tooling availability: determine whether `/simplify`, `/code-review`, and `/codex:review` are available in this session. Cache the result in session memory.

On subsequent iterations, only run `git status --short --branch`.

### Step 1: Process Existing PRs (max 2 per iteration)

Query: `gh pr list --state open --json number,title,headRefName,statusCheckRollup,labels,reviews`

Process each PR in order: **1b → 1c → 1a**.

**1b. CI failures**: Check `gh pr checks <number>`. Attempt fix (max 2 attempts). If still failing: add label `needs-human-review`, comment, move on. If you push a fix, leave the PR open for a later iteration.

**1c. Review feedback**: Read `references/review-gates.md` for tool-specific rules. Read PR comments: `gh pr view <number> --comments`. Check session memory for `/codex:review` findings. All bot review findings (any priority) and high-confidence `/code-review` findings (≥80): must-fix. Only skip a finding if it is clearly a false positive or provides no actionable value — in that case, comment on the PR explaining why it was dismissed. If a review tool is unavailable, comment that the gate was unavailable and leave the PR open.

**1a. Merge eligible**: A PR is eligible when ALL true:
- CI passes
- No unresolved high-confidence `/code-review` findings (≥80)
- No unresolved bot review findings (any priority)
- No unresolved critical `/codex:review` findings in session memory
- PR was NOT created or pushed to in this iteration
- No `needs-human-review` or `arch-decision` label

If eligible: `gh pr merge <number> --squash --delete-branch`.

### Step 2: Select Next Issue

```bash
gh issue list --state open --json number,title,labels,body --limit 50
```

Priority: P0-critical > P1-high > P2-medium > P3-low > unlabeled. Skip `arch-decision` issues. Skip issues with an open linked PR. Pick **ONE** issue. If none eligible → **NEXT ITERATION**.

### Step 3: Create Branch

```bash
git fetch origin
git checkout main
git pull --ff-only
git checkout -b loop/issue-<number>-<slug>
```

If branch creation fails, comment on the issue and **NEXT ITERATION**.

### Step 4: Classify and Implement

If fewer than 10 turns remain → comment on issue, **NEXT ITERATION**.

- **Simple** (single-file, bug fix, docs): Implement with TDD directly.
- **Complex** (multi-file, new API, 200+ lines):
  - No plan exists: write plan to `docs/superpowers/plans/<topic>.md`, comment on issue, **NEXT ITERATION**.
  - Plan exists: implement ONE sub-task.

For runtime-sensitive changes on non-macOS hosts, see `references/macos-runtime-policy.md`.

### Step 5: Verify and Submit

**5a. Build and test**:
```bash
swift build && swift test && swift build -c release
```
Max 3 fix-build-test cycles. If still failing → comment, **NEXT ITERATION**.

**5b. Code quality**: If `/simplify` is available, run once before committing. If unavailable, note in PR body.

**5c. Commit and create PR**:
```bash
git add -A
git commit -m "<type>: <concise description> (#<N>)"
git push -u origin HEAD
gh pr create --title "<title under 70 chars>" --body "$(cat <<'EOF'
Closes #<N>

## Summary
<1-3 bullet points>

## Verification
- Automated: swift build, swift test, swift build -c release
EOF
)" --base main
```

**5d. Review gate (bounded)**: Fire reviews in parallel where possible:
1. `/codex:review --base main --background` first (async, if available)
2. `/code-review` (sync, if available)
3. Bot reviews arrive asynchronously — handled in Step 1c of a future iteration

Round 1: Fix high-confidence/critical issues, push, re-run each available tool once.
Round 2: If issues persist, fix if 1-2 changes suffice. Otherwise add `needs-human-review`.

Max **2 invocations per review tool per PR per iteration**.

**5e.** Do NOT merge. Leave the PR open for the next iteration so CI and async reviews can settle.

Proceed to **NEXT ITERATION**.

## Gotchas

- `/codex:review` results are **session-local only** — they do not appear as PR comments. Check session memory, not `gh pr view --comments`.
- `/code-review` and bot reviews post durable PR comments readable via `gh pr view --comments` across iterations.
- CronCreate can duplicate-deliver long prompts. This skill exists to avoid that — do not inline its content into `/loop`.
- You MAY append entries to `docs/lessons-learned.md` when discovering operational insights.

## Verification (self-check before NEXT ITERATION)

- [ ] No uncommitted changes left in worktree
- [ ] All PRs touched have clear status comments
- [ ] No missing review gates went unrecorded
- [ ] Branch is not `main`
