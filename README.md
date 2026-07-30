<picture>
  <source media="(prefers-color-scheme: dark)" srcset="banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="banner-light.svg">
  <img alt="Looper" src="banner-dark.svg" width="480">
</picture>

Looper turns a PRD or bounded spec into a reviewed story queue, then implements, validates, reviews, and commits one story at a time.

Its orchestration is intentionally small. Agents do the planning and coding; Looper enforces source freshness, fixed call budgets, harness-owned proof, adversarial review, and commits.

```text
complete-source plan → broad plan review → [one revision → focused closure]
    → stories.json
    → implement story → validate → broad code review
    → [one remediation → validate → focused closure] → commit
```

## Quick start

```bash
./install.sh

# Prepare and inspect the queue before coding.
looper prepare --spec tasks/theme-toggle.md
jq '.stories[] | {id, title, dependsOn, passes}' .looper/my-branch/stories.json
looper run

# Or prepare and begin immediately.
looper start --prd plans/dark-mode.md
```

Use `--prd` for a whole feature or product document and `--spec` for a bounded end-to-end task. The original path remains authoritative; Looper records its absolute path and hash and stops with `PLAN_STALE` if the file changes or disappears. It does not create a second source copy.

## Preparation

Preparation is a fixed sequence:

1. A read-only agent inspects the repository and plans the complete source.
2. An independent read-only agent adversarially reviews the complete plan.
3. If approved, Looper publishes `stories.json`.
4. If changes are requested, the planner produces one complete focused revision and the reviewer performs one finding-ID-scoped closure review.

The happy path uses exactly two model calls. The revision path uses exactly four. A timeout or malformed-output repair consumes the same absolute four-call budget; Looper stops if it cannot fit both revision and closure. There is no third round.

`stories.json` is both the approved execution plan and visible queue. Every story already contains source references, scope and non-goals, acceptance criteria with concrete proof commands, dependencies, likely files, ordered steps, architecture notes, risks, assumptions, and a disappointment check. Looper changes only `passes` as work completes.

## Execution

For each dependency-ready story, Looper:

1. Requires a clean worktree and locks the story's material hash.
2. Invokes the implementation agent immediately—there is no per-story planner.
3. Runs proof commands itself and persists the logs.
4. Invokes one independent broad code review.
5. If necessary, permits one remediation, reruns validation, and invokes one focused closure review.
6. Commits and sets `passes: true` only after approval.

The happy path is two model calls per story; remediation is four. Closure rejection is terminal for that run. A failed commit remains resumable without rerunning agents.

Successful validation is cached by exact Git tree hash and exact command. An identical command is never rerun against an identical tree. Implementation agents may run targeted tests while coding, but the harness's persisted result is authoritative and is supplied to review.

## State and observability

```text
.looper/<branch>/
  stories.json                 # approved plans + passes queue
  state.json                   # current phase, lock, budgets, timing
  preparation/
    proposal.json
    review.json
    revision.json              # only when requested
    closure.json               # only when requested
  reviews/
    <story>-validation.json
    <story>-review.json
    <story>-closure.json        # only when requested
  validation-cache.json
  logs/
```

`state.json` is the only mutable orchestration record; it does not duplicate the story queue. Old Looper state is intentionally unsupported and must be discarded and prepared again.

```bash
looper watch          # phase, elapsed time, calls, repairs, story/validation progress
looper watch --raw    # follow the active agent log
```

Optional project addenda live beside `stories.json`:

- `prompt.shared.md`
- `prompt.implementer.md`
- `prompt.reviewer.md`

They extend the built-in prompts and should contain only concise project-specific guidance.

## Commands

```text
looper prepare (--prd|--spec) PATH
looper start (--prd|--spec) PATH
looper run [max_iterations]
looper [max_iterations]
looper watch [--raw]
```

Completed preparation boundaries and active story phases resume from persisted artifacts. Material source drift, a changed locked story, dirty story start, exhausted budget, failed focused closure, or unknown old state stops with a concise diagnostic rather than silently replanning.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `LOOPER_ENV_FILE` | `~/.config/looper/env` | Global environment file; `./.looper/env` is also read |
| `LOOPER_STATE_DIR` | `.looper/<branch>` | Override the state directory |
| `LOOPER_IMPLEMENTATION_AGENT` | `claude` | Planning, implementation, and remediation: `claude`, `codex`, or `opencode` |
| `LOOPER_REVIEW_AGENT` | `codex` | Broad and closure review: `claude`, `codex`, or `opencode` |
| `LOOPER_IMPLEMENTATION_MODEL` | opencode default | opencode planning/implementation model |
| `LOOPER_REVIEW_MODEL` | opencode default | opencode review model |
| `LOOPER_VALIDATION_COMMANDS` | empty | Newline-separated additional harness commands |
| `LOOPER_AGENT_TIMEOUT_SECONDS` | `600` | Timeout for each model call |

Only opencode uses the model variables. Install the CLIs selected by your agent configuration, plus `git` and `jq`. See `templates/looper.env.example` for a minimal environment file.

## Repository files

| File | Purpose |
|---|---|
| `bin/looper` | Single orchestration script |
| `templates/execution-plan.schema.json` | Complete plan and revision output |
| `templates/review.schema.json` | Broad plan/code review output |
| `templates/closure.schema.json` | Finding-scoped closure output |
| `templates/prompt.*.md` | Built-in agent roles |
| `tests/integration.sh` | End-to-end behavioral contract |

## Verification

```bash
bash tests/integration.sh
```

Based on [Ralph Loop](https://github.com/snarktank/ralph) by Ryan Carson.
