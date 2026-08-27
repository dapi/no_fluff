---
title: No Fluff Product Vision
doc_kind: product
doc_function: canonical
purpose: Устойчивое product promise, experience principles и non-goals No Fluff без неподтверждённых claims.
derived_from:
  - ../dna/governance.md
  - context.md
status: active
audience: humans_and_agents
canonical_for:
  - product_vision
  - product_strategy_principles
---

# Product Vision

## Product promise

No Fluff помогает пользователю читать отобранные полезные публикации из
выбранных Telegram-каналов и сохраняет путь к исходному материалу. Product
promise не включает гарантию идеальной классификации, фиксированный процент
фильтрации или доказанную экономию времени до появления measurement evidence.

## Strategic bets

| Bet ID | Bet | Evidence | Review trigger |
| --- | --- | --- | --- |
| `BET-01` | Автоматическая классификация может сделать чтение выбранных Telegram-источников менее шумным | Current classifier and production-proven delivery slice | Representative quality benchmark or sustained user feedback |
| `BET-02` | Более дешёвый provider route может уменьшить cost без потери quality/latency/JSON validity | [R-001 research](../research/R-001/README.md) | Completed representative provider benchmark |

## Experience principles

- `XP-01 Source-preserving` — каждое delivered сообщение сохраняет ссылку на
  оригинальную Telegram-публикацию.
- `XP-02 User-selected sources` — current core flow начинается с канала,
  выбранного пользователем, а не с непрозрачной общей ленты.
- `XP-03 Evidence before claims` — percentage, time-saved, accuracy и cost
  claims публикуются только с dated measurement and owner.
- `XP-04 Safe failure` — rejected/invalid classification не превращается в
  ложный delivered verdict; retry и operational failure остаются видимыми.

## Product non-goals

- `PNG-01` Не считать рекомендацию каналов, social graph, summaries,
  deduplication, analytics или personalization частью доказанного current core
  только потому, что они упомянуты в roadmap/product copy.
- `PNG-02` Не оптимизировать current provider decision только по номинальному
  token price.
- `PNG-03` Не описывать customer-facing web/mobile UI, пока runtime evidence не
  подтвердит такую surface.
- `PNG-04` Не обещать поддержку private channels или scale на основании одного
  public-channel pilot.

## Decision rules

- При сопоставимом impact приоритет получает изменение, которое улучшает
  `WF-01` и имеет более сильное representative evidence.
- LLM provider/model switch допускается к delivery routing только после
  benchmark-а quality, latency, JSON validity и total observed cost.
- Новый domain concept сначала фиксируется в [`../domain/`](../domain/README.md).
