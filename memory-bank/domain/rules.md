---
title: No Fluff Domain Rules
doc_kind: domain
doc_function: canonical
purpose: Evidence-backed domain rules and invariants for public-channel subscription, content selection and delivery.
derived_from:
  - ../dna/governance.md
  - model.md
status: active
audience: humans_and_agents
canonical_for:
  - domain_rules
  - domain_invariants
---

# Domain Rules

## Invariants

| Rule ID | Rule | Applies to | Why | Source |
| --- | --- | --- | --- | --- |
| `DR-01` | A Telegram user has at most one subscription relation to a channel | Subscription | Avoid ambiguous duplicate follow state | [Subscription model](../../app/models/subscription.rb), DB schema |
| `DR-02` | One channel message creates at most one post for that channel | Post import | Repeated sync must be harmless | [Post model](../../app/models/post.rb), [sync service](../../app/services/channels/mtproto_channel_sync.rb) |
| `DR-03` | Only a classified deliverable post that is neither ad nor fluff may be queued for delivery | Content selection | Preserve the core filter verdict | [Process job](../../app/jobs/content/process_post_job.rb) |
| `DR-04` | One Telegram user/post pair has at most one successful delivery record | Delivery | Prevent duplicate bot messages from retries/concurrency | [Delivery model](../../app/models/delivery.rb), [delivery job](../../app/jobs/content/deliver_posts_job.rb) |
| `DR-05` | A delivery record is created only after Bot API success | Delivery | A failed send must remain retryable and must not look delivered | [Delivery job](../../app/jobs/content/deliver_posts_job.rb), [tests](../../test/jobs/content/deliver_posts_job_test.rb) |
| `DR-06` | Delivered post text includes the canonical source link | Delivery | Preserve attribution and user path to source | [Delivery job](../../app/jobs/content/deliver_posts_job.rb) |
| `DR-07` | A follower service account is not an organic product user | Product/domain boundary | Prevent user/metrics contamination | [Product features caveat](../../docs/Product/features.md) |

## Policies

| Policy ID | Policy | Input | Output / verdict | Owner |
| --- | --- | --- | --- | --- |
| `POL-01` | Content classification | Post text | JSON-valid `deliverable`, score 0..100, confidence 0..1 or classification error | `Content::PostClassifier` |
| `POL-02` | Recurring channel eligibility | Active channel, active subscription, authorized assigned follower, persisted session, public username | Queue bounded sync or skip | `Channels::RecurringMtprotoChannelSyncJob` |
| `POL-03` | Free-channel limit | Telegram user and current subscriptions | Add allowed or subscription offer | `Limits::LimitChecker`; commercial ownership unresolved |

## Rule change policy

- Update this owner before/with any change to acceptance, uniqueness or
  delivery-success semantics.
- Technical batch size, queue concurrency, locks and retries belong in
  [`../engineering/architecture.md`](../engineering/architecture.md).
- Any change requiring private-channel or scale claims needs new evidence; the
  current pilot does not establish them.
