---
title: No Fluff Domain Glossary
doc_kind: domain
doc_function: canonical
purpose: Ubiquitous language и запрещённые двусмысленности current No Fluff domain.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
canonical_for:
  - ubiquitous_language
  - domain_terms
---

# Domain Glossary

## Terms

| Term | Meaning | Context | Do not confuse with |
| --- | --- | --- | --- |
| `Telegram user` | End user represented by `TelegramUser`, who interacts with the bot and owns subscriptions | Subscription and delivery | `Follower user` service account |
| `Follower user` | Service-side Telegram account with encrypted MTProto session, assigned to channels for access | Channel acquisition | Customer, organic user, bot identity or public persona |
| `Channel` | Persisted Telegram channel identified by Telegram id and username | Subscription and acquisition | A generic chat/group; current proven flow covers public channels |
| `Subscription` | Unique relation between a Telegram user and a channel; only active relations are eligible for delivery/sync selection | Subscription | Commercial payment subscription |
| `Post` | One imported Telegram channel message, unique by channel and Telegram message id | Content selection | Delivered bot message or digest item |
| `Classification` | Classifier verdict containing deliverability, importance score and confidence, persisted onto a post | Content selection | Provider response text before JSON validation |
| `Deliverable post` | Classified post accepted for delivery and not marked as advertising or fluff | Content selection and delivery | Any imported or merely queued post |
| `Delivery` | Durable record created only after successful Bot API delivery for one Telegram user/post pair | Delivery | Enqueue attempt, retry, imported post or Telegram source message |
| `Source link` | Canonical `t.me/<channel>/<message>` link appended to delivered text | Delivery | Internal record identifier |
| `Digest` | Persisted data concept present in schema/models | Legacy/future scope | Current proven delivery format; current slice sends individual posts |

## Naming rules

- Use `Bot API` for user interaction/delivery and `MTProto` for follower-user
  channel access.
- Use `delivered` only when a successful Bot API response is followed by a
  durable `Delivery` record.
- Use `production-proven` only within the explicit bounds of the
  [2026-08-26 vertical slice](../../docs/Architecture/live-mtproto-vertical-slice.md).

## Ambiguous terms

| Term | Allowed meaning | Forbidden / overloaded meaning | Replacement |
| --- | --- | --- | --- |
| `user` | State whether `Telegram user` or `Follower user` | Treat both as the same actor | Use the explicit term |
| `subscription` | Telegram user ↔ channel relation | Paid plan without qualification | `channel subscription` or `commercial plan` |
| `joined` | Follower-user channel access state when discussing MTProto | Bot API membership or an enqueue attempt | `MTProto access joined` / `Bot API membership` |
| `DeepSeek V4` | Published V4 Flash or Pro product named by source | Assume identity with legacy `deepseek-chat` | State exact model name and mismatch |

## Sources

- [Schema](../../db/schema.rb),
  [`TelegramUser`](../../app/models/telegram_user.rb),
  [`FollowerUser`](../../app/models/follower_user.rb), and
  [production vertical slice](../../docs/Architecture/live-mtproto-vertical-slice.md).
- Identity/session details are intentionally excluded.
