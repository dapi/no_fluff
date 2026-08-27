---
title: No Fluff Domain Events
doc_kind: domain
doc_function: canonical
purpose: Canonical statement of the current domain-event boundary and observed durable facts.
derived_from:
  - ../dna/governance.md
  - model.md
  - rules.md
status: active
audience: humans_and_agents
canonical_for:
  - domain_events
  - business_events
---

# Domain Events

## Current contract

No explicit published domain-event contract or event bus was identified in the
current No Fluff repository. Solid Queue jobs are technical commands/work and
database records are durable facts; neither should be renamed a domain event
without an explicit contract decision.

## Observed durable facts (not published events)

| Fact | Producer | Consumers | Evidence |
| --- | --- | --- | --- |
| Subscription relation exists/active | Telegram channel service | Recurring selection and content delivery | [Channel service](../../app/services/telegram/channel_service.rb) |
| Post imported | MTProto channel sync | Classification job | [Sync service](../../app/services/channels/mtproto_channel_sync.rb) |
| Post classified | Content process job | Delivery eligibility | [Process job](../../app/jobs/content/process_post_job.rb) |
| Delivery recorded | Delivery job after Bot API success | Duplicate prevention/operations | [Delivery job](../../app/jobs/content/deliver_posts_job.rb) |

## Event gap

If a future feature introduces cross-context published events, define event
name, producer, consumer, minimal facts, idempotency expectation and ordering
before treating it as a domain contract. Current job class names do not own that
business contract.
