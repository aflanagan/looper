# Looper PRD-to-Story-Contract Skill

## Trigger
Use this skill when the user asks to convert a PRD to Looper format or create `prd.json`.

## Purpose

This conversion is decomposition layer one: preserve approved product intent as small, dependency-aware story contracts. Do not produce implementation tasks or file-by-file steps here. At runtime Looper locks one story, generates a codebase-grounded execution plan, adversarially reviews it, and only then implements it.

## Process

### 1. Validate the approved PRD

Do not silently repair or reinterpret an approved contract. Report problems and obtain approval before material changes.

Check that:

- every converted story is explicitly `APPROVED`;
- IDs and acceptance-criterion IDs are unique and stable;
- each story is one independently reviewable outcome small enough for one coding context;
- acceptance criteria are observable and verifiable;
- `sourceRefs` trace each story to goals or requirements and all in-scope requirements are covered;
- `dependsOn` references exist, point to earlier stories, and are acyclic;
- scope, non-goals, proof expectations, and a disappointment check are present;
- replacement stories name the superseded story in `replaces` and preserve its uncovered source refs/criteria.

If a story is too large, propose revised `DRAFT` story blocks and ask for approval. Never split an approved story invisibly during JSON conversion.

### 2. Determine the state directory

Derive `<branch-name>` from the current Git branch: drop an initial `codex/` or `looper/`, replace characters outside `[A-Za-z0-9._-]` with `-`, and use `unknown-branch` if empty. Write under `.looper/<branch-name>/`.

### 3. Emit canonical JSON

Use `schemaVersion: 2` and preserve approved wording exactly:

```json
{
  "schemaVersion": 2,
  "project": "ProjectName",
  "branchName": "looper/feature-name",
  "description": "Brief feature description",
  "userStories": [
    {
      "id": "ABC-001",
      "status": "APPROVED",
      "title": "Short outcome title",
      "description": "As a user, I want an outcome so that I receive value.",
      "sourceRefs": ["Goal-1", "FR-2"],
      "scope": ["Explicitly included outcome"],
      "nonGoals": ["Explicitly excluded adjacent behavior"],
      "acceptanceCriteria": [
        {"id": "ABC-001-AC-001", "text": "Observable criterion."}
      ],
      "proofExpectations": [
        {"id": "ABC-001-PROOF-001", "text": "How the outcome should be proved.", "command": "optional safe deterministic command"}
      ],
      "disappointmentCheck": "A reasonable expectation that must not be missed.",
      "dependsOn": [],
      "replaces": [],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

Choose one semantic 2–3 letter uppercase prefix based on the branch or dominant feature area. IDs must match `<PREFIX>-001`; do not emit generic `US-*` IDs. Assign numeric priority as a readable tie-breaker, not as the dependency model.

### 4. Material-change rules

When updating an existing `prd.json`:

- Preserve story and AC IDs and all approved material wording.
- New or materially changed contracts must be `DRAFT` until explicitly approved.
- Once Looper has locked a story ID, never reuse that ID for a materially different contract; create a new approved ID and use `replaces` when it supersedes the old work.
- Removing or weakening an approved AC, changing scope/non-goals, changing dependencies, or changing proof/disappointment expectations is material.
- Replacing a terminal story requires new approved stories whose `replaces` arrays name it. Do not delete the terminal story; lineage is part of the audit trail.
- `passes`, `notes`, and runtime `execution` fields are Looper-owned state. Preserve them unless the user explicitly requests a state reset.

### 5. Legacy normalization

Legacy files with string acceptance criteria remain runnable. During explicit conversion, normalize each string to `{ "id": "<STORY-ID>-AC-NNN", "text": "..." }` in existing order and add conservative defaults for absent contract fields. Runtime Looper leaves the legacy PRD unchanged and canonicalizes only its frozen selected-story contract. Never renumber an already-object criterion.

### 6. Scaffold addenda

If absent, create short project-specific `prompt.shared.md`, `prompt.implementer.md`, and `prompt.reviewer.md` files beside `prd.json`. Do not copy Looper defaults and do not overwrite existing addenda without explicit permission.

## Output

Confirm the chosen prefix, output path, story count, dependency validation, any legacy normalization, and which addenda were created or preserved.
