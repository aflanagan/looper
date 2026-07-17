<picture>
  <source media="(prefers-color-scheme: dark)" srcset="banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="banner-light.svg">
  <img alt="Looper" src="banner-dark.svg" width="480">
</picture>
<br /><br />
Automate multi-story implementation by pairing an implementation agent with a review agent in a loop until both agree on the code.
<br /><br />
Give Looper a PRD, and it breaks it into dependency-ordered stories, then runs an implementation agent against each one while a review agent checks the uncommitted diff. If review requests changes, Looper runs remediation and re-review until approval or the max review rounds are hit. Then it commits and moves to the next story.
<br /><br />

```
PRD → Stories → [ implementation → review → remediate? ] → commit → next story
```

## How It Works

1. Create a PRD with dependency-ordered stories
2. Convert it to `.looper/<branch-name>/prd.json` using the `/looper` slash command (or create `.looper/<branch-name>/` manually and add your own `prd.md`/`prd.json`)
3. Run `looper`
4. For each story:
   - The implementation agent implements the story and runs quality checks
   - The review agent reviews uncommitted changes
   - If review requests changes, Looper runs remediation and re-review (up to `LOOPER_REVIEW_MAX_ROUNDS`, default 5)
   - On approval, Looper commits and marks the story passed
5. Stops when all stories pass or max iterations is reached

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

> **Cost note:** Looper runs one implementation agent and one review agent in a loop. Each story may consume multiple implementation + review cycles. Monitor your API usage, and use `LOOPER_REVIEW_MAX_ROUNDS` and iteration limits to constrain spend. If the review cap is exhausted, Looper stops instead of silently restarting the same story.

## Usage

### 1. Create a PRD

In Claude Code, use the `/prd` slash command:

```
/prd add dark mode to the dashboard
```

### 2. Convert to Looper format

Still in Claude Code, convert the PRD to the structured JSON format Looper expects:

```
/looper convert this prd
```

This creates `.looper/<branch-name>/prd.json`. The `/looper` skill now chooses a semantic 2-3 letter story prefix automatically and states it in the response. Example structure:

```json
{
  "project": "Dashboard",
  "branchName": "looper/dark-mode",
  "description": "Add dark mode support to the dashboard UI.",
  "userStories": [
    {
      "id": "UI-001",
      "title": "Add theme toggle component",
      "description": "As a dashboard user, I want a theme toggle so that I can switch between light and dark mode.",
      "acceptanceCriteria": [
        "Header shows a theme toggle control.",
        "Theme preference persists across reloads.",
        "Relevant tests pass."
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "UI-002",
      "title": "Implement CSS custom properties for theming",
      "description": "As a dashboard user, I want all core surfaces themed so that dark mode is usable end to end.",
      "acceptanceCriteria": [
        "Core dashboard surfaces render correctly in both themes.",
        "Theme variables are applied consistently.",
        "Relevant tests pass."
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### 3. (Optional) Add project prompt addenda

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

### Manual bootstrap (without `/prd` or `/looper`)

If you prefer to start manually:

1. Create `.looper/<branch-name>/` (usually from your current git branch)
2. Add your PRD markdown as `.looper/<branch-name>/prd.md`
3. Add `.looper/<branch-name>/prd.json` in Looper story format
4. Optionally add `.looper/<branch-name>/prompt.shared.md`
5. Optionally add `.looper/<branch-name>/prompt.implementer.md`
6. Optionally add `.looper/<branch-name>/prompt.reviewer.md`
7. Run `looper`

`prd.md` is optional for Looper runtime, but recommended as source context you can keep alongside `prd.json`.

### 4. Run Looper

```bash
looper      # default: 10 iterations
looper 20   # custom iteration limit
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
      ├── prd.md               # Optional: source PRD markdown
      ├── prd.json             # Required: stories and task state
      ├── prompt.shared.md     # Optional: prompt guidance shared by both agents
      ├── prompt.implementer.md # Optional: implementation-only addendum
      ├── prompt.reviewer.md   # Optional: review-only addendum
      ├── progress.txt         # Auto-created: iteration log (excluded from auto-commits)
      └── stories/             # Auto-created: one current state file per story (excluded from auto-commits)
          └── <story-id>.md
```

`<branch-name>` defaults to the current git branch slug (with `codex/` and `looper/` prefixes stripped). Set `LOOPER_STATE_DIR` to override the full state path.

Older `prompt.local.md` and `review-prompt.md` files are no longer read. Move any reusable content into the new addenda files.

Looper only commits after the review agent returns `APPROVED`. On approval, it appends a review-closure summary to the progress log, updates the active story file under `stories/`, and writes a short outcome note to the story's entry in `prd.json`.

Active run metadata and watch logs are kept under your temp directory, not under `.looper/`. `looper watch` defaults to a compact transcript and supports `--verbose` and `--raw` (`--full-logs` alias) when you want more detail.

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `LOOPER_STATE_DIR` | `.looper/<branch-name>` | Override the full state directory path |
| `LOOPER_IMPLEMENTATION_AGENT` | `claude` | Agent for implementation and remediation (`claude`, `codex`, or `opencode`) |
| `LOOPER_REVIEW_AGENT` | `codex` | Agent for review (`claude`, `codex`, or `opencode`) |
| `LOOPER_IMPLEMENTATION_MODEL` | _(opencode default)_ | Model for the `opencode` implementation agent, as `provider/model` (e.g. `xai/grok-4.5`). Ignored by `claude`/`codex`. |
| `LOOPER_REVIEW_MODEL` | _(opencode default)_ | Model for the `opencode` review agent, as `provider/model` (e.g. `anthropic/claude-sonnet-4-20250514`). Ignored by `claude`/`codex`. |
| `LOOPER_REVIEW_MAX_ROUNDS` | `5` | Max review/remediation cycles per story before Looper exits non-zero |
| `LOOPER_KEEP_LOGS` | `0` | Preserve temp run logs on failure when set to `1` |
| `LOOPER_IMPLEMENTATION_PROMPT_FILE` | `templates/prompt.implementer.md` | Override the base implementation prompt template |
| `LOOPER_REVIEW_PROMPT_FILE` | `templates/prompt.reviewer.md` | Override the base review prompt template |
| `LOOPER_REVIEW_SCHEMA_FILE` | `templates/codex-review-schema.json` | Override review schema path |

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
| `templates/codex-review-schema.json` | Structured output schema for the review agent (Codex native; injected into the prompt for opencode) |
| `skills/looper/SKILL.md` | `/looper` slash command (PRD-to-JSON conversion) |
| `skills/prd/SKILL.md` | `/prd` slash command (PRD generation) |

## Based On

[Ralph Loop](https://github.com/snarktank/ralph) by Ryan Carson.

## License

<!-- TODO: Add license -->
