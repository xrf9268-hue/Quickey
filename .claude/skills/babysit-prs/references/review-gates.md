# Review Gates Reference

Three review tools with different output destinations. Treating them uniformly leads to missed findings.

## Tool Comparison

| Tool | Output | Persistence | Threshold | Check Command |
|------|--------|------------|-----------|---------------|
| `/code-review` | PR comments | Durable across iterations | Confidence ≥ 80 | `gh pr view <N> --comments` |
| `@chatgpt-codex-connector[bot]` | PR comments | Durable, arrives async | P0/P1/P2 priority tags | `gh pr view <N> --comments` |
| `/codex:review` | Session memory only | Session-scoped, not on PR | Critical/non-critical | `/codex:status` + `/codex:result` |

## Usage Rules

- **Invocation limit**: Max 2 invocations per tool per PR per iteration.
- **Parallelization**: Fire `/codex:review --base main --background` first (async), then `/code-review` (sync), then check `/codex:status`.
- **Must-fix**: `/code-review` ≥ 80 confidence, P0/P1 bot findings, critical `/codex:review` findings.
- **Evaluate**: P2+ bot findings, minor `/codex:review` findings — fix if easy, otherwise comment why skipped.

## Degraded Tooling

If a review tool is unavailable in the current session:

1. Comment on the PR: "Review gate `/code-review` (or `/codex:review`) was unavailable in this session."
2. Leave the PR open — do not treat a missing gate as a clean pass.
3. The next iteration or a human reviewer will pick up the missing gate.

## Availability Check

During Session Init, determine availability by checking whether the commands are recognized. Cache the result in session memory for the duration of the session.
