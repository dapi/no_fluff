---
title: No Fluff UI Design Guide Index
doc_kind: engineering
doc_function: index
purpose: Curated navigation for the real Telegram Bot UI surface.
derived_from:
  - ../../dna/governance.md
  - ../frontend.md
status: active
audience: humans_and_agents
canonical_for:
  - project_ui_design_guide_routing
must_not_define:
  - product_requirements
  - domain_rules
  - frontend_architecture_contract
  - feature_interface_requirements
  - implementation_sequence
---

# UI Design Guide

No Fluff has one evidenced customer UI surface: Telegram Bot messages, commands
and inline keyboards. Generic public-web, admin, native-mobile and shared-kit
drafts were removed because no corresponding reusable runtime UI was confirmed.

## Annotated index

- [Telegram Bot UI Guide](telegram-bot.md) — entry points for message copy,
  keyboards, callbacks, channel input, delivery formatting and representative
  tests.

## Ownership

- [`../frontend.md`](../frontend.md) owns interaction/localization engineering
  rules.
- Product/domain owners define intent and language.
- Telegram clients own native visual rendering.
- Code owns exact callback payloads, helper APIs and behavior; this guide is a
  discovery map, not an implementation source of truth.
