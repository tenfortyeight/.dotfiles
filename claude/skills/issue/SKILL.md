---
name: issue
description: Analyze and work on a GitHub issue with comprehensive solution analysis
---

Work on a specific GitHub issue from the current repository.

## Features
- Fetches complete issue details including comments
- Analyzes issue relevance and current codebase state
- Weighs solution approaches and picks the best
- Asks the user only when the choice needs their judgement
- Tracks progress with todo list

## Usage
`/issue <issue_number>`

Example: `/issue 42`

## Process Flow
1. **Fetch Issue Details** - Get full issue information and comments
2. **Set Assignee** - Set assignee to the user
3. **Analyze Current State** - Check if issue is still relevant/accurate
4. **Identify Affected Areas** - Find related code and functions
5. **Choose a Solution** - Weigh the approaches, pick the best and say why in a line
6. **User Decision, only if needed** - Outline 2–3 approaches and wait only when the choice touches blast radius, changes the scope or needs a business decision (CLAUDE.md, Working hands-off)
7. **Implementation** - Execute the chosen solution with progress tracking

Arguments: $ARGUMENTS
