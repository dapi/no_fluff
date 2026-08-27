---
title: No Fluff Engineering Architecture
doc_kind: engineering
doc_function: canonical
purpose: Current code/module boundaries, runtime dataflow, concurrency, failure handling, LLM contract and configuration ownership.
derived_from:
  - ../dna/governance.md
  - ../domain/context-map.md
status: active
audience: humans_and_agents
canonical_for:
  - engineering_architecture
  - runtime_patterns
  - configuration_ownership
  - llm_integration_contract
---

# Engineering Architecture

## Evidence baseline

Current behavior is grounded in code/config/tests at repository baseline
`812b087b19213036a002fb605d4554762b43981e` and the
[2026-08-26 production vertical slice](../../docs/Architecture/live-mtproto-vertical-slice.md).
The broad [C4 document](../../docs/Architecture/c4-model.md) is useful history
but contains stale webhook, Redis and unimplemented-component claims; code and
the later vertical slice take precedence for current implementation.

## Stack and runtime boundaries

| Boundary | Current owner | Contract | Evidence |
| --- | --- | --- | --- |
| Rails application | Rails 8.0.3 API-only app on Ruby 3.4.10 | Commands/services/models/jobs and health route | [Application](../../config/application.rb), root `Gemfile` |
| User transport | Telegram Bot API | Production inbound updates use outbound long polling; outbound posts use `send_message` | `bin/jobs-supervisor`, [delivery job](../../app/jobs/content/deliver_posts_job.rb) |
| Channel access | Telegram MTProto through follower-user client/helper | Resolve/join/read public channels with encrypted session and configured proxy | [Sync service](../../app/services/channels/mtproto_channel_sync.rb) |
| Background work | Solid Queue | `channels`, `content`, recurring and notification queues; five-minute recurring sync | [Queue config](../../config/queue.yml), [recurring config](../../config/recurring.yml) |
| Persistence | PostgreSQL + Solid Cache/Cable/Queue | Primary records and separate Rails database roles | [Database config](../../config/database.yml), [cache config](../../config/cache.yml) |
| Classification | RubyLLM 1.8.x | Direct DeepSeek provider call with project JSON contract | [Classifier](../../app/services/content/post_classifier.rb) |
| Error tracking | Bugsnag plus existing notification services | Rescued errors carry useful context without credentials/session values | [Job handling](../../app/jobs/concerns/job_error_handling.rb), [Bugsnag initializer](../../config/initializers/bugsnag.rb) |

## Critical dataflow

1. Telegram command handling validates a public-channel username.
2. `Telegram::ChannelService` selects an authorized follower user, resolves and
   joins via MTProto, persists channel/subscription and queues initial sync.
3. `Channels::RecurringMtprotoChannelSyncJob` selects active, subscribed,
   public channels with an authorized follower and persisted session.
4. `Channels::MtprotoChannelSync` locks the channel, performs bounded cursor
   import and queues `Content::ProcessPostJob` only for new posts.
5. `Content::PostClassifier` returns JSON; the process job persists verdict and
   queues delivery only for accepted posts and active subscribers.
6. `Content::DeliverPostsJob` sends source text/link, then records success in
   the delivery ledger.

The webhook route and legacy Bot API persistence/join code remain compatibility
surface, not the current production update/acquisition path.

## Module boundaries

| Module / layer | Owns | Must not own directly |
| --- | --- | --- |
| `Telegram::Commands` / controllers | Bot interaction, input routing and I18n responses | MTProto session internals, provider pricing |
| `Telegram::ChannelService` + `Channels::*` | Public-channel access, assignment, import scheduling | Classification verdict or delivery success |
| `Content::PostClassifier` / process job | Provider call, response validation and persisted selection verdict | Telegram channel join or provider decision governance |
| `Content::DeliverPostsJob` | Bot API send and success ledger | Classifier selection or subscription creation |
| Active Record models | Persistence constraints and relations | Product claims or external-source truth |
| `ApplicationConfig` | Application configuration schema/default access | Production secret values or infrastructure deployment ownership |

## Concurrency and idempotency

- Recurring selector uses `limits_concurrency` for one scheduler pass.
- Channel sync runs under `Channel#with_lock`; post uniqueness is enforced per
  channel/message in model/database.
- Delivery runs under `Post#with_lock`; database uniqueness on
  `(telegram_user_id, post_id)` is the final duplicate guard.
- External Bot API success happens before ledger creation. A rejected/failed
  send creates no false success record and remains retryable.
- Bounded reads are clamped to `1..100`; current recurring default is 50.

Do not introduce a second local retry loop where Active Job already owns retry
semantics without reviewing duplicate external-effect risk.

## LLM integration contract

- `Content::PostClassifier` explicitly passes `provider: :deepseek`.
- `ApplicationConfig.llm_default_model` defaults to `deepseek-chat` in current
  environment overlays.
- `assume_model_exists: true` avoids a remote registry lookup.
- The accepted response is JSON only: `deliverable` boolean,
  `importance_score` integer clamped to 0..100, and `confidence` clamped to
  0.0..1. Invalid JSON/types/keys raise `Content::ClassificationError`.
- `deepseek-chat` is a legacy integration name. Do not assert that it is
  identical to published DeepSeek V4 Flash or V4 Pro.
- The dated price/vendor conclusion and no-switch guard are governed by
  [research R-001](../research/R-001/README.md) and
  [product roadmap](../product/roadmap.md). They do not change this current
  architecture.

## Failure handling

- Jobs inherit shared retry/error context from `ApplicationJob` and
  `JobErrorHandling`.
- Repository instructions require Bugsnag notification when rescuing errors and
  useful, sanitized metadata where possible.
- Do not log tokens, API keys, private phone data, session strings or encrypted
  values. Existing logging paths must be reviewed for sensitive payload risk
  when touched.
- A business rejection (not deliverable) is not an operational exception; an
  invalid provider response is.

## Configuration ownership

1. [`ApplicationConfig`](../../config/configs/application_config.rb) owns the
   application schema and `NO_FLUFF_` prefix.
2. [`config/no_fluff.yml`](../../config/no_fluff.yml) owns non-secret
   environment defaults such as `deepseek-chat`.
3. Rails framework configuration owns database/queue/recurring adapters and may
   read environment variables directly. This is an observed framework-level
   exception to the application-code `ApplicationConfig` convention.
4. [`../ops/config.md`](../ops/config.md) owns operational configuration and
   secret-handling procedure without values.
5. Deployment/infrastructure configuration is owned by
   `~/code/brandymint/infra`; this repository may contain build/deploy entrypoints
   but does not override the external canonical owner.

## Known gaps

- Named engineering/context owners, SLOs, alert routing and full rollback
  ownership are `Unknown`.
- Private-channel support, follower-pool scale and long-term Telegram rate
  behavior are not proven by the current slice.
- No representative quality/latency/JSON-validity/cost provider benchmark has
  been recorded.
