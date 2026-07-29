## Looper Project Model
Looper stores branch-scoped runtime state under the `State directory` path from runtime context, usually `.looper/<branch>/`.

Within that directory, expect this structure:
- `prd.json`: story backlog and per-story pass state
- `prd.md`: optional source PRD markdown when the project keeps it
- `progress.txt`: global progress log and `## Codebase Patterns`
- `stories/<story-id>.md`: the Story File for one active story
- `stories/<story-id>.contract.json`: immutable material contract snapshot
- `stories/<story-id>.approved-plan.json`: adversarially approved execution plan
- `prompt.shared.md`: optional project instructions shared by both agents
- `prompt.implementer.md`: optional project instructions for implementation only
- `prompt.reviewer.md`: optional project instructions for review only

## File Contract
- `Immutable contract file`: the exclusive product truth for this run. Its story outcome, scope, non-goals, acceptance criteria, proof expectations, and dependencies cannot be weakened or replaced by any live file.
- `Approved plan file`: the exclusively approved execution approach. Load it before implementation or code review and stop if it is missing or conflicts with the immutable contract.
- `prd.json`: mutable backlog and completion state only. It may be reordered or edited while a story is active; never use its live story wording as product authority for the locked run.
- `Story File`: the markdown file at the story file path from runtime context, typically `stories/<story-id>.md` under the Looper state directory.
- `progress.txt`: the progress log file at the path from runtime context. Use it for `## Codebase Patterns` and the latest entry for the active story.

## Required Context
- In the fully rendered prompt for this run, Looper appends a `## Runtime Context` block at the end. Start there and use it to identify:
  - the active story id
  - the PRD file path
  - the story file path
  - the progress log file path
- Read the immutable contract and approved plan paths first. Use the PRD only for backlog/pass-state context.
- Read the Story File and inspect these sections in order:
  - `## Story Details`
  - `## Current Status`
  - `## Open Findings`
  - `## Latest Review Summary`
  - `## Latest Implementation Handoff`
- Treat the Story File as the canonical handoff record between Looper phases.
- Treat the locked contract and approved plan paths in runtime context as authoritative. The PRD is mutable backlog state; it must not silently change the active contract.
- Read the progress log file and use:
  - the `## Codebase Patterns` section near the top
  - the most recent entry for the active story id
