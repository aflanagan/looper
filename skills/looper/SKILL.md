# Looper PRD-to-JSON Converter Skill

## Trigger
This skill activates when the user asks to:
- "convert this prd"
- "turn this into looper format"
- "create prd.json from this"
- "looper json"
- "convert to looper"

## Process

### Step 1: Validate the PRD
Check the input PRD for:
- [ ] Stories are small enough (completable in one context window)
- [ ] Stories are ordered by dependency (no story depends on a later story)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] Each story has clear, testable outcomes

If issues are found, suggest fixes before converting.

### Step 2: Determine branch-scoped state directory

Set `<branch-name>` from the current git branch:
- Start with `git rev-parse --abbrev-ref HEAD`
- If it starts with `codex/` or `looper/`, drop that prefix
- Replace non `[A-Za-z0-9._-]` characters with `-`
- If empty, use `unknown-branch`

State directory path:
- `.looper/<branch-name>/`

### Step 3: Convert to JSON format

Create `.looper/<branch-name>/prd.json` with this structure:

```json
{
  "project": "ProjectName",
  "branchName": "looper/feature-name",
  "description": "Brief feature description",
  "userStories": [
    {
      "id": "QRY-001",
      "title": "Short descriptive title",
      "description": "As a [user], I want [feature] so that [benefit].",
      "acceptanceCriteria": [
        "Specific, verifiable criterion 1",
        "Specific, verifiable criterion 2",
        "Tests pass (if applicable)",
        "Type checks pass (if applicable)"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

Before generating stories, choose a single semantic prefix for `userStories[].id`:
- Prefer the current branch name first.
- If the branch name is too generic, infer the prefix from the PRD's dominant feature area.
- Use an uppercase 2-3 letter prefix that stays readable.
- State the chosen prefix in your response when you save the file.

Examples:
- `query-layer` -> `QRY-001`
- `data-layer` -> `DL-001`
- `investigation-engine` -> `INV-001`

### Step 4: Set priorities
Assign priority numbers based on dependency order:
- Priority 1: Foundation work (schema, models, core functions)
- Priority 2: Business logic (services, utilities)
- Priority 3: Integration (connecting components)
- Priority 4: UI/presentation layer
- Priority 5: Polish and edge cases

Lower priority number = do first.

### Step 5: Archive previous PRD (if exists)
If there is an existing PRD with a different `branchName`:
- the looper script handles archiving automatically
- overwrite the file

### Step 6: Save the file
Write to `.looper/<branch-name>/prd.json`.

## JSON field requirements

### `branchName`
- Format: `looper/feature-name-kebab-case`
- Must be a valid git branch name
- Prefix with `looper/` for easy identification

### `userStories[].id`
- Format: `<PREFIX>-001`, `<PREFIX>-002`, etc.
- `<PREFIX>` must be a semantic 2-3 letter uppercase code chosen from branch name or PRD intent
- Sequential numbering
- Unique within the PRD

### `userStories[].acceptanceCriteria`
Must be verifiable. Good vs bad examples:

**Bad (vague):**
- "Works correctly"
- "User can do the thing"
- "Feature is implemented"

**Good (verifiable):**
- "Function returns list of dicts with 'id' and 'name' keys"
- "Clicking button shows confirmation dialog with 'Cancel' and 'Confirm' options"
- "API returns 200 status with JSON body containing 'success': true"

### `userStories[].priority`
- Integer starting at 1
- 1 = highest priority (do first)
- Reflects dependency order

### `userStories[].passes`
- Always start as `false`
- Looper updates to `true` when a story completes

### `userStories[].notes`
- Start empty
- Looper adds implementation notes and learnings

## Critical rules

1. **One context window per story**: if a story seems too big, split it
2. **No circular dependencies**: story N cannot depend on story N+1
3. **Verifiable criteria only**: every criterion must be testable
4. **Include quality checks**: add "Tests pass" or "Type checks pass" where applicable
5. **No generic story ids**: do not emit `US-001` or `US-QRY-001`; use a semantic 2-3 letter prefix instead

## Output
Save the JSON to `.looper/<branch-name>/prd.json` and confirm to the user.
