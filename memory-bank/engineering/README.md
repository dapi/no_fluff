---
title: No Fluff Engineering Index
doc_kind: engineering
doc_function: index
purpose: Навигация по engineering contracts, current architecture, testing and change conventions No Fluff.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# No Fluff Engineering

- [Architecture](architecture.md) — Rails/Telegram/MTProto/LLM module
  boundaries, critical dataflow, concurrency, failure and config ownership.
- [Frontend Engineering](frontend.md) — Telegram Bot UI surface, interaction
  and localization contract; no customer-facing web UI is asserted.
- [Telegram Bot UI Guide](ui-design-guide/README.md) — curated source paths for
  messages, keyboards, callbacks and representative tests.
- [Testing Policy](testing-policy.md) — Minitest, fixtures/mocks, Dip commands,
  CI gates and documentation validation.
- [Validation Profiles](validation-profiles.md) — risk-based validation floor
  with a No Fluff application note.
- [Autonomy Boundaries](autonomy-boundaries.md) — decision protocol plus No
  Fluff instruction, production, protected-file and Git boundaries.
- [Coding Style](coding-style.md) — Rails/Ruby/I18n/config/error conventions and
  RuboCop contract.
- [Git Workflow](git-workflow.md) — `main`, direct-main safety, commits, push
  discipline and optional `~/.worktrees` location.
- [ADR Index](../adr/README.md) — architecture decisions; no ADR was created for
  the no-switch research decision because architecture did not change.

Existing repository instructions remain authoritative. Memory Bank documents
their meaning and evidence but does not replace them or install a managed agent
block.
