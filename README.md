# Looper

An autonomous coding-agent loop for Claude Code. Looper implements user stories from a PRD one at a time, committing after each, until all stories are complete.

## How It Works

1. Create a PRD (product requirements document) with user stories
2. Convert it to `prd.json` format using the `/looper` skill
3. Run `looper` - it loops through stories autonomously
4. Each iteration: picks one story, implements it, runs quality checks, commits
5. Stops when all stories pass or max iterations is reached

## Installation

```bash
git clone https://github.com/aflanagan/ralph.git ~/work/looper
cd ~/work/looper
./install.sh
```

Note: the GitHub repo is still `ralph` today; the intent is to rename it to `looper`.

The installer:
- Symlinks `looper` to `~/bin/`
- Adds compatibility alias `ralph -> looper`
- Symlinks skills to `~/.claude/skills/`

Make sure `~/bin` is in your PATH:

```bash
export PATH="$HOME/bin:$PATH"
```

## Usage

### 1. Create a PRD

In Claude Code, use the `/prd` skill:

```
/prd add dark mode to the dashboard
```

This generates a structured PRD in `.ai/looper/plans/`.

### 2. Convert to Looper format

Use the `/looper` skill:

```
/looper convert this prd
```

This creates `.ai/looper/prd.json` with the task structure Looper needs.

### 3. (Optional) Add project config

Create `.ai/looper/config.md` with project-specific instructions:

```markdown
# Looper Project Config

## Quality Checks
- Run tests: `npm test`
- Run linter: `npm run lint`

## Project Context
- This is a React app using Tailwind CSS
- See CLAUDE.md for coding standards
```

### 4. Run Looper

```bash
looper      # Default: 10 iterations
looper 20   # Custom iteration limit
```

Looper will:
- Pick the highest-priority incomplete story
- Implement it following your project's patterns
- Run quality checks
- Commit with `[Looper] US-XXX: <title>`
- Update `prd.json` and `progress.txt`
- Repeat until done

### 5. (Optional) Add local prompt addendum

Create `.ai/looper/prompt.local.md` when you need per-repo prompt behavior (for example a custom review loop).

Looper always loads the global template at `templates/looper-prompt.md` first, then appends `.ai/looper/prompt.local.md` if it exists.

## Project Structure

Preferred layout:

```
.ai/looper/
  ├── prd.json          # Required: task state
  ├── config.md         # Optional: project-specific config
  ├── prompt.local.md   # Optional: project-specific prompt addendum
  └── progress.txt      # Auto-created: iteration learnings
```

Legacy layout is still supported:

```
.claude/
  ├── prd.json
  ├── ralph-config.md
  ├── ralph-prompt.md
  └── progress.txt
```

## Files

| File | Purpose |
|------|---------|
| `bin/looper` | The main CLI script |
| `templates/looper-prompt.md` | Instructions sent to Claude each iteration |
| `skills/looper/SKILL.md` | Skill for converting PRDs to JSON |
| `skills/prd/SKILL.md` | Skill for generating PRDs |

## How Looper Learns

Looper maintains `progress.txt` across iterations. Each iteration appends:
- What was implemented
- Files changed
- Patterns discovered
- Gotchas encountered

Future iterations read this file first, so Looper learns from its own work.

## Branch Management

- Looper works on the branch specified in `prd.json` (`branchName` field)
- When you start a new feature (different branch), previous progress is archived to `.ai/looper/archive/` (or `.claude/archive/` in legacy repos)
- Looper never pushes - you review commits and push manually

## Requirements

- [Claude Code CLI](https://claude.ai/code)
- `jq` (for JSON parsing)
- Git
