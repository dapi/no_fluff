---
title: No Fluff Domain Model
doc_kind: domain
doc_function: canonical
purpose: Conceptual model and relationships for the current public-channel import, classification and delivery flow.
derived_from:
  - ../dna/governance.md
  - glossary.md
status: active
audience: humans_and_agents
canonical_for:
  - domain_model
  - domain_concepts
---

# Domain Model

## Concepts

| Concept | Kind | Owns / represents | Key relationships | Evidence |
| --- | --- | --- | --- | --- |
| `TelegramUser` | actor/entity | Bot end user and delivery preferences | Has channel subscriptions and deliveries | [Model](../../app/models/telegram_user.rb) |
| `FollowerUser` | service actor/entity | MTProto authorization/session and channel workload | Assigned to channels | [Model](../../app/models/follower_user.rb) |
| `Channel` | entity | Telegram source identity and access/assignment state | Has subscriptions/posts; optional follower | [Model](../../app/models/channel.rb) |
| `Subscription` | relation/entity | Telegram user follows one channel | Belongs to user and channel | [Model](../../app/models/subscription.rb) |
| `Post` | entity | Imported source publication and classifier result | Belongs to channel; has deliveries | [Model](../../app/models/post.rb) |
| `Classification policy` | policy | Converts post text to a deliverability verdict | Updates post; gates delivery enqueue | [Classifier](../../app/services/content/post_classifier.rb), [process job](../../app/jobs/content/process_post_job.rb) |
| `Delivery` | fact/entity | Successful user/post delivery ledger | Belongs to Telegram user and post | [Model](../../app/models/delivery.rb), [delivery job](../../app/jobs/content/deliver_posts_job.rb) |

## Relationship map

1. A `TelegramUser` follows a `Channel` through one `Subscription`.
2. A `FollowerUser` may be assigned to multiple `Channel` records and supplies
   authorized MTProto access.
3. A `Channel` owns imported `Post` records; the channel/message identity must
   remain unique.
4. A `Classification policy` decides whether a persisted `Post` is eligible
   for delivery.
5. A successful user/post send creates one `Delivery`; failure creates no
   success record and remains retryable.

## Concept ownership

| Concept | Canonical runtime owner | Allowed writers | Allowed readers | Notes |
| --- | --- | --- | --- | --- |
| Subscription | `Subscription` + Telegram channel services | Bot command/service paths | Sync eligibility and delivery selection | Commercial plan is a different concept |
| Channel access | `Channel` + `FollowerUser` | MTProto authorization/join/sync services | Sync scheduler and diagnostics | Private session material is not documentation data |
| Post/classification | `Post` + `Content::PostClassifier`/process job | Import and classification jobs | Delivery job, feedback/digest code | Code owns exact persistence behavior |
| Delivery fact | `Delivery` + delivery job | Only successful delivery path | Idempotency check and operations | DB uniqueness is final enforcement |

## Model boundaries

- `MB-01` Database tables for chats, tool calls, digests, feedback and
  preferences do not by themselves prove a current product workflow.
- `MB-02` Legacy Bot API join/webhook compatibility state remains in code but is
  not the current MTProto acquisition owner.
- `MB-03` Provider, queue, lock and retry mechanisms are engineering concerns,
  documented in [`../engineering/architecture.md`](../engineering/architecture.md).
- `MB-04` Follower identity and credential/session values are explicitly
  outside this model.
