<picture>
  <source media="(prefers-color-scheme: dark)" srcset="banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="banner-light.svg">
  <img alt="Looper" src="banner-dark.svg" width="480">
</picture>
<br /><br />
Automate multi-story implementation with locked story contracts, adversarially reviewed execution plans, harness-owned validation, and independent code review.
<br /><br />
Give Looper an authoritative PRD or bounded task spec. It snapshots the source, creates dependency-aware story contracts, and has a separate adversarial agent review the decomposition before anything is implemented. For each approved story, Looper then snapshots the contract, generates and reviews a codebase-grounded plan, implements, validates, reviews the diff, and makes one final commit.
<br /><br />

```
PRD or bounded spec → complete round-1 proposal → validate/repair author output
    → broad adversarial decomposition review
    → [ stable-ID revision → deterministic reconstruction → focused closure review ]
    → approved story contracts → lock one story
    → [ read-only plan → adversarial plan review → revise? ]
    → [ implementation → harness checks → code review → remediate? ]
    → one final commit → next story
```

## Quick Start

Choose the input by scope; both routes enter the same decomposition, planning, implementation, validation, and review pipeline.

| Starting point | Prepare and inspect first | Prepare and run end to end |
|---|---|---|
| Whole-feature or multi-story PRD | `looper prepare --prd plans/feature.md` | `looper start --prd plans/feature.md` |
| Bounded end-to-end task spec | `looper prepare --spec tasks/task.md` | `looper start --spec tasks/task.md` |

`prepare` snapshots the source, decomposes it into independently reviewed stories, and stops after publishing approved `stories.json`. Run `looper` afterward to execute those stories. `start` performs that same preparation and immediately continues into story execution; it is not a separate or weaker workflow.

```bash
# Inspect the generated stories before implementation
looper prepare --spec tasks/theme-toggle.md
jq '.stories[] | {id, title, dependsOn}' .looper/my-branch/stories.json
looper

# Or run a complete PRD without stopping after preparation
looper start --prd plans/dark-mode.md
```

Rerunning the same `prepare` or `start` command resumes from the persisted boundary. Correctable author/reviewer output defects and bounded timeouts recover automatically; Looper asks for human input only for genuine source contradictions or material product choices. Each run uses the executable, prompts, and schemas captured when preparation first began, so updating the live Looper checkout does not alter an in-progress run.

## How It Works

1. Create an authoritative PRD or bounded task spec.
2. Run `looper prepare --prd PATH` or `looper prepare --spec PATH`. Looper snapshots it as immutable `source.md`, proposes stories, and adversarially reviews their source coverage and boundaries.
3. Looper validates the complete first-round decomposition before broad review. Later `CHANGES_REQUESTED` rounds return stable-ID revision operations against the last reviewed proposal; Looper applies them deterministically and validates the reconstructed complete proposal before focused closure review.
4. Correctable author- and reviewer-output defects get separate bounded same-round repairs. Transport/API failures retain their original diagnostics, author and reviewer timeouts receive bounded increased-timeout retries, and exhausted content repairs stop in distinct non-human invalid-output states.
5. The first preparation captures the Looper executable and every resolved prompt/schema—including environment overrides—under the run state. Every later phase verifies and executes that pinned runtime, so a live checkout update cannot reinterpret persisted state.
6. Genuine contradictions or material ambiguity stop in `NEEDS_HUMAN`. Mechanically correctable findings at the configured review limit stop in resumable `CORRECTABLE_REVIEW_LIMIT` rather than a human state.
7. On approval, Looper atomically publishes schema-v3 `.looper/<branch-name>/stories.json`.
8. Run `looper`. A new story starts only from a clean worktree outside Looper state. (`looper start` combines preparation and execution.)
9. For each runnable story:
   - Looper creates an immutable contract snapshot and active-story lock.
   - The implementation agent plans in read-only mode; the review agent adversarially reviews the plan for up to `LOOPER_PLAN_REVIEW_MAX_ROUNDS` (default 3).
   - An approved `SPLIT_REQUIRED` or `BLOCKED` disposition stops before code. Approved replacement stories can recover a terminal story through their `replaces` lineage.
   - The implementation agent implements the approved plan.
   - Looper runs configured proof commands itself, then the review agent reviews the uncommitted diff.
   - If review requests changes, Looper runs remediation and re-review (up to `LOOPER_REVIEW_MAX_ROUNDS`, default 5)
   - On approval, Looper commits once and marks the story passed atomically. A failed commit remains retryable and never marks the story passed.
10. Stops when all stories pass or max iterations is reached

> **What happens if they can't agree?** After exhausting review rounds for a story, Looper stops with a non-zero exit and leaves the story unresolved. The next manual rerun resumes remediation for that same story.

## Installation

```bash
git clone https://github.com/aflanagan/looper.git
cd looper
./install.sh
```

`install.sh` sets up:
- `~/bin/looper` — the CLI orchestrator
- `~/.claude/skills/{looper,prd}` — custom slash commands for Claude Code (`/looper`, `/prd`)
- `~/.codex/skills/{looper,prd}` — skills for Codex

Make sure `~/bin` is in your `PATH`:

```bash
export PATH="$HOME/bin:$PATH"
```

## Requirements

- [Claude Code CLI](https://claude.ai/code) — for the `claude` agent
- [Codex CLI](https://github.com/openai/codex) — for the `codex` agent
- [opencode](https://opencode.ai) — optional, for the `opencode` agent (run any Models.dev model — Grok, Gemini, GPT, etc.)
- `jq`
- Git

You only need the CLI(s) for the agents you actually use. To run Claude on implementation and Codex on review (the default), you need both of those. To drive any other model, install `opencode` (`npm i -g opencode-ai`) and use the `opencode` agent — see [Using any model](#using-any-model).

> **Cost note:** Source preparation adds a bounded decomposition/review loop, and each story adds plan generation/review before implementation/review. The defaults are three decomposition-review rounds, up to three same-round author repairs and three independent reviewer repairs, three planning rounds, and five code-review rounds. Every phase is persisted for exact-boundary resume.

## Usage

### 1. Prepare a source

Use `/prd` to author a whole-feature product document, or bring any bounded end-to-end Markdown spec. Then choose exactly one source kind:

```bash
looper prepare --prd plans/dark-mode.md
looper prepare --spec tasks/theme-toggle.md
```

The source is copied byte-for-byte to `source.md` and bound to its kind and SHA-256 hash. The implementation agent creates one complete first-round proposal in read-only mode, starts at the supplied repository root, and is explicitly prohibited from wider filesystem traversal. This is a command/prompt boundary plus write detection, not an OS-level filesystem read boundary. Later rounds return only stable-ID add/replace/remove operations. Looper applies those operations to the hash-locked base without array-index patching, preserves unaffected ordering/content, and runs the same complete semantic validator over the reconstructed proposal. Correctable failures are returned with machine-readable diagnostics without consuming a review round. Only an independently approved complete proposal becomes `stories.json`; terminal and resumable stops preserve their source, base, review, revision, transport, and diagnostic hashes.

Use `start` to prepare and immediately enter the same execution engine:

```bash
looper start --spec tasks/theme-toggle.md
```

### 2. (Optional) Add project prompt addenda

Looper always starts from its built-in implementation and review templates. You can extend them with up to three project-level addenda under `.looper/<branch-name>/`:

- `prompt.shared.md` for instructions both agents should follow
- `prompt.implementer.md` for implementation-only guidance
- `prompt.reviewer.md` for review-only guidance

Example:

```markdown
# prompt.shared.md
## Required Checks
- Always run `npm test` and `npm run lint` before finishing a story

## Project Context
- This project uses React 18 with TypeScript

# prompt.implementer.md
## Implementation Notes
- New components must include unit tests

# prompt.reviewer.md
## Review Priorities
- Be strict about state persistence regressions and missing tests
```

Keep these files short. They should contain project-specific deltas, not copies of Looper's default prompts.

Prompt assembly order is:
1. base shared template: `templates/prompt.shared.md`
2. base role template: `templates/prompt.implementer.md` or `templates/prompt.reviewer.md`
3. project shared addendum: `.looper/<branch>/prompt.shared.md`
4. project role addendum: `.looper/<branch>/prompt.implementer.md` or `.looper/<branch>/prompt.reviewer.md`
5. runtime context appended by Looper

### 3. Run or resume Looper

```bash
looper          # alias for: looper run (10 iterations)
looper 20       # alias for: looper run 20
looper run 20   # explicit resume
```

To follow an active run in another terminal:

```bash
looper watch             # compact transcript
looper watch --verbose   # transcript plus tool details
looper watch --raw       # raw underlying log stream
```

## Project Structure

```
.looper/
  └── <branch-name>/
      ├── source.md            # Immutable authoritative PRD or bounded spec
      ├── stories.json         # Reviewed story contracts and execution state
      ├── decomposition/       # Persisted proposal/review rounds and approval
      │   ├── state.json
      │   ├── proposal-N-attempt-A.json
      │   ├── proposal-N-diagnostic-A.json
      │   ├── revision-N-attempt-A.json
      │   ├── revision-N-diagnostic-A.json
      │   ├── proposal-N-attempt-A-agent-T.json
      │   ├── proposal-N-attempt-A-raw-T.log
      │   ├── proposal-N.json
      │   ├── review-N-attempt-A.json
      │   ├── review-N-diagnostic-A.json
      │   ├── review-N.json
      │   └── approved.json
      ├── runtime/             # Hash-verified executable + prompt/schema snapshot
      │   ├── manifest.json
      │   ├── bin/looper
      │   └── templates/
      ├── prompt.shared.md     # Optional: prompt guidance shared by both agents
      ├── prompt.implementer.md # Optional: implementation-only addendum
      ├── prompt.reviewer.md   # Optional: review-only addendum
      ├── progress.txt         # Auto-created: iteration log (excluded from auto-commits)
      ├── active-story.json   # Current lock and explicit resume phase (excluded from auto-commits)
      └── stories/             # Auto-created: one current state file per story (excluded from auto-commits)
          ├── <story-id>.md
          ├── <story-id>.contract.json
          ├── <story-id>.planning.json
          ├── <story-id>.plan-N.json
          ├── <story-id>.plan-review-N.json
          ├── <story-id>.approved-plan.json
          └── <story-id>.validation.json
```

`<branch-name>` defaults to the current git branch slug (with `codex/` and `looper/` prefixes stripped). Set `LOOPER_STATE_DIR` to override the full state path.

Older `prompt.local.md` and `review-prompt.md` files are no longer read. Move any reusable content into the new addenda files.

Looper only commits after the code-review agent returns `APPROVED`. On approval, it appends a review-closure summary to the progress log, updates the active story file under `stories/`, and writes a short outcome note to the story's entry in `stories.json`.

Schema v3 is intentionally breaking and has no legacy schema compatibility. Once a story ID has a locked contract, Looper never overwrites it; materially revised work needs a new story ID and `replaces` lineage when appropriate.

Active run metadata and watch logs are kept under your temp directory, not under `.looper/`. `looper watch` defaults to a compact transcript and supports `--verbose` and `--raw` (`--full-logs` alias) when you want more detail.

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `LOOPER_ENV_FILE` | `~/.config/looper/env` | Global env file auto-sourced at startup (also sources `./.looper/env` if present). Holds `LOOPER_*` config and/or provider keys. See [Config via an env file](#config-via-an-env-file). |
| `LOOPER_STATE_DIR` | `.looper/<branch-name>` | Override the full state directory path |
| `LOOPER_IMPLEMENTATION_AGENT` | `claude` | Agent for implementation and remediation (`claude`, `codex`, or `opencode`) |
| `LOOPER_REVIEW_AGENT` | `codex` | Agent for review (`claude`, `codex`, or `opencode`) |
| `LOOPER_IMPLEMENTATION_MODEL` | _(opencode default)_ | Model for the `opencode` implementation agent, as `provider/model` (e.g. `xai/grok-4.5`). Ignored by `claude`/`codex`. |
| `LOOPER_REVIEW_MODEL` | _(opencode default)_ | Model for the `opencode` review agent, as `provider/model` (e.g. `anthropic/claude-sonnet-4-20250514`). Ignored by `claude`/`codex`. |
| `LOOPER_REVIEW_MAX_ROUNDS` | `5` | Max review/remediation cycles per story before Looper exits non-zero |
| `LOOPER_PLAN_REVIEW_MAX_ROUNDS` | `3` | Max persisted plan/review cycles before implementation is blocked |
| `LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS` | `3` | Max persisted source decomposition/review cycles before mechanically correctable findings pause in `CORRECTABLE_REVIEW_LIMIT` |
| `LOOPER_DECOMPOSITION_OUTPUT_REPAIR_MAX_ATTEMPTS` | `3` | Max same-round decomposer repairs after an invalid author output before `DECOMPOSITION_OUTPUT_INVALID` |
| `LOOPER_DECOMPOSITION_REVIEW_OUTPUT_REPAIR_MAX_ATTEMPTS` | `3` | Max same-round reviewer repairs after invalid reviewer output before `DECOMPOSITION_REVIEW_OUTPUT_INVALID` |
| `LOOPER_DECOMPOSITION_AGENT_TIMEOUT_SECONDS` | `600` | Base per-invocation timeout for read-only decomposition author and reviewer agents |
| `LOOPER_DECOMPOSITION_TIMEOUT_MAX_RETRIES` | `1` | Bounded author/reviewer timeout retries; each retry increases the timeout without consuming a review/content-repair round |
| `LOOPER_VALIDATION_COMMANDS` | _(empty)_ | Optional newline-separated harness commands; story proof-expectation commands are also run |
| `LOOPER_KEEP_LOGS` | `0` | Preserve temp run logs on failure when set to `1` |
| `LOOPER_IMPLEMENTATION_PROMPT_FILE` | `templates/prompt.implementer.md` | Override the base implementation prompt template |
| `LOOPER_REVIEW_PROMPT_FILE` | `templates/prompt.reviewer.md` | Override the base review prompt template |
| `LOOPER_REVIEW_SCHEMA_FILE` | `templates/codex-review-schema.json` | Override review schema path |
| `LOOPER_PLANNER_PROMPT_FILE` | `templates/prompt.planner.md` | Override the read-only planner prompt |
| `LOOPER_PLAN_REVIEW_PROMPT_FILE` | `templates/prompt.plan-reviewer.md` | Override the adversarial plan-review prompt |
| `LOOPER_DECOMPOSER_PROMPT_FILE` | `templates/prompt.decomposer.md` | Override the read-only source-decomposer prompt |
| `LOOPER_DECOMPOSITION_REVISER_PROMPT_FILE` | `templates/prompt.decomposition-reviser.md` | Override the stable-ID late-round revision prompt |
| `LOOPER_DECOMPOSITION_REVIEW_PROMPT_FILE` | `templates/prompt.decomposition-reviewer.md` | Override the adversarial decomposition-review prompt |
| `LOOPER_DECOMPOSITION_REVISION_SCHEMA_FILE` | `templates/codex-decomposition-revision-schema.json` | Override the stable-ID revision structured-output schema |

## Using any model

Looper ships with three interchangeable agents. `claude` and `codex` are pinned to their own CLIs, but **`opencode` decouples the harness from the model** — pick any model from [Models.dev](https://models.dev) (Grok, Gemini, GPT, Claude, local models, …) by setting a single environment variable. No per-model wiring required.

### Setup

1. Install opencode: `npm i -g opencode-ai`
2. Authenticate the provider(s) you want to use: `opencode auth login` (stores keys in `~/.local/share/opencode/auth.json`). Do this once per provider.

### Select a model

Set the agent to `opencode` and name the model as `provider/model`:

```bash
# Grok on both implementation and review
LOOPER_IMPLEMENTATION_AGENT=opencode LOOPER_IMPLEMENTATION_MODEL=xai/grok-4.5 \
LOOPER_REVIEW_AGENT=opencode        LOOPER_REVIEW_MODEL=xai/grok-4.5 \
looper
```

Mix and match freely — the implementation and review agents are independent, so you can pair any two models (or mix opencode with claude/codex):

```bash
# Implement with Gemini, review with Claude — both via opencode
LOOPER_IMPLEMENTATION_AGENT=opencode LOOPER_IMPLEMENTATION_MODEL=google/gemini-2.5-pro \
LOOPER_REVIEW_AGENT=opencode        LOOPER_REVIEW_MODEL=anthropic/claude-sonnet-4-20250514 \
looper

# Implement with Claude Code, review with Grok via opencode
LOOPER_IMPLEMENTATION_AGENT=claude \
LOOPER_REVIEW_AGENT=opencode LOOPER_REVIEW_MODEL=xai/grok-4.5 \
looper
```

If you omit `LOOPER_IMPLEMENTATION_MODEL` / `LOOPER_REVIEW_MODEL`, opencode uses its own configured default model.

### Config via an env file

Typing the agent/model prefix on every run gets old. Looper auto-sources an env file at startup so a run is just `looper`:

- **Global:** `~/.config/looper/env` (override the path with `LOOPER_ENV_FILE`)
- **Project-local:** `./.looper/env` (sourced if present; wins over the global file)

Both are optional. A file can hold `LOOPER_*` config **and** provider API keys — opencode reads keys like `XAI_API_KEY` / `ANTHROPIC_API_KEY` straight from the environment, so this becomes the single place for your setup (no `opencode auth login` step required, and no scattered per-provider files):

```bash
# ~/.config/looper/env
LOOPER_IMPLEMENTATION_AGENT=opencode
LOOPER_IMPLEMENTATION_MODEL=xai/grok-4.5
LOOPER_REVIEW_AGENT=opencode
LOOPER_REVIEW_MODEL=xai/grok-4.5
XAI_API_KEY=xai-...
```

Then just `looper`. Precedence: **anything already set in your shell wins** (so `LOOPER_REVIEW_MODEL=other looper` still overrides the file for a one-off), then project-local, then global. A starter template lives at [`templates/looper.env.example`](templates/looper.env.example).

> **Secrets:** the repo `.gitignore` excludes `.looper/env` and `looper.env` so keys never get committed. Prefer the global `~/.config/looper/env` (outside any repo) for API keys.

### How review works with opencode

The review agent must return JSON matching `templates/codex-review-schema.json`. opencode has no schema-constrained output mode, so Looper injects the schema into the review prompt as an output contract, then extracts and validates the returned JSON. If the model returns invalid or non-schema JSON, Looper runs **one repair round** asking for schema-valid JSON before failing the round. This keeps arbitrary models usable as reviewers without a native structured-output mode.

> **Tip:** Follow an opencode run with `looper watch` just like the other agents — opencode events stream into the same compact/verbose/raw transcript.

## Files

| File | Purpose |
|------|---------|
| `bin/looper` | Main CLI orchestrator |
| `templates/prompt.shared.md` | Base shared prompt context for both agents |
| `templates/prompt.implementer.md` | Base implementation prompt |
| `templates/prompt.reviewer.md` | Base review prompt |
| `templates/prompt.decomposer.md` | Source decomposition prompt |
| `templates/prompt.decomposition-reviser.md` | Stable-ID late-round decomposition revision prompt |
| `templates/prompt.decomposition-reviewer.md` | Adversarial source-decomposition review prompt |
| `templates/codex-decomposition-revision-schema.json` | Structured stable-ID revision contract |
| `templates/codex-review-schema.json` | Structured output schema for the review agent (Codex native; injected into the prompt for opencode) |
| `templates/stories.schema.json` | Published schema-v3 story-list contract |
| `skills/looper/SKILL.md` | `/looper` source preparation and execution workflow |
| `skills/prd/SKILL.md` | `/prd` slash command (PRD generation) |

## Based On

[Ralph Loop](https://github.com/snarktank/ralph) by Ryan Carson.

## License

<!-- TODO: Add license -->
