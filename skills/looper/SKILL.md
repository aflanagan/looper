---
name: looper
description: Prepare an authoritative PRD or bounded spec into one adversarially reviewed execution-plan queue, then run Looper's implementation, validation, and code-review workflow.
---

# Looper workflow

Use this skill when asked to prepare or execute a PRD or bounded task with Looper.

```bash
looper prepare --prd path/to/prd.md
looper prepare --spec path/to/task.md
looper start --prd path/to/prd.md
looper start --spec path/to/task.md
looper run [max_iterations]
looper watch [--raw]
```

`--prd` means whole-feature planning. `--spec` is a hard scope ceiling for one bounded source. The supplied file remains authoritative: Looper records its absolute path and hash, reads it directly, and stops if it changes or disappears.

Preparation creates one repository-grounded plan for the complete source and one independent broad review. Requested changes permit one complete focused revision and one finding-scoped closure review. The fixed preparation budget is four model calls including timeout or structured-output repairs.

The approved `stories.json` is both execution plan and queue. Each story already includes its implementation steps and proof; execution never invokes a planner. Looper locks one dependency-ready story, implements it, runs harness validation, and performs one broad code review. Requested changes permit one remediation and one closure review, with no further round.

`state.json` stores only current orchestration, lock, budget, timing, and validation progress. It does not duplicate the queue. Do not create source snapshots, per-story plan files, Story Files, progress logs, compatibility artifacts, or extra rounds. Preserve optional `prompt.shared.md`, `prompt.implementer.md`, and `prompt.reviewer.md` addenda unless explicitly asked to change them.
