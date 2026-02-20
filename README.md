# Ralph

An autonomous coding agent loop for Claude Code. Ralph implements user stories from a PRD one at a time, committing after each, until all stories are complete.

## How It Works

1. You create a PRD (product requirements document) with user stories
2. Convert it to `prd.json` format using the `/ralph` skill
3. Run `ralph` - it loops through stories autonomously
4. Each iteration: picks one story, implements it, runs quality checks, commits
5. Stops when all stories pass or max iterations reached

## Installation

```bash
git clone https://github.com/aflanagan/ralph.git ~/work/ralph
cd ~/work/ralph
./install.sh
```

The installer:
- Symlinks `ralph` to `~/bin/`
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

This generates a structured PRD in `.claude/plans/`.

### 2. Convert to Ralph Format

Use the `/ralph` skill:
```
/ralph convert this prd
```

This creates `.claude/prd.json` with the task structure Ralph needs.

### 3. (Optional) Add Project Config

Create `.claude/ralph-config.md` with project-specific instructions:

```markdown
# Ralph Project Config

## Quality Checks
- Run tests: `npm test`
- Run linter: `npm run lint`

## Project Context
- This is a React app using Tailwind CSS
- See CLAUDE.md for coding standards
```

### 4. Run Ralph

```bash
ralph        # Default: 10 iterations
ralph 20     # Custom iteration limit
```

Ralph will:
- Pick the highest-priority incomplete story
- Implement it following your project's patterns
- Run quality checks
- Commit with `[Ralph] US-XXX: <title>`
- Update `prd.json` and `progress.txt`
- Repeat until done

### 5. (Optional) Add Project Prompt Addendum

Create `.claude/ralph-prompt.md` when you need per-repo prompt behavior (for example a custom review loop).

Ralph always loads the global template at `templates/ralph-prompt.md` first, then appends `.claude/ralph-prompt.md` if it exists.

## Project Structure

Each project using Ralph needs:

```
.claude/
  ├── prd.json           # Required: task state
  ├── ralph-config.md    # Optional: project-specific config
  ├── ralph-prompt.md    # Optional: project-specific prompt addendum (appended to global template)
  └── progress.txt       # Auto-created: iteration learnings
```

## Files

| File | Purpose |
|------|---------|
| `bin/ralph` | The main CLI script |
| `templates/ralph-prompt.md` | Instructions sent to Claude each iteration |
| `skills/ralph/SKILL.md` | Skill for converting PRDs to JSON |
| `skills/prd/SKILL.md` | Skill for generating PRDs |

## How Ralph Learns

Ralph maintains `progress.txt` across iterations. Each iteration appends:
- What was implemented
- Files changed
- Patterns discovered
- Gotchas encountered

Future iterations read this file first, so Ralph learns from its own work.

## Branch Management

- Ralph works on the branch specified in `prd.json` (`branchName` field)
- When you start a new feature (different branch), previous progress is archived to `.claude/archive/`
- Ralph never pushes - you review commits and push manually

## Requirements

- [Claude Code CLI](https://claude.ai/code)
- `jq` (for JSON parsing)
- Git
