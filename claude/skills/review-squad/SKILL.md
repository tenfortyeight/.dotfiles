---
name: review-squad
description: Run architecture, security, QA, and devil's advocate review on changes
allowed-tools:
  - Task
  - Bash
  - Read
  - Glob
  - Grep
---

Spawn 4 parallel review agents to critique the current changes. This catches issues before they become pipeline failures or production bugs.

## Process

1. First, gather context:
   - Run `git diff` to see unstaged changes
   - Run `git diff --cached` to see staged changes
   - Identify which files/areas are affected

2. Then spawn these 4 agents IN PARALLEL using the Task tool:

   **Architecture Agent:**
   - Does this fit the existing platform/codebase design patterns?
   - Are changes consistent with how similar things are done elsewhere in this repo (and sibling repos if relevant)?
   - Will this scale? Any tight coupling introduced?
   - Check against established patterns before introducing new ones

   **Security Agent:**
   - Any secrets, tokens, or credentials exposed?
   - Input validation present where needed?
   - Auth/authz boundaries respected?
   - OWASP top 10 concerns?

   **QA Agent:**
   - Is this testable? If hard to test, suggest redesign
   - What test cases are missing?
   - Boundary conditions covered? (0, 1, -1, null, empty, max)
   - Integration points that need verification?

   **Devil's Advocate Agent:**
   - Try to break this. What happens if it fails?
   - Race conditions possible?
   - Partial failure scenarios?
   - What breaks if a dependency is unavailable?
   - For workflows: what if a job fails but subsequent jobs run?

3. Collect all findings and summarize by severity:
   - **Blockers**: Must fix before committing
   - **Warnings**: Should address, risk if ignored
   - **Suggestions**: Nice to have improvements

$ARGUMENTS
