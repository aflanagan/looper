<picture>
  <source media="(prefers-color-scheme: dark)" srcset="banner-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="banner-light.svg">
  <img alt="Looper" src="banner-dark.svg" width="480">
</picture>

Automate multi-story implementation by pairing Claude Code (implementer) with Codex (reviewer) in a loop until both agree on the code. Based on the [Ralph Loop](https://ghuntley.com/loop/) pattern (implement → review → remediate).

Give Looper a PRD, and it breaks it into dependency-ordered stories, then runs Claude Code against each one while Codex reviews. If Codex requests changes, Claude remediates. This continues until Codex approves or max review rounds are hit. Then it commits and moves to the next story.

```
PRD → Stories → [ Claude implements → Codex reviews → remediate? ] → commit → next story
```

## How It Works

1. Create a PRD with dependency-ordered stories
2. Convert it to `.looper/prd.json` using the `/looper` slash command
3. Run `looper`
4. For each story:
   - Claude implements the story and runs quality checks
   - Codex reviews uncommitted changes
   - If Codex requests changes, Claude remediates and Codex re-reviews (up to `LOOPER_REVIEW_MAX_ROUNDS`, default 3)
   - On approval, Looper commits and marks the story passed
5. Stops when all stories pass or max iterations is reached

> **What happens if they can't agree?** After exhausting review rounds, Looper moves on to the next story without committing. Check `.looper/progress/` for details on what went wrong.

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

- [Claude Code CLI](https://claude.ai/code)
- [Codex CLI](https://github.com/openai/codex)
- `jq`
- Git

> **Cost note:** Looper runs Claude Code and Codex in a loop — each story may consume multiple implementation + review cycles. Monitor your API usage, and use `LOOPER_REVIEW_MAX_ROUNDS` and iteration limits to constrain spend.

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

This creates `.looper/prd.json`. Example structure:

```json
{
  "stories": [
    {
      "id": "1",
      "title": "Add theme toggle component",
      "description": "Create a toggle switch in the header...",
      "dependencies": [],
      "passes": false,
      "notes": []
    },
    {
      "id": "2",
      "title": "Implement CSS custom properties for theming",
      "dependencies": ["1"],
      "passes": false,
      "notes": []
    }
  ]
}
```

### 3. (Optional) Add project config

Create `.looper/config.md` with project-specific quality checks and context. For example:

```markdown
## Quality Checks
- Always run `npm test` and `npm run lint` before marking a story complete
- Ensure all new components have unit tests

## Context
- This project uses React 18 with TypeScript
- Styles use Tailwind CSS
```

### 4. Run Looper

```bash
looper      # default: 10 iterations
looper 20   # custom iteration limit
```

## Project Structure

```
.looper/
  ├── prd.json                 # Required: stories and task state
  ├── config.md                # Optional: project-specific quality checks and context
  ├── prompt.local.md          # Optional: project-specific prompt addendum
  ├── review-prompt.md         # Optional: override the default review prompt
  ├── progress/                # Auto-created: branch-scoped iteration logs
  │   └── <branch-slug>.txt   #   (excluded from auto-commits)
  └── reviews/                 # Auto-created: review artifacts per story
      └── <branch>/<story>/    #   (excluded from auto-commits)
```

Looper only commits after Codex returns `APPROVED`. On approval, it appends a review-closure summary to the progress log and a short outcome note to the story's entry in `prd.json`.

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `LOOPER_STATE_DIR` | `.looper` | Override the state directory path |
| `LOOPER_REVIEW_MAX_ROUNDS` | `3` | Max review/remediation cycles per story |
| `LOOPER_REVIEW_PROMPT_FILE` | `templates/review-prompt.md` | Override review prompt path |
| `LOOPER_REVIEW_SCHEMA_FILE` | `templates/codex-review-schema.json` | Override review schema path |

## Files

| File | Purpose |
|------|---------|
| `bin/looper` | Main CLI orchestrator |
| `templates/looper-prompt.md` | Base Claude implementation prompt |
| `templates/review-prompt.md` | Base review prompt |
| `templates/codex-review-schema.json` | Structured output schema for Codex review |
| `skills/looper/SKILL.md` | `/looper` slash command (PRD-to-JSON conversion) |
| `skills/prd/SKILL.md` | `/prd` slash command (PRD generation) |

## Based On

[Ralph Loop](https://github.com/snarktank/ralph) by Ryan Carson.

## License

<!-- TODO: Add license -->
