---
title: No Fluff Domain Context Map
doc_kind: domain
doc_function: canonical
purpose: Provisional evidence map of current functional contexts and language boundaries; formal owners remain pending.
derived_from:
  - ../dna/governance.md
  - glossary.md
  - model.md
status: active
audience: humans_and_agents
canonical_for:
  - bounded_contexts
  - domain_context_map
---

# Domain Context Map

## Confidence boundary

Existing code names functional modules/services but does not declare a formal
DDD bounded-context map or named context owners. The table below is therefore a
provisional evidence map, not a claim that team ownership or service boundaries
have been finalized.

## Observed functional contexts

| Context | Owns language / rules for | Upstream | Downstream | Must not own |
| --- | --- | --- | --- | --- |
| `Subscription Management` | Telegram user follows/removes channels and free-channel limit verdict | Telegram user interaction | Channel Acquisition, Content Delivery | MTProto session material or classifier verdict |
| `Channel Acquisition` | Follower assignment, resolve/join and bounded message import | Subscription Management, authorized follower state | Content Selection | Product metrics or delivery-success fact |
| `Content Selection` | Classification response contract and deliverable verdict | Imported post | Content Delivery | Provider pricing decision or user subscription ownership |
| `Content Delivery` | Bot API send, source attribution and user/post success ledger | Active subscription + deliverable post | User and operations | MTProto join or classifier policy internals |

## Relationships

| ID | Upstream | Downstream | Current contract | Evidence |
| --- | --- | --- | --- | --- |
| `REL-01` | Subscription Management | Channel Acquisition | Persist subscription and enqueue initial/bounded sync | [Channel service](../../app/services/telegram/channel_service.rb) |
| `REL-02` | Channel Acquisition | Content Selection | Persist unique post and enqueue process job | [Sync service](../../app/services/channels/mtproto_channel_sync.rb) |
| `REL-03` | Content Selection | Content Delivery | Enqueue only accepted post for active subscribers | [Process job](../../app/jobs/content/process_post_job.rb) |
| `REL-04` | Content Delivery | Operations | Durable success record or retryable failure | [Delivery job](../../app/jobs/content/deliver_posts_job.rb) |

## Shared language

- `Channel`, `Post`, `TelegramUser` and `Delivery` are shared through Active
  Record models; exact runtime coupling is documented in
  [`../engineering/architecture.md`](../engineering/architecture.md).
- Bot API and MTProto are distinct published integration boundaries.

## Open boundary questions

- `OQ-01` Named business/context owners are `Unknown`.
- `OQ-02` Settings, digest, feedback/personalization and chat/LLM conversation
  models are not placed into a canonical context until current behavior is
  evidenced.
- `OQ-03` Legacy Bot API webhook/join compatibility code overlaps current
  MTProto paths; engineering owns the compatibility boundary.
