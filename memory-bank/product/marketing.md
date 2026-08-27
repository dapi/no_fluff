---
title: No Fluff Marketing And Positioning
doc_kind: product
doc_function: canonical
purpose: Evidence-bounded positioning, messaging and claim constraints for No Fluff.
derived_from:
  - ../dna/governance.md
  - context.md
  - customers.md
status: active
audience: humans_and_agents
canonical_for:
  - product_positioning
  - product_messaging
  - go_to_market_context
---

# Marketing And Positioning

## Positioning

| Audience | Current alternative | Product difference | Proof / confidence |
| --- | --- | --- | --- |
| `SEG-01` active Telegram-channel reader | Manually scan every selected channel | Import selected public-channel posts, classify them, and deliver accepted posts with source links | [Production-proven slice](../../docs/Architecture/live-mtproto-vertical-slice.md); high for one bounded flow, not for scale or long-term quality |

## Approved bounded messaging

- `MSG-01` «Без шелухи» помогает читать отобранные публикации из выбранных
  Telegram-каналов и сохраняет ссылку на источник.
- `MSG-02` Текущий flow использует AI classification; quality and savings claims
  require separate measurement.

## Claims requiring evidence

- Не заявлять fixed percentage removed, guaranteed accuracy, guaranteed time
  saved, perfect deduplication, proven personalization или «always cheaper».
- Не называть future roadmap capabilities current product behavior.
- Не утверждать support private channels, high scale или stable long-term rate
  limits по одному public-channel pilot.

## Channels and launch constraints

Canonical acquisition channels, campaign owner and current launch stage are
`Unknown`. Existing channel lists in product documents are hypotheses.

- `LC-01` External performance/quality/cost claims require dated evidence and an
  owner.
- `LC-02` Service follower identity and private operational data never appear in
  public messaging.
- `LC-03` Provider/model names must match the actually evaluated product; legacy
  `deepseek-chat` must not be presented as proven identical to published V4.
