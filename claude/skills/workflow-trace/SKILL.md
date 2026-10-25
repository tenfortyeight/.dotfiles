---
name: workflow-trace
description: Trace a GitHub workflow end-to-end across repos
allowed-tools:
  - Agent
  - Read
  - Glob
  - Grep
  - Bash
---

Trace the complete flow of a GitHub workflow to find gaps, missing connections, and incoherent flows. Especially useful for workflows that use reusable workflows.

## Usage

- `/workflow-trace .github/workflows/deploy.yml` - Trace a specific workflow
- `/workflow-trace deploy` - Find and trace workflows matching "deploy"
- `/workflow-trace` - Trace all workflows in current repo

## Process

1. **Find the workflow(s)**
   - Look in `.github/workflows/` in current repo
   - If argument provided, filter to matching files

2. **For each workflow, map the structure:**
   - All jobs and their `needs:` dependencies
   - Inputs and outputs at workflow level
   - Each job's inputs, outputs, and secrets

3. **Follow reusable workflow calls:**
   - When you see `uses: <org>/<repo>/.github/workflows/<file>@<ref>`, locate the referenced repo locally if available, or fetch it
   - Read the referenced workflow file
   - Verify inputs passed match inputs expected
   - Verify outputs consumed exist and are correctly referenced

4. **Check for coherence issues:**
   - Jobs with `needs:` referencing non-existent jobs
   - Outputs referenced but never produced
   - Inputs required but not passed
   - Jobs that could run in parallel but have implicit ordering assumptions
   - Data that needs to flow between jobs but isn't explicitly passed
   - Conditions (`if:`) that could cause unexpected skips

5. **Output:**
   - ASCII or mermaid flow diagram showing job dependencies
   - List of all reusable workflows called (with file paths)
   - **Issues found** - anything that doesn't connect properly
   - **Warnings** - potential problems (implicit assumptions, missing error handling)

## Example Output

```
Workflow: deploy.yml

Jobs flow:
  build -> test -> deploy-staging -> deploy-production
                                  \-> notify

Reusable workflows:
  - deploy-staging uses: reusable-workflows/.github/workflows/deploy-k8s.yml
  - deploy-production uses: reusable-workflows/.github/workflows/deploy-k8s.yml

Issues:
  - deploy-production has no `needs: deploy-staging` - could run in parallel!
  - notify job references output `deploy_url` but deploy-production doesn't expose it

Warnings:
  - No failure notification if deploy-staging fails
```

$ARGUMENTS
