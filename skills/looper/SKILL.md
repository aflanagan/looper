---
name: looper
description: Prepare an authoritative PRD or bounded spec into adversarially reviewed story contracts, then run Looper's per-story planning, implementation, validation, and review workflow.
---

# Looper Source-to-Execution Workflow

Use this skill when the user asks to prepare, decompose, or execute a PRD or bounded task/spec with Looper.

## Choose the source contract

- Use `--prd` for a whole product/feature document. Decomposition preserves useful boundaries, splits oversized work, and covers all in-scope requirements.
- Use `--spec` for a bounded end-to-end task. The spec is a hard scope ceiling; Looper must not pull in neighboring roadmap work.

The workflow is generic. Do not add repository-specific paths, queue naming, heading conventions, or tool assumptions to the source.

## Commands

```bash
looper prepare --prd path/to/prd.md
looper prepare --spec path/to/task.md
looper start --prd path/to/prd.md [max_iterations]
looper start --spec path/to/task.md [max_iterations]
looper run [max_iterations]
looper [max_iterations]
looper watch [--verbose|--raw]
```

`prepare` performs source capture, decomposition, and adversarial decomposition review without implementing. `start` performs the same preparation and then enters the ordinary story execution engine. `run` and bare `looper` resume an already prepared state.

The prepare/start invocation is the authority boundary. Looper snapshots the input byte-for-byte as immutable `source.md`, records its kind, original path, and SHA-256 hash, and refuses a different kind or content for the same state directory.

## Decomposition contract

The read-only decomposition agent must inventory every in-scope source item, produce dependency-ordered story contracts, and map each source item to stories and acceptance criteria. Stories are product outcomes, not implementation plans. Each requires:

- a stable ID and independent outcome;
- source references, explicit scope, and non-goals;
- stable observable acceptance-criterion IDs;
- proof expectations and a disappointment check;
- backward-only explicit dependencies and replacement lineage where relevant.

A separate read-only reviewer evaluates every inventory item and every story for omissions, invented scope, weak proof, oversized boundaries, hidden dependencies, and “could pass but disappoint” failures. It returns:

- `APPROVED`: Looper injects harness-owned status/provenance and atomically publishes schema-v3 `stories.json`;
- `CHANGES_REQUESTED`: the author revises within the bounded review rounds;
- `NEEDS_HUMAN`: a contradiction or material product choice requires human input;
- `REVIEW_LIMIT`: bounded review ended without approval.

Do not manually write runtime fields (`status`, `passes`, `notes`, `execution`) into an author proposal. Do not publish or replace `stories.json` unless the reviewer approves.

## State and resume behavior

The state directory contains:

```text
source.md
stories.json
decomposition/
  state.json
  proposal-N.json
  review-N.json
  approved.json
stories/
  <story-id>.contract.json
  <story-id>.planning.json
  <story-id>.plan-N.json
  <story-id>.plan-review-N.json
  <story-id>.approved-plan.json
```

Source decomposition resumes at persisted author/reviewer boundaries. The same approved source is idempotent. A source hash mismatch, malformed output, unauthorized read-only side effect, `NEEDS_HUMAN`, or review limit stops without publishing partial stories.

After preparation, all inputs converge on one engine: lock one story, generate a codebase-grounded read-only plan, adversarially review it, implement only an approved `PLAN_READY` plan, run harness-owned validation, adversarially review the diff, remediate if needed, and commit once on approval.

Project prompt addenda remain optional beside `stories.json`: `prompt.shared.md`, `prompt.implementer.md`, and `prompt.reviewer.md`. Preserve existing files; do not overwrite them without explicit permission.
