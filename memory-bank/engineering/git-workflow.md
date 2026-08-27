---
title: No Fluff Git Workflow
doc_kind: engineering
doc_function: convention
purpose: Current default-branch, commit, rebase/push and worktree rules for No Fluff.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Git Workflow

## Default branch

- Default branch: `main`.
- Do not switch/create branches in the canonical project directory unless the
  user explicitly requests it. The 2026-08-27 Memory Bank adaptation is
  explicitly direct work on current `main`.

## Commits

- Keep commits concise, descriptive and scoped to the intended change.
- Review `git diff --check`, status and the complete intended diff before
  staging/commit.
- Do not include secrets, private data, generated local state or unrelated user
  changes.

## Synchronization and push

- For an authorized direct-main push: commit the reviewed local change, fetch
  `origin`, rebase onto `origin/main`, rerun affected checks if the rebase
  changes the tree, and push normally.
- Do not force-push or rewrite shared history unless explicitly authorized.
- Verify the pushed remote `main` SHA after push.

## Pull requests

No repository-local rule requires a PR for every change. Follow the current
task: direct push only when explicitly requested; otherwise use the applicable
review workflow and report validations/risks.

## Worktrees

If a task explicitly calls for a separate worktree, create it under
`~/.worktrees`. Do not create a worktree or branch for work explicitly scoped to
current `main`.
