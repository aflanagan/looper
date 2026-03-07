## Looper Project Model
Looper stores branch-scoped runtime state under the `State directory` path from runtime context, usually `.looper/<branch>/`.

Within that directory, expect this structure:
- `prd.json`: story backlog and per-story pass state
- `prd.md`: optional source PRD markdown when the project keeps it
- `progress.txt`: global progress log and `## Codebase Patterns`
- `stories/<story-id>.md`: the Story File for one active story
- `prompt.shared.md`: optional project instructions shared by both agents
- `prompt.implementer.md`: optional project instructions for implementation only
- `prompt.reviewer.md`: optional project instructions for review only

## File Contract
- `prd.json`: the JSON file at the PRD path from runtime context. Read the active story object from `userStories[]` by matching the active story id.
- `Story File`: the markdown file at the story file path from runtime context, typically `stories/<story-id>.md` under the Looper state directory.
- `progress.txt`: the progress log file at the path from runtime context. Use it for `## Codebase Patterns` and the latest entry for the active story.

## Required Context
- In the fully rendered prompt for this run, Looper appends a `## Runtime Context` block at the end. Start there and use it to identify:
  - the active story id
  - the PRD file path
  - the story file path
  - the progress log file path
- Read the PRD file and find the active story object by `id`.
- Read the Story File and inspect these sections in order:
  - `## Story Details`
  - `## Current Status`
  - `## Open Findings`
  - `## Latest Review Summary`
  - `## Latest Implementation Handoff`
- Treat the Story File as the canonical handoff record between Looper phases.
- Read the progress log file and use:
  - the `## Codebase Patterns` section near the top
  - the most recent entry for the active story id
