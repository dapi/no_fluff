---
title: No Fluff Product Context
doc_kind: product
doc_function: canonical
purpose: Каноничное описание продукта No Fluff, текущей проблемы, доказанного core workflow и продуктовых границ.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
canonical_for:
  - project_product_context
  - product_problem_space
  - top_level_outcomes
must_not_define:
  - domain_model
  - implementation_sequence
  - architecture_decision
---

# Product Context

## Product and problem

No Fluff («Без шелухи») — Telegram-бот, который помогает пользователю не
просматривать вручную весь поток выбранных Telegram-каналов. Текущий
production-proven срез импортирует публикации публичных каналов, классифицирует
их и доставляет пользователю только публикации, признанные полезными, вместе со
ссылкой на источник.

Общий problem statement — информационная перегрузка, ручная фильтрация рекламы
и второстепенных публикаций, а также риск пропустить полезный материал. Это
documented framing; отдельная customer-research база и measured baseline в
репозитории не найдены.

## Evidence precedence

- Для текущего поведения сильнее всего code/config/tests на текущем `main` и
  [production-proven vertical slice](../../docs/Architecture/live-mtproto-vertical-slice.md)
  от 2026-08-26.
- [Product problems](../../docs/Product/problems.md),
  [features](../../docs/Product/features.md) and neighboring product documents
  владеют existing intent, но часть фич, цифр и user-flow copy описывает целевую
  картину, а не доказанный current scope.
- [AI-authored draft PRD](../../.protocols/01_Production_Requirements_Document.md)
  используется только как provenance гипотез; его market, provider, metrics и
  infrastructure claims не являются current facts.

## Core product workflows

- `WF-01 Public channel follow and delivery` — пользователь добавляет публичный
  канал; система подписывает его, импортирует публикации через MTProto,
  классифицирует и доставляет accepted posts через Bot API. Это единственный
  полностью production-proven workflow.
- `WF-02 Settings management` — пользователь может менять частоту доставки,
  формат и строгость через Telegram inline keyboard. Code и tests подтверждают
  сохранение настроек, но влияние всех значений на current delivery path не
  доказано как production workflow.
- `WF-03 Follower access administration` — администратор управляет служебными
  follower users. Это operational actor flow; private credentials и identity
  records не принадлежат Memory Bank.

Если `WF-01` понадобится как upstream для нескольких delivery packages, его
можно выделить в governed use case. В текущей documentation-only adaptation
отдельный `UC-*` не создаётся.

## Top-level outcomes

- Пользователь получает меньше сообщений, чем исходный поток, без доставки
  публикаций, отклонённых classifier-ом.
- Доставленное сообщение сохраняет исходный текст и каноническую ссылку на
  Telegram-публикацию.
- Повторный sync или delivery job не должен создавать повторную доставку той же
  публикации тому же пользователю.
- Product-level quality, retention и time-saved baselines пока `Unknown`; их
  measurement ownership описан в [metrics.md](metrics.md).

## Product constraints

- `PCON-01` Current proven source scope — публичные Telegram-каналы. Private
  channels, follower-pool scale и long-term rate limits остаются отдельными
  gates.
- `PCON-02` Telegram является current user interaction surface; customer-facing
  web/mobile application не подтверждено runtime evidence.
- `PCON-03` Provider/model changes нельзя оценивать только по прайсу: нужны
  representative quality, latency, JSON-validity и cost signals.
- `PCON-04` Нельзя публиковать или переносить credentials, private follower
  identities, phone data и session material.

## Source documents

- [Root README](../../README.md) — current local workflow и production
  long-polling statement; last changed 2026-08-26.
- [Product problems](../../docs/Product/problems.md) — problem framing; last
  changed 2025-11-02, evidence links absent.
- [Product features](../../docs/Product/features.md) — current/future feature
  narrative; interpret with code evidence.
- [Vertical slice](../../docs/Architecture/live-mtproto-vertical-slice.md) and
  [Spec 055](../../docs/Specs/055_Production_Mtproto_Delivery_Specification.md)
  — current production-proven public-channel path, dated 2026-08-26.
