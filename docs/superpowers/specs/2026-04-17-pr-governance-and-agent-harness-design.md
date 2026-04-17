# PR Governance And Agent Harness Design

## Summary

Quickey's current pull request automation covers build/test validation, PR metadata enforcement, and GitHub Project field reconciliation, but it does not establish a complete merge harness. In particular, the repository currently has no GitHub branch protection or rulesets on `main`, and no required check fails when actionable review feedback remains unresolved. This leaves a gap where CI can be green while inline review findings still require manual follow-up.

This design introduces a layered governance and harness model for Quickey:

1. GitHub-native governance rules for merge safety.
2. A deterministic review-state harness that converts unresolved actionable review findings into a required check.
3. A runtime-validation harness that separates declarative PR metadata from concrete macOS validation evidence.
4. A non-blocking agent evaluation harness for nightly or manual regression testing of review-remediation workflows.

The intent is to keep merge gates deterministic and auditable, while still adopting modern agentic coding practices and harness engineering for higher-level workflow regression coverage.

## Goals

- Make unresolved actionable PR review findings visible as a machine-evaluable merge signal.
- Move Quickey's merge policy from informal conventions to GitHub-native governance rules.
- Preserve the repository's current runtime-validation policy while making validation evidence easier to collect and review.
- Establish a path for evaluating agent-driven PR remediation workflows without making LLM availability a hard dependency for every PR.

## Non-Goals

- Replacing human code review with AI review.
- Turning external LLM calls into required per-PR merge checks in the first iteration.
- Claiming that GitHub-hosted CI can replace real macOS runtime validation for TCC, event taps, activation behavior, or login items.
- Reworking the current `/loop` or `babysit-prs` automation into the primary merge gate.

## Current State

As of 2026-04-17:

- `main` has no branch protection rule.
- The repository has no configured GitHub rulesets.
- `.github/workflows/ci.yml` provides `CI / Build and Test` on `macos-15`.
- `.github/workflows/pr-metadata.yml` enforces `Fixes #...` and `Validation Status`.
- `.github/workflows/project-sync.yml` reconciles `Quickey Backlog` project fields.
- No repository-native workflow currently reads `reviewThreads`, `reviewDecision`, or unresolved bot findings to block merges.

This means Quickey already has useful automation primitives, but not a complete governance harness.

## Design Principles

### Deterministic Gates First

Required merge gates should rely on stable, auditable signals:

- GitHub rulesets / branch protection
- deterministic review-thread state
- deterministic build/test results
- repository policy checks

Model-graded or trace-graded evaluations are valuable, but should begin as non-blocking quality regression signals rather than hard merge requirements.

### Separate Declaration From Evidence

PR metadata should answer "what the author claims was validated." Harness outputs should answer "what actually ran and what evidence was produced." Both are useful, but they should not be conflated.

### Review Findings Must Become A Durable Signal

If a bot or agent leaves actionable review findings in GitHub, Quickey should not depend on a human remembering to poll the PR manually. The repository should surface unresolved findings as either:

- a required check result, or
- a ruleset-enforced unresolved conversation block,

and ideally both.

## Recommended Architecture

### Layer 1: Governance Harness

Use a GitHub ruleset on `main` as the outer merge policy. The first iteration should require:

- pull requests for all changes to `main`
- at least 1 human approval
- approval of the most recent reviewable push, or stale approval dismissal
- required conversation resolution
- required status checks:
  - `CI / Build and Test`
  - `PR Metadata / Validate PR metadata`
  - `Review Gate / Validate review state`

This layer should remain GitHub-native rather than agent-managed. Agents may open PRs and remediate findings, but the repository itself should decide mergeability.

### Layer 2: Review Harness

Add a dedicated workflow that reads review state and fails when unresolved actionable findings remain.

Proposed components:

- `.github/workflows/review-gate.yml`
- `.github/scripts/validate-review-state.mjs`
- `.github/scripts/tests/review-state.test.mjs`

The script should query:

- PR `reviewDecision`
- `reviewThreads`
- thread resolution state (`isResolved`)
- thread freshness (`isOutdated`)
- file/line anchors for reporting

Initial policy:

- fail if `reviewDecision == CHANGES_REQUESTED`
- fail if any actionable thread is `isResolved == false` and `isOutdated == false`
- do not fail on outdated threads

For reviewer types, Quickey should treat both human and trusted bot findings as actionable if they are left in GitHub as unresolved inline review threads. Top-level comments that do not participate in a review thread should remain informational unless Quickey later adds an explicit parser for them.

The workflow output should:

- print a concise failure summary in logs
- write a GitHub step summary listing file, line, reviewer, and first-line finding text
- give maintainers a stable required check that can be protected by rulesets

### Layer 3: Runtime Harness

Quickey is runtime-sensitive, but not all runtime evidence belongs in hosted CI. The design should formalize two separate channels:

1. **Repository CI evidence**
   - deterministic tests and packaging checks that can run on GitHub Actions
2. **Manual macOS runtime evidence**
   - packaged-app validation, permissions/TCC checks, live event-path checks

Recommended additions:

- keep `.github/workflows/ci.yml` as the primary hosted CI
- optionally extend CI with deterministic shell-level coverage such as:
  - `bats scripts/e2e-lib.bats`
- add a local evidence-capture script:
  - `scripts/capture-runtime-validation.sh`

The evidence-capture script should produce a small markdown or JSON artifact that records:

- app artifact under test
- date/time and machine context
- commands executed
- pass/fail result for each runtime-sensitive check
- optional log file references

This artifact is not intended to become a required GitHub-hosted check in the first iteration. Instead, it provides a normalized way to attach truthful runtime evidence to PRs and handoff notes.

### Layer 4: Agent Evaluation Harness

Add a separate evaluation harness for agentic workflows. This layer should begin as nightly or manually triggered automation, not a merge gate.

Proposed components:

- `.github/workflows/agent-evals.yml`
- `.github/evals/` or `harness/agent-evals/`
- dataset fixtures for representative Quickey change tasks
- optional trace/grade adapters for external model evaluations

Recommended evaluation categories:

- PR metadata remediation
- review-thread remediation
- runtime-sensitive path classification
- Hyper vs standard route handling in E2E scripts
- required documentation updates (`README.md`, `AGENTS.md`, handoff notes) when policy changes

Recommended signals:

- deterministic repo checks first
- optional model-based graders or trace graders second

The first goal is workflow regression detection, not autonomous merge approval. If agent prompts, review bots, or automation policies regress, Quickey should catch that in nightly eval output before it manifests as repeated bad PR hygiene.

## Rollout Plan

### Phase 1: Governance Baseline

Deliverables:

- create a ruleset definition for `main`
- require PR, approval, latest-reviewable-push freshness, and conversation resolution
- mark current deterministic checks as required

Suggested repository additions:

- `.github/governance/main-ruleset.json`
- optional helper script to validate or apply the ruleset configuration

Success criteria:

- `main` can no longer be merged through green CI alone when conversation threads remain unresolved
- Quickey's merge policy is visible in repository settings and documented in-repo

### Phase 2: Review Gate

Deliverables:

- add `review-gate.yml`
- add `validate-review-state.mjs`
- add tests for thread classification and summary rendering

Success criteria:

- a PR with unresolved actionable review threads fails `Review Gate / Validate review state`
- a PR with only resolved or outdated threads passes
- maintainers can understand failures from the check summary without opening raw API payloads

### Phase 3: Runtime Evidence Standardization

Deliverables:

- add `scripts/capture-runtime-validation.sh`
- document how manual macOS runtime evidence should be captured and attached
- optionally add deterministic `bats` coverage into hosted CI

Success criteria:

- runtime-sensitive PRs have a consistent evidence format
- repository policy clearly distinguishes metadata declaration from actual runtime evidence

### Phase 4: Agent Eval Harness

Deliverables:

- create eval dataset structure
- add nightly or `workflow_dispatch` evaluation workflow
- publish summary artifacts for regressions

Success criteria:

- Quickey can detect regressions in agent-assisted review-remediation workflows
- model availability issues do not block ordinary PR merges

## File-Level Plan Surface

This design is expected to touch the following repository areas in later implementation phases.

### New Files

- `.github/workflows/review-gate.yml`
- `.github/scripts/validate-review-state.mjs`
- `.github/scripts/tests/review-state.test.mjs`
- `.github/governance/main-ruleset.json`
- `scripts/capture-runtime-validation.sh`
- `.github/workflows/agent-evals.yml`
- `.github/evals/README.md`

### Existing Files To Update

- `.github/workflows/ci.yml`
- `docs/github-automation.md`
- `docs/loop-job-guide.md`
- `docs/loop-prompt.md`
- `AGENTS.md`

## Policy Decisions

### What Should Be Required For Merge

Required immediately:

- human approval
- resolved review conversations
- deterministic review-state check
- deterministic CI / metadata checks

Not required initially:

- external LLM-based grading
- nightly eval results
- manual macOS runtime validation for every development-stage PR

This preserves Quickey's current development-stage policy while strengthening governance around review state and merge safety.

### What Counts As Actionable Review Feedback

Initial actionable set:

- unresolved inline review threads from humans
- unresolved inline review threads from trusted automation or bots
- GitHub `CHANGES_REQUESTED`

Deferred for a later phase:

- parsing top-level PR comments into merge-blocking findings
- prioritization heuristics that block only selected severities
- confidence-score filtering across heterogeneous bot review systems

## Risks

- If the review gate is too strict about non-actionable bot chatter, it can create merge friction.
- If the repository enables required conversation resolution without documenting expected maintainer behavior, contributors may be confused about why a green CI PR still cannot merge.
- If external-model evals are promoted too early into required checks, merge reliability and cost can degrade.
- If runtime evidence capture is too heavyweight, contributors may bypass it instead of using it.

## Mitigations

- Start with review-thread semantics already modeled by GitHub (`isResolved`, `isOutdated`, `CHANGES_REQUESTED`) instead of inventing custom severity parsing immediately.
- Keep agent evals non-blocking until Quickey has enough historical signal to trust them.
- Document the governance flow in the same repository where contributors work, instead of relying on external setup knowledge.
- Preserve Quickey's explicit `macOS runtime validation pending` vs `complete` policy so governance changes do not accidentally imply stronger runtime guarantees than the repository can provide.

## Acceptance Criteria

This design is successful when:

- Quickey can no longer merge a PR with unresolved actionable review findings by accident.
- Required merge gates are deterministic and repository-native.
- Runtime-sensitive validation remains truthful and evidence-based.
- Agent-assisted review remediation can be regression-tested without becoming a brittle per-PR dependency.

