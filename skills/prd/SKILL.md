---
name: prd
description: Create or refine an authoritative product requirements document for Looper's complete-source planning workflow.
---

# PRD authoring

A Looper PRD is product authority, not an execution queue. Make outcomes, boundaries, requirements, constraints, non-goals, and observable success clear enough that one repository-grounded planning agent can produce the complete story plan without inventing product decisions.

Prefer stable requirement IDs and this lightweight structure when useful:

```markdown
# PRD: Feature
## Overview
## Goals
## Non-Goals
## Requirements
## Constraints
## Success and proof
## Open questions
```

Before preparation, resolve material contradictions and product choices, identify adjacent work that must remain out of scope, make success observable, and call out a literal implementation that could technically pass yet disappoint.

Save the PRD anywhere in the repository and invoke `looper prepare --prd PATH` or `looper start --prd PATH`. That original file remains authoritative; Looper stores its absolute path and hash but does not copy it. Changing or removing it makes the approved plan stale and requires fresh preparation.

Candidate story boundaries are welcome, but do not write a second queue or file-by-file implementation plan into the PRD unless the product contract truly requires it. Looper plans and adversarially reviews all stories together before implementation.
