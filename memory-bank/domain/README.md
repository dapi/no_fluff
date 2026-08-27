---
title: No Fluff Domain Index
doc_kind: domain
doc_function: index
purpose: Навигация по evidence-backed предметной модели текущего No Fluff public-channel flow.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# No Fluff Domain

Этот каталог описывает язык, concepts, rules и states, доказанные текущими
моделями, сервисами, тестами и production-proven public-channel slice. Он не
promote-ит future roadmap или database table в product capability без evidence.

## Аннотированный индекс

- [Glossary](glossary.md) — canonical meanings для Telegram user, follower
  user, channel, subscription, post, classification и delivery.
- [Domain Model](model.md) — conceptual relationships и ownership boundaries,
  а не копия database schema.
- [Domain Rules](rules.md) — доказанные инварианты current import/classify/deliver
  flow.
- [Domain States](states.md) — follower authorization, channel access и
  subscription states; gaps в transition ownership отмечены явно.
- [Domain Events](events.md) — отсутствие published domain-event contract и
  граница с jobs/records.
- [Context Map](context-map.md) — provisional evidence map функциональных
  contexts; formal bounded-context ownership требует confirmation.

## Scope boundary

Current scope — Telegram public-channel subscription, MTProto import,
classification and Bot API delivery. Chat/LLM conversation tables, digests,
recommendations, personalization, analytics and private-channel workflows
остаются вне canonical current flow, пока их behavior не подтверждён.
