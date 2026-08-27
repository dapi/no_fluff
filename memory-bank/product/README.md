---
title: No Fluff Product Index
doc_kind: product
doc_function: index
purpose: Навигация по каноническому продуктовому контексту No Fluff.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# No Fluff Product

Этот каталог владеет устойчивым product-level контекстом. Текущий код владеет
реализацией, `domain/` — предметными правилами, а existing `docs/Product/`
остаётся источником product intent и гипотез с указанной freshness.

## Аннотированный индекс

- [Product Context](context.md) — текущая проблема, доказанный core workflow,
  продуктовые границы и provenance.
- [Vision](vision.md) — подтверждённое product promise, experience principles и
  non-goals без неподтверждённых рекламных обещаний.
- [Customers And Users](customers.md) — пользователи, системные actors, jobs и
  непроверенные audience hypotheses.
- [Product Metrics](metrics.md) — известные измерительные gaps, candidate
  quality signals и правила, запрещающие считать draft targets baseline.
- [Marketing And Positioning](marketing.md) — допустимое positioning и claims,
  а также claims, требующие evidence.
- [Product Roadmap](roadmap.md) — только подтверждённые themes и открытые bets;
  feature backlog остаётся в существующем [`docs/ROADMAP.md`](../../docs/ROADMAP.md).

## Ownership boundary

- Этот каталог не переопределяет существующие repository instructions,
  specification lifecycle или runtime code.
- `docs/Product/` и `.protocols/` не копируются сюда целиком: broad claims,
  цифры и future scope остаются источниками гипотез до подтверждения.
- Named product owner в репозитории не найден; owner confirmation остаётся
  открытым вопросом в governed PRD.
