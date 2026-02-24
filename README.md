# Looper

A long running loop harness for Claude Code and Codex. Looper takes a PRD, breaks it down to stories, and then runs a [Ralph Loop](https://ghuntley.com/loop/) to implement one story at a time with Claude Code. Codex then reviews the code and requests changes. Claude will either rebut the requests or implement them. This process continues until both agree on the implementation.

## How It Works

1. Create a PRD with dependency-ordered stories
2. Convert it to `.looper/prd.json` using `/looper`
3. Run `looper`
4. Each iteration:
   - Claude implements one story and runs quality checks
   - Codex reviews uncommitted changes
   - If review requests changes, Claude remediates and Codex re-reviews (up to max rounds)
   - On approval, Looper marks the story passed and commits
5. Stops when all stories pass or max iterations is reached

## Installation

```bash
git clone https://github.com/aflanagan/looper.git
cd looper
./install.sh
```

`install.sh` sets up:
- `~/bin/looper`
- `~/.claude/skills/{looper,prd}`
- `~/.codex/skills/{looper,prd}`

Ensure your shell `PATH` includes the install destination (`$HOME/bin` by default):

```bash
export PATH="$HOME/bin:$PATH"
```

## Requirements

- [Claude Code CLI](https://claude.ai/code)
- [Codex CLI](https://github.com/openai/codex)
- `jq`
- Git

## Usage

### 1. Create a PRD

In Claude Code, use `/prd`:

```
/prd add dark mode to the dashboard
```

### 2. Convert to Looper format

Use `/looper`:

```
/looper convert this prd
```

This creates `.looper/prd.json`.

### 3. (Optional) Add project config

Create `.looper/config.md` with project-specific quality checks and context.

### 4. Run Looper

```bash
looper      # default: 10 iterations
looper 20   # custom iteration limit
```

## Project Structure

```
.looper/
  ├── prd.json                 # Required: task state
  ├── config.md                # Optional: project-specific config
  ├── prompt.local.md          # Optional: project-specific prompt addendum
  ├── review-prompt.md         # Optional: override review prompt
  ├── progress/                # Auto-created: branch-scoped iteration logs
  │   └── <branch-slug>.txt
  └── reviews/                 # Auto-created: review artifacts
```

## Runtime Behavior

- Looper does not commit until Codex returns `APPROVED`.
- Looper sets story `passes: true` only after approval.
- After approval, Looper appends a review-closure summary to `.looper/progress/<branch-slug>.txt` and a short review outcome line to that story's `.looper/prd.json` notes.
- Looper writes progress to branch-scoped files under `.looper/progress/<branch-slug>.txt`.
- Looper excludes `.looper/reviews` and `.looper/progress` runtime artifacts from auto-commits.
- Review artifacts are written under `.looper/reviews/<branch>/<story>/`.

## Configuration

Environment variables:
- `LOOPER_STATE_DIR`: override `.looper` path
- `LOOPER_REVIEW_MAX_ROUNDS`: default `5`
- `LOOPER_REVIEW_PROMPT_FILE`: override review prompt path
- `LOOPER_REVIEW_SCHEMA_FILE`: override review schema path

## Files

| File | Purpose |
|------|---------|
| `bin/looper` | Main CLI orchestrator |
| `templates/looper-prompt.md` | Base Claude implementation prompt |
| `templates/review-prompt.md` | Base review prompt |
| `templates/codex-review-schema.json` | Structured output schema for Codex review |

## Based On
Ryan Carson's Ralph Loop - https://github.com/snarktank/ralph
| `skills/looper/SKILL.md` | PRD-to-JSON conversion skill |
| `skills/prd/SKILL.md` | PRD generation skill |
