---
title: No Fluff Release And Deployment
doc_kind: ops
doc_function: canonical
purpose: Release ownership split, application artifact evidence, safety gates and current rollback gaps.
derived_from:
  - ../dna/governance.md
  - config.md
  - stages.md
status: active
audience: humans_and_agents
canonical_for:
  - release_ownership
  - deployment_boundary
  - rollback_gaps
---

# Release And Deployment

## Source-of-truth split

- This repository owns application source, tests, root `Dockerfile`,
  image-build definitions and repository-local helper entrypoints.
- `~/code/brandymint/infra` owns canonical deployment configuration,
  environment selection, rollout, rollback and production secret injection.
- [`config/deploy.yml`](../../config/deploy.yml) and root `Makefile`
  are existing application-repository evidence/entrypoints. They do not
  override infrastructure ownership or authorize deployment.

## Observed release path

The existing Makefile describes a Linux/amd64 OCI image build, image publish,
infrastructure diff/update, webhook deletion for long-polling production, and a
post-update verification step. The exact current production procedure must be
resolved from the infrastructure repository before use.

## Required gates for future release work

1. Read both current repository instructions and
   `~/code/brandymint/infra/AGENTS.md`.
2. Identify immutable application artifact and intended environment.
3. Run application tests/lint/security/build checks proportionate to the change.
4. Run canonical infrastructure diff through its approved workflow.
5. Obtain any required production execution approval.
6. Deploy only through the infrastructure-owned process; verify health/version
   and change-specific signals.
7. Execute fastest safe rollback on a stop signal under the same owner/gates.

## Rollback gap

Canonical rollback unit, command, approver, data-migration constraints and stop
signals were not found in this repository and external infra was intentionally
not inspected. Status: `TBD`, owner: operations/infrastructure owner.

## Current task boundary

Memory Bank installation changes documentation and local bootstrap only. It
does not build/publish an image, edit deployment config, access production or
deploy.
