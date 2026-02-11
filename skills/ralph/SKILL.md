# Ralph PRD-to-JSON Converter Skill

## Trigger
This skill activates when the user asks to:
- "convert this prd"
- "turn this into ralph format"
- "create prd.json from this"
- "ralph json"
- "convert to ralph"

## Process

### Step 1: Validate the PRD
Check the input PRD for:
- [ ] Stories are small enough (completable in one context window)
- [ ] Stories are ordered by dependency (no story depends on a later story)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] Each story has clear, testable outcomes

If issues found, suggest fixes before converting.

### Step 2: Convert to JSON Format

Create `.claude/prd.json` with this structure:

```json
{
  "project": "ProjectName",
  "branchName": "ralph/feature-name",
  "description": "Brief feature description",
  "userStories": [
    {
      "id": "US-001",
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

### Step 3: Set Priorities
Assign priority numbers based on dependency order:
- Priority 1: Foundation work (schema, models, core functions)
- Priority 2: Business logic (services, utilities)
- Priority 3: Integration (connecting components)
- Priority 4: UI/presentation layer
- Priority 5: Polish and edge cases

Lower priority number = do first.

### Step 4: Archive Previous PRD (if exists)
If there's an existing prd.json with a different branchName:
- The ralph script will handle archiving automatically
- Just overwrite the file

### Step 5: Save the File
Write to `.claude/prd.json`

## JSON Field Requirements

### branchName
- Format: `ralph/feature-name-kebab-case`
- Must be a valid git branch name
- Prefix with `ralph/` for easy identification

### userStories[].id
- Format: `US-001`, `US-002`, etc.
- Sequential numbering
- Unique within the PRD

### userStories[].acceptanceCriteria
Must be verifiable. Good vs bad examples:

**Bad (vague):**
- "Works correctly"
- "User can do the thing"
- "Feature is implemented"

**Good (verifiable):**
- "Function returns list of dicts with 'id' and 'name' keys"
- "Clicking button shows confirmation dialog with 'Cancel' and 'Confirm' options"
- "API returns 200 status with JSON body containing 'success': true"

### userStories[].priority
- Integer starting at 1
- 1 = highest priority (do first)
- Reflects dependency order

### userStories[].passes
- Always start as `false`
- Ralph updates to `true` when story completes

### userStories[].notes
- Start empty
- Ralph adds implementation notes and learnings

## Critical Rules

1. **One context window per story**: If a story seems too big, split it
2. **No circular dependencies**: Story N cannot depend on Story N+1
3. **Verifiable criteria only**: Every criterion must be testable
4. **Include quality checks**: Add "Tests pass" or "Type checks pass" where applicable

## Output
Save the JSON to `.claude/prd.json` and confirm to the user.
