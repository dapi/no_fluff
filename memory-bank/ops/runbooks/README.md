---
title: No Fluff Runbooks Index
doc_kind: ops
doc_function: index
purpose: Registry of evidence-backed operational runbooks and explicit current gaps.
derived_from:
  - ../../dna/governance.md
  - ../stages.md
  - ../release.md
status: active
audience: humans_and_agents
---

# Runbooks Index

No complete repository-local runbook with trigger, diagnosis, resolution,
rollback and escalation ownership was confirmed during brownfield discovery.
No generic runbook was instantiated because commands, environment targets and
owners would be invented.

## Existing operational evidence (not governed runbooks)

- [Root README](../../../README.md) — local Dip commands and production
  long-polling notes.
- [Background jobs](../../../docs/background-jobs-queues.md) — older queue guide;
  validate against current `config/queue.yml` before use.
- [Production vertical slice](../../../docs/Architecture/live-mtproto-vertical-slice.md)
  — dated verification evidence, not a reusable account/runbook.
- [Release owner](../release.md) — routing and current rollback gap.

## Creation rule

Create a runbook only for a repeated operational task with confirmed owner,
safe entrypoint, expected result, rollback and escalation. Production commands
must come from the canonical infrastructure repository, never from template
examples.
