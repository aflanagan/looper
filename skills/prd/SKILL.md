# PRD Generator Skill

## Trigger
Use this skill when the user asks to create, write, plan, or spec a product requirement.

## Contract model

A PRD is the approved product contract. Its stories are not implementation plans. Each story says what outcome is independently valuable and how it will be proved; Looper later creates and adversarially reviews a codebase-grounded execution plan for the selected story.

Stories have two authoring states:

- `DRAFT`: questions, boundaries, or proof are still being refined. Looper must not execute it.
- `APPROVED`: the user has approved the story block and its material contract fields. Only approved stories may be converted for execution.

Approval applies to the complete story block. A material change to its outcome, acceptance criteria, scope, non-goals, dependencies, proof expectations, or disappointment check returns it to `DRAFT` and requires explicit re-approval. Typographical edits that do not alter meaning are non-material.

## Process

### 1. Gather requirements

Ask only the clarifying questions needed to establish the user, problem, boundary, success proof, dependencies, and important non-goals. Use lettered choices when they make the decision easier.

### 2. Draft the PRD

Use this structure:

```markdown
# PRD: [Feature Name]

## Introduction / Overview
## Goals
## Non-Goals
## Functional Requirements
## Design Considerations (optional)
## Technical Considerations (optional)
## Success Metrics
## Open Questions

## Stories

### [ABC-001] Short outcome title
- Status: DRAFT | APPROVED
- User outcome: As a ..., I want ..., so that ...
- Source refs: FR-1, Goal-1
- Depends on: none | ABC-000
- Replaces: none | ABC-000
- In scope:
  - ...
- Non-goals:
  - ...
- Acceptance criteria:
  - ABC-001-AC-001: Observable, verifiable outcome.
  - ABC-001-AC-002: Observable, verifiable outcome.
- Proof expectations:
  - ABC-001-PROOF-001: Test, command, or product-level inspection that proves an AC.
- Disappointment check: What reasonable user expectation would make this technically-correct story still feel unfinished?
```

Give Goals and Functional Requirements stable IDs so `Source refs` can preserve traceability. Choose one semantic 2–3 letter uppercase story prefix and use sequential IDs. Acceptance-criterion IDs are permanent: never renumber or reuse one after approval; add a new ID when the contract grows.

### 3. Review decomposition before approval

For every story, verify:

- It produces one independently reviewable outcome and can be implemented in one coding context.
- Its acceptance criteria describe observable behavior, not implementation steps.
- `Source refs` account for the PRD requirements it implements; every in-scope requirement is owned by at least one story.
- Dependencies are explicit, acyclic, and refer only to earlier or externally satisfied work.
- Scope and non-goals prevent neighboring stories from bleeding together.
- Proof expectations cover tests plus any user/developer/operator experience that code-only tests could miss.
- The disappointment check catches a hollow implementation that passes literal criteria but misses the intended experience.

If implementation likely spans unrelated subsystems, requires more than one independently useful migration/cutover, or cannot be proved as one unit, split it before approval. Do not invent implementation steps; runtime planning owns that layer.

### 4. Obtain approval and save

Present material unresolved choices. Change story status to `APPROVED` only after the user approves the complete block. Save the PRD to `.looper/<branch-name>/prd.md`.

Derive `<branch-name>` from the current Git branch: drop an initial `codex/` or `looper/`, replace characters outside `[A-Za-z0-9._-]` with `-`, and use `unknown-branch` if empty.

## Output rules

- Write explicitly enough for a junior developer and an AI agent.
- Do not convert draft stories into executable work.
- Preserve approved wording and stable IDs during conversion.
- Order stories by dependency, but never use order as a substitute for `Depends on`.
- Prefer product-verifiable criteria over vague quality claims such as “works correctly.”
