---
name: prd
description: Create or refine an authoritative product requirements document that Looper can decompose into reviewed story contracts.
---

# PRD Authoring

Use this skill when the user asks to create, write, plan, or refine a product requirements document for Looper.

## Purpose

A PRD is product authority, not an implementation plan or execution queue. Make intended outcomes, boundaries, requirements, non-goals, and proof clear enough that independent agents can decompose it without inventing product decisions. Looper separately proposes stories, adversarially reviews their coverage and boundaries, and publishes `stories.json` only after approval.

## Process

1. Ask only the questions needed to resolve material product choices, contradictions, boundaries, and success proof.
2. Draft the PRD with stable IDs for goals and requirements.
3. Check completeness, conflicts, non-goals, and product-verifiable success.
4. Save the authoritative Markdown byte-for-byte as `.looper/<branch-name>/source.md`, or save elsewhere and pass that path to `looper prepare --prd`.

Use this structure when it fits:

```markdown
# PRD: [Feature Name]

## Introduction / Overview
## Goals
- Goal-1: ...
## Non-Goals
## Functional Requirements
- FR-1: ...
## Design Considerations (optional)
## Technical Constraints (optional)
## Success Metrics
## Open Questions
## Candidate Story Boundaries (optional)
```

Candidate boundaries are useful product groupings, not pre-approved runtime contracts. Do not add file-by-file steps or prescribe an implementation unless the product requirement truly depends on it.

## Source readiness check

Before handing the source to Looper, verify:

- Every in-scope outcome or behavior has a stable source ID.
- Non-goals prevent adjacent work from leaking into scope.
- Acceptance or success statements are observable rather than “works correctly.”
- Explicit dependencies and rollout constraints are recorded.
- No material contradiction or unresolved product choice is hidden.
- Existing useful story boundaries are clear, while oversized boundaries may be split by decomposition.
- A literal implementation that would still disappoint is called out.

Invoking `looper prepare --prd PATH` or `looper start --prd PATH` declares that file authoritative. Routine per-story human approval is not required: Looper uses a separate read-only decomposer and adversarial reviewer. If they encounter a material ambiguity they cannot safely resolve, the workflow stops in `NEEDS_HUMAN` with persisted evidence.

## Branch state directory

Looper derives `<branch-name>` from the current Git branch: it drops an initial `codex/` or `looper/`, replaces characters outside `[A-Za-z0-9._-]` with `-`, and uses `unknown-branch` if empty. `source.md` and generated state live under `.looper/<branch-name>/` unless `LOOPER_STATE_DIR` overrides it.
