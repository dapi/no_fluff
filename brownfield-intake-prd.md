# Brownfield intake PRD: No Fluff

Status: historical provenance; converted and not a governed source of truth
Created: 2026-08-27
Repository baseline: `812b087b19213036a002fb605d4554762b43981e` on `main`
Governed conversion: [`memory-bank/prd/PRD-001-no-fluff-brownfield-baseline.md`](./memory-bank/prd/PRD-001-no-fluff-brownfield-baseline.md)
Discovery boundary: existing repository instructions, documentation, code,
configuration, deploy definitions, and tests only. Production, infrastructure,
secret stores, Telegram session stores, and private data were not inspected.

## Purpose and retention

This temporary document records the evidence used to adapt Memory Bank into the
existing No Fluff repository. It must be converted into a governed PRD whose
dependencies point to adapted canonical owners. After conversion this file is
historical provenance only, not a second active product or architecture owner.

## Current product problem

No Fluff is a Telegram bot intended to reduce information overload by following
channels selected by a user, classifying imported posts, and delivering only
posts classified as useful rather than fluff or advertising. The durable value
claim is reduced manual filtering and a lower risk of missing useful content.

Evidence: [root README](./README.md),
[documented problems](./docs/Product/problems.md),
[classifier](./app/services/content/post_classifier.rb), and
[production-proven vertical slice](./docs/Architecture/live-mtproto-vertical-slice.md).
Confidence: high for the implemented import/classify/deliver flow; medium for
the broader user-problem framing because the product documents do not include
linked validation data. Owner: product owner needs confirmation. Freshness:
code and vertical-slice evidence were last changed 2026-08-26; the problem
document was last changed 2025-11-02.

## Users and jobs

### Observed actors

- A Telegram user starts the bot, manages channel subscriptions and settings,
  and receives accepted posts through Telegram Bot API messages.
- An administrator manages follower-user access and receives operational error
  paths. The first Telegram user can become the first administrator according
  to current command code.
- A follower user is a service-side Telegram account used through MTProto to
  resolve, join, and read channels. Its credentials and session material are
  sensitive operational data and are deliberately absent from this intake.

Evidence: [start command](./app/services/telegram/commands/start_command.rb),
[channel command](./app/services/telegram/commands/channel_command.rb),
[channel service](./app/services/telegram/channel_service.rb),
[settings agent](./app/services/telegram/settings_agent.rb), and
[vertical slice](./docs/Architecture/live-mtproto-vertical-slice.md).
Confidence: high for code-level behavior. Owner: product owner for user jobs;
application maintainer for implementation; both need explicit confirmation.
Freshness: inspected at the repository baseline on 2026-08-27.

### Documented audience hypotheses

Existing product material names digitally experienced, Russian-speaking
professionals, entrepreneurs, analysts, content creators, and other heavy
Telegram-channel readers. Demographics, willingness to pay, channel counts,
and time-saving estimates are hypotheses rather than verified facts because the
documents do not link supporting research.

Evidence: [target audience](./docs/Product/target-audience.md) and
[existing draft PRD](./.protocols/01_Production_Requirements_Document.md).
Confidence: low to medium. Owner: product owner needs confirmation. Freshness:
the audience document was last changed 2025-10-01; the existing PRD identifies
itself as an AI-authored draft created 2025-01-31.

## Goals

- Preserve an evidence-backed description of the current product and its
  import → classify → deliver path.
- Make product, domain, engineering, and operations ownership navigable without
  replacing existing repository instructions or documentation.
- Preserve uncertainties and conflicts instead of promoting aspirational
  documents to current facts.
- Govern provider-pricing research separately from product and engineering
  owners, with explicit evidence, assumptions, and a decision record.

These are adaptation goals derived from the current task and the inspected
repository; they are not a delivery plan.

## Non-goals

- No application behavior, runtime code, existing documentation, deployment,
  infrastructure, production state, secret, or Telegram session change.
- No new product feature, epic, implementation plan, or selected architecture.
- No assertion that all documented product features, personas, metrics, or
  monetization ideas are implemented or validated.
- No benchmark execution and no provider switch in this adaptation.
- No reproduction of credentials, private phone numbers, session material,
  internal endpoints, or encrypted values.

## Current scope and durable flow

The current production-proven slice is:

1. A user adds a public channel through the Telegram bot.
2. The application resolves and joins the channel with an authorized follower
   user over MTProto, persists the channel/subscription, and queues an initial
   bounded sync.
3. A Solid Queue recurring job selects eligible active subscribed public
   channels every five minutes and queues bounded MTProto syncs.
4. Imported posts are unique per channel/message, then classified through
   RubyLLM.
5. Only deliverable posts are queued for Telegram Bot API delivery.
6. A database-unique delivery ledger prevents duplicate user/post delivery and
   records a delivery only after a successful Bot API response.

Evidence: [Spec 055](./docs/Specs/055_Production_Mtproto_Delivery_Specification.md),
[vertical slice](./docs/Architecture/live-mtproto-vertical-slice.md),
[channel sync service](./app/services/channels/mtproto_channel_sync.rb),
[recurring job](./app/jobs/channels/recurring_mtproto_channel_sync_job.rb),
[process job](./app/jobs/content/process_post_job.rb), and
[delivery job](./app/jobs/content/deliver_posts_job.rb).
Confidence: high for the bounded public-channel path. Owner: application
maintainer; needs explicit confirmation. Freshness: implementation and live
evidence were last changed 2026-08-26.

Private-channel behavior, follower-pool scaling, and long-term Telegram
rate-limit behavior are not established by the single production-proven slice.
Evidence: the explicit caveat in the
[vertical slice](./docs/Architecture/live-mtproto-vertical-slice.md).
Confidence: high that these remain gaps. Owner: application/operations owner
needs confirmation.

## Success signals

### Verified technical signals

- The 2026-08-26 production record reports session restoration after process
  and pod recreation, bounded post import, a duplicate-free second sync,
  classification, successful delivery, and empty ready/failed queues after the
  recurring pass.
- Tests cover explicit DeepSeek provider/model selection, accepted/rejected
  classification, bounded recurring sync eligibility, post import idempotency,
  delivery-ledger uniqueness, and failed-delivery retryability.
- CI is configured to run Brakeman, RuboCop, and the Rails test suite.

Evidence: [vertical slice](./docs/Architecture/live-mtproto-vertical-slice.md),
[classifier test](./test/services/content/post_classifier_test.rb),
[process test](./test/jobs/content/process_post_job_test.rb),
[sync test](./test/services/channels/mtproto_channel_sync_test.rb),
[delivery test](./test/jobs/content/deliver_posts_job_test.rb), and
[CI workflow](./.github/workflows/ci.yml). Confidence: high for what these
artifacts explicitly test or report. Owner: engineering/operations owner needs
confirmation. Freshness: core slice tests and production record are dated
2026-08-26; CI was last changed 2026-01-29.

### Unverified product signals

Onboarding conversion, retained use, time saved, classification quality,
latency, JSON validity, and cost per representative post are useful candidate
signals, but the repository contains no current measured baseline accepted as
canonical. Numeric acquisition, retention, revenue, uptime, response-time, and
coverage targets in `.protocols/` and product copy must remain hypotheses until
an owner and measurement source confirm them.

Evidence: [user flow](./docs/Product/user-flow.md),
[existing draft PRD](./.protocols/01_Production_Requirements_Document.md), and
[success metrics draft](./.protocols/04_Success_Metrics_Framework.md).
Confidence: high that these targets are documented; low that they are measured
or approved. Owner: product/operations owners need confirmation. Freshness:
the source documents predate the 2026-08-26 production slice.

## Inventory summary

### Runtime modules and boundaries

- Rails 8.0.3 API-only application on Ruby 3.4.10.
- Telegram Bot API boundary for user commands and outbound delivery; production
  updates use an outbound long-polling process supervised with jobs.
- Telegram MTProto boundary for follower-user channel access; a helper process
  is invoked by the application-owned service.
- RubyLLM boundary for post classification. The current classifier explicitly
  selects provider `deepseek`, reads the configured model, and requires JSON
  with `deliverable`, `importance_score`, and `confidence`.
- PostgreSQL-backed primary data, Solid Queue, Solid Cache, and Solid Cable.
- Bugsnag calls and Rails `/up` health route are present; a complete alert/SLO
  ownership record was not found.

Evidence: [application config](./config/application.rb),
[Gemfile](./Gemfile), [locked dependencies](./Gemfile.lock),
[jobs supervisor](./bin/jobs-supervisor),
[classifier](./app/services/content/post_classifier.rb),
[database config](./config/database.yml), [cache config](./config/cache.yml),
[queue config](./config/queue.yml), and [routes](./config/routes.rb).
Confidence: high. Owner: engineering owner needs confirmation. Freshness:
inspected at the repository baseline on 2026-08-27.

### Domain/data inventory

The current schema and models include Telegram users, follower users, channels,
subscriptions, posts, deliveries, feedback, user preferences, digests and
digest items, chats/messages/tool calls/models, classifications, settings, and
deploy notifications. Durable uniqueness exists for a channel/message post, a
user/channel subscription, and a user/post delivery. Channel access and
follower authorization have explicit state enums.

Evidence: [schema](./db/schema.rb), [channel model](./app/models/channel.rb),
[follower-user model](./app/models/follower_user.rb),
[subscription model](./app/models/subscription.rb),
[post model](./app/models/post.rb), and
[delivery model](./app/models/delivery.rb). Confidence: high for schema and
model declarations. Owner: domain/engineering owner needs confirmation.
Freshness: inspected at the repository baseline on 2026-08-27.

### API, UI, jobs, and external integrations

- The user-facing surface evidenced in current code is Telegram messages,
  commands, and inline keyboards. The Rails application is API-only; no
  current customer-facing web UI contract is established by the inspected
  runtime code.
- Routes expose Rails health, a Telegram webhook-compatible route retained in
  code, and a Solid Queue dashboard mount. Production delivery documentation
  says webhook is not the active update transport.
- Recurring MTProto synchronization is scheduled every five minutes in
  development and production. Queues separate channel, content, recurring, and
  notification work.
- External boundaries are Telegram Bot API, Telegram MTProto, the configured
  LLM provider, PostgreSQL, and Bugsnag.

Evidence: [application config](./config/application.rb),
[routes](./config/routes.rb), [start command](./app/services/telegram/commands/start_command.rb),
[settings agent](./app/services/telegram/settings_agent.rb),
[recurring config](./config/recurring.yml), and
[queue config](./config/queue.yml). Confidence: high for current code/config;
medium for runtime activation outside the production-proven slice. Owner:
engineering/operations owner needs confirmation.

### Configuration, secrets, environments, and deployment

- Application settings use `ApplicationConfig`/Anyway Config with the
  `NO_FLUFF_` prefix; model default is `deepseek-chat` in test, development,
  and production config. The classifier hard-codes the provider boundary to
  DeepSeek.
- Framework-level database and worker configuration also reads environment
  variables directly, which is an exception/conflict with the repository
  instruction to access application values through `ApplicationConfig`.
- Test, development, and production environments are defined. Local
  development is documented through Dip with Docker and PostgreSQL 17.
- A Kamal deploy definition, production Dockerfile, image workflow, Makefile
  deployment targets, and production verification script exist. Per repository
  instructions supplied for this task, canonical deployed-application
  infrastructure belongs to `~/code/brandymint/infra`; it was intentionally not
  inspected or changed.
- Secret values, encrypted credentials, runtime environment, and secret stores
  were not inspected. Ownership is recorded only as an open operational
  procedure.

Evidence: [repository instructions](./CLAUDE.md),
[application configuration class](./config/configs/application_config.rb),
[non-secret defaults](./config/no_fluff.yml),
[classifier](./app/services/content/post_classifier.rb),
[database config](./config/database.yml), [Dip config](./dip.yml),
[root README](./README.md), [deploy config](./config/deploy.yml),
[Dockerfile](./Dockerfile), and [Makefile](./Makefile). Confidence: high for
repository definitions; unknown for live environment state except separately
supplied research facts. Owner: application vs infrastructure ownership needs
confirmation; infrastructure repository ownership is fixed by the task-level
repository instructions. Freshness: deploy/app sources were last changed no
later than 2026-08-26.

### Testing and change conventions

- Repository instructions require Minitest, tests-first development, I18n for
  bot text, `ApplicationConfig` for application configuration, Bugsnag
  notification on rescued errors, and RuboCop for Ruby changes.
- The canonical local full-suite command documented in the README is
  `dip test`; CI runs `bin/rails db:test:prepare test`, RuboCop, and Brakeman.
- Existing specifications use a separate lifecycle ending in `delivered`; this
  remains authoritative for existing `docs/Specs/` artifacts and is not
  replaced by Memory Bank.

Evidence: [repository instructions](./CLAUDE.md),
[testing guidelines](./.claude/TESTING_GUIDELINES.md),
[root README](./README.md), [CI workflow](./.github/workflows/ci.yml), and
[specification workflow](./docs/Specification_Workflow_Guide.md).
Confidence: high for documented conventions. Owner: engineering/process owner
needs confirmation. Freshness varies; instructions are authoritative until
changed, while testing and specification guides contain older examples.

### Existing documentation and freshness concerns

- `docs/Product/` owns existing product narratives; some pages describe future
  capabilities and unsupported numeric claims alongside current behavior.
- `docs/Architecture/c4-model.md` is broad and partially stale relative to the
  2026-08-26 vertical slice and code.
- `docs/Specs/` and `docs/Implementation/` retain the established feature
  specification and delivery history.
- `.protocols/` contains an AI-authored draft PRD, metric framework, and process
  proposals. They are useful as hypothesis provenance but not current evidence
  for market size, KPIs, providers, infrastructure, or implemented scope.
- `docs/Design/` describes a Telegram-like demonstration interface; it is not
  evidence of a current customer-facing web UI.

Owner: each existing documentation family remains authoritative in its current
repository role until explicitly superseded; individual maintainers need
confirmation. Confidence: high for this classification based on source status,
dates, and conflicts with current code.

## Risks

- Classification quality or JSON validity may regress when model/provider
  changes even when token prices are lower.
- LLM price sheets and exchange rates are volatile and do not include every
  production cost or routing behavior.
- Provider/model naming differs between the current `deepseek-chat` integration
  and the published DeepSeek V4 products used for current price comparison.
- Current production evidence is one bounded public-channel slice and must not
  be generalized to private channels, scale, or long-term rate limits.
- Older product, architecture, UI, and metrics documents can be mistaken for
  implemented/current behavior.
- Operations ownership, rollback procedure, alert routing, SLOs, and current
  production topology are incomplete in this repository and were out of scope
  for inspection.

## Assumptions

- Repository code/config at the recorded baseline is the strongest source for
  current implementation behavior.
- The 2026-08-26 vertical-slice record is accepted as historical production
  evidence but is not re-verified during this documentation-only task.
- User-supplied 2026-08-27 provider access and pricing facts will be recorded as
  dated research evidence without inspecting production credentials.
- Existing repository instructions remain authoritative after Memory Bank is
  installed; no managed agent block will be installed.

## Conflicts

| ID | Conflict | Evidence and disposition | Owner |
| --- | --- | --- | --- |
| C-01 | Webhook vs long polling | The older C4 and live route mention webhook, while the current README, supervisor, tests, and production slice identify long polling as active. Record long polling as current production transport and retain webhook as compatibility code, not the production path. | Engineering/operations owner needs confirmation |
| C-02 | Redis/cache claims vs Solid Cache | The older C4 and draft PRD name Redis, while current Gemfile and cache/database config use Solid Cache backed by PostgreSQL. Treat current config as authoritative. | Engineering owner needs confirmation |
| C-03 | OpenAI/Anthropic vs DeepSeek | The 2025 draft PRD names OpenAI/Anthropic and GPT/Claude, while current classifier code and tests explicitly select DeepSeek and `deepseek-chat`. Treat code/test as current; keep the older claims as stale draft provenance. | Engineering/product owner needs confirmation |
| C-04 | Implemented scope vs broad feature copy | Product, UI, roadmap, and metrics documents include personalization, summaries, deduplication, recommendations, analytics, monetization, and web/demo surfaces that are not all proven by the current vertical slice. Adapt only code- or production-evidenced behavior and label the rest as hypotheses/future scope. | Product owner needs confirmation |
| C-05 | Configuration convention | Repository instructions prohibit direct application `ENV` access, while framework database/queue/bootstrap files use it. Preserve the instruction for application code and record framework configuration as an observed exception pending owner confirmation. | Engineering owner needs confirmation |

## Open questions

| ID | Question | Evidence | Needed owner |
| --- | --- | --- | --- |
| Q-01 | Who approves product outcomes, audience claims, and benchmark acceptance criteria? | No CODEOWNERS/ownership record was found. | Product owner |
| Q-02 | Who owns application architecture, domain terminology, and engineering conventions? | Responsibilities are implied by docs but not assigned to a named role. | Engineering owner |
| Q-03 | What are the canonical SLOs, alerts, dashboards, escalation path, release owner, and rollback procedure? | Health/Bugsnag/deploy assets exist; a complete runbook was not found and external infra was out of scope. | Operations/infrastructure owner |
| Q-04 | Which representative No Fluff posts and acceptance thresholds should govern the provider benchmark? | Current tests mock one JSON response; no representative benchmark corpus or thresholds are canonical. | Product + engineering owners |
| Q-05 | Which current model is actually served behind the legacy `deepseek-chat` name, and how is it comparable to published V4 Flash/Pro products? | Code names `deepseek-chat`; current price sheets name V4 Flash/Pro. | LLM/provider owner |
| Q-06 | Which product metrics are measured today, and where is the canonical data source? | Existing numeric targets are draft/hypothesis material without linked measurements. | Product/analytics owner |

## Intentionally unadapted facts and documents

- Secret values, encrypted credentials, API keys, tokens, private phone data,
  follower-user session strings, Telegram session/store contents, and runtime
  environment values.
- Production and infrastructure state, including the external canonical infra
  repository; only repository-local ownership/navigation may be referenced.
- Specific service-account identity and pilot-account private details.
- Market size, revenue forecasts, willingness-to-pay claims, competitor matrix,
  and numeric KPI/SLO targets from `.protocols/` because they lack validated
  evidence and current owners.
- Future roadmap capabilities and unproven product-copy claims.
- Web/demo visual-system details from `docs/Design/`; the durable current UI
  owner should cover Telegram message and inline-keyboard interaction only.
- Archived refactoring proposals, obsolete implementation alternatives,
  superseded MTProto/TDLib studies, and code examples not needed to describe the
  current production-proven slice.
- No use cases beyond the evidenced public-channel import/classify/deliver flow,
  and no historical ADR unless the installed governance requires one for an
  already-made decision that remains materially active.

## Conversion requirements

The governed PRD must:

- depend only on adapted product, domain, engineering, and operations owners;
- retain the repository baseline, evidence links, confidence, freshness,
  conflicts, assumptions, open questions, and intentionally unadapted list;
- remain documentation-only and create no delivery package or implementation
  plan;
- route the separate 2026-08-27 DeepSeek-vs-NeuralDeep research conclusion
  through governed research and decision indexes;
- mark this intake as historical provenance after conversion.
