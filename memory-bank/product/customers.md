---
title: No Fluff Customers And Users
doc_kind: product
doc_function: canonical
purpose: Каноничное описание подтверждённых actors, user jobs и непроверенных audience hypotheses No Fluff.
derived_from:
  - ../dna/governance.md
  - context.md
status: active
audience: humans_and_agents
canonical_for:
  - product_customers
  - user_segments
  - jobs_to_be_done
---

# Customers And Users

## Segments

| Segment ID | Segment | Job To Be Done | Current Pain | Success Signal | Evidence / confidence |
| --- | --- | --- | --- | --- | --- |
| `SEG-01` | Активный читатель Telegram-каналов | Следить за выбранными источниками, не просматривая вручную весь поток | Информационный шум и риск пропустить полезное | Полезные delivered posts при приемлемом числе пропусков | [Product problems](../../docs/Product/problems.md) и [target audience](../../docs/Product/target-audience.md); medium, customer validation не linked |

Профессиональные, предпринимательские, инвестиционные и другие persona из
existing target-audience документа остаются segmentation hypotheses. Нет
evidence, позволяющего назначить им priority или подтвердить demographics,
willingness to pay и объём чтения.

## Users and actors

| Actor ID | Actor | Uses product how | Decision power | Evidence |
| --- | --- | --- | --- | --- |
| `ACT-01` | Telegram user | Добавляет/удаляет каналы, меняет настройки, получает posts | End user; purchase/buyer role unknown | [Commands](../../app/services/telegram/commands/channel_command.rb), [settings](../../app/services/telegram/settings_agent.rb) |
| `ACT-02` | No Fluff administrator | Управляет follower access и диагностическими paths | Operational administrator | [Start command](../../app/services/telegram/commands/start_command.rb), existing admin code/tests |
| `ACT-03` | Follower user | Служебный MTProto actor для чтения каналов | Не customer и не organic user | [Follower model](../../app/models/follower_user.rb), [sync service](../../app/services/channels/mtproto_channel_sync.rb) |

## Assumptions

- `ASM-01` Пользователь считает AI-filtering полезнее ручного просмотра. Это
  должно проверяться representative product evidence, а не product copy.
- `ASM-02` Пользователь принимает риск false negatives. Допустимый уровень и
  owner решения `Unknown`.
- `ASM-03` Free/premium segmentation существует в code, но current commercial
  model, payment flow и willingness to pay не подтверждены как product facts.

## Must not assume

- `NA-01` Не считать demographic и market-size цифры validated.
- `NA-02` Не считать служебного follower user реальным customer или organic
  growth.
- `NA-03` Не считать наличие `Feedback`, digest или preference models
  доказательством использования этих возможностей в production.
- `NA-04` Не переносить identity, phone или session details служебных actors в
  governed documentation.
