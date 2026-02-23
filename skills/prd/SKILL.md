# PRD Generator Skill

## Trigger
This skill activates when the user asks to:
- "create a prd"
- "write prd for"
- "plan this feature"
- "requirements for"
- "spec out"

## Process

### Step 1: Gather requirements
Ask 3-5 clarifying questions to understand the feature. Use lettered options (A/B/C/D) when applicable.

Example questions:
- What is the primary user for this feature?
- What problem does this solve?
- Are there any technical constraints?
- What's the scope - MVP or full feature?

### Step 2: Generate PRD

Create a structured PRD with these sections:

```markdown
# PRD: [Feature Name]

## Introduction/Overview
Brief description of what this feature does and why it matters.

## Goals
Specific, measurable objectives:
- Goal 1
- Goal 2

## User Stories
Small, completable stories in this format:
- US-001: As a [user], I want [feature] so that [benefit]
- US-002: ...

**Important**: Each story must be completable in ONE context window (2-3 sentences of work).
If a story is too big, split it into sub-stories.

## Functional Requirements
Numbered, unambiguous requirements:
1. The system SHALL...
2. The system SHALL...

## Non-Goals
What this feature explicitly does NOT include:
- Not doing X
- Not doing Y

## Design Considerations (optional)
UI/UX considerations if applicable.

## Technical Considerations (optional)
Architecture, dependencies, integration points.

## Success Metrics
How we'll know this feature is successful:
- Metric 1
- Metric 2

## Open Questions
Unresolved questions that need answers:
- Question 1?
- Question 2?
```

### Step 3: Save the PRD
Save to `.ai/looper/plans/prd-[feature-name].md`

Legacy fallback path (if a repo has not migrated yet):
- `.claude/plans/prd-[feature-name].md`

## Output guidelines

- Write for junior developers and AI agents (explicit, unambiguous)
- Keep user stories SMALL (one context window each)
- Order stories by dependency (schema -> backend -> frontend)
- Include acceptance criteria for each story
- Be specific, not vague ("button shows dialog" not "works correctly")
