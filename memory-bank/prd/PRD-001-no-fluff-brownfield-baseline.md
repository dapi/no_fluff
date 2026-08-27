---
title: "PRD-001: No Fluff Brownfield Baseline"
doc_kind: prd
doc_function: canonical
purpose: Governed current-product baseline preserving brownfield intake scope, provenance, confidence, conflicts and open questions.
derived_from:
  - ../product/context.md
  - ../product/customers.md
  - ../product/metrics.md
  - ../product/roadmap.md
  - ../domain/context-map.md
  - ../domain/rules.md
  - ../engineering/architecture.md
  - ../engineering/testing-policy.md
  - ../ops/config.md
  - ../ops/release.md
status: active
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_verify_contract
---

# PRD-001: No Fluff Brownfield Baseline

## Conversion provenance

This PRD is the governed conversion of the non-governed
[`brownfield-intake-prd.md`](../../brownfield-intake-prd.md), created before any
Memory Bank template content was opened or copied. Intake repository baseline:
`812b087b19213036a002fb605d4554762b43981e` on `main`, discovery date
2026-08-27.

Canonical product/domain/engineering/ops facts now live in the `derived_from`
owners above. The intake is retained only as historical evidence and cannot
override them.

## Problem

No Fluff addresses information overload in selected Telegram channels. The
current proven capability lets a user follow a public channel, imports its
posts through a follower user's MTProto access, classifies them and delivers
accepted posts with a source link. Broader personalization, summaries,
recommendations, analytics, private-channel support and measured market claims
are not part of this governed current baseline without additional evidence.

Confidence: high for the implemented public-channel flow; medium for the broad
user-problem framing; low for unvalidated segment and market claims. Canonical
background: [Product Context](../product/context.md).

## Users and jobs

| User / actor | Job To Be Done | Current pain / boundary | Confidence / owner |
| --- | --- | --- | --- |
| Telegram user (`SEG-01`/`ACT-01`) | Follow selected sources and receive accepted posts without manually scanning every publication | Information noise and risk of missed useful material | Medium product evidence; product owner confirmation needed |
| No Fluff administrator (`ACT-02`) | Maintain follower access and diagnose failures | Operational access/session failures; no complete runbook/SLO owner | High code evidence; operations owner needed |
| Follower user (`ACT-03`) | Supply service-side MTProto access | Service actor only; private identity/session data excluded | High code evidence; not a customer |

Details and assumptions are canonical in
[Customers And Users](../product/customers.md).

## Goals

- `G-01` Preserve the current public-channel import → classify → deliver value
  path and its source attribution.
- `G-02` Preserve idempotent post import and successful-delivery semantics.
- `G-03` Keep current/future claims evidence-bounded: unknowns remain `Unknown`
  or `TBD`, not plausible inventions.
- `G-04` Evaluate provider changes through representative quality, latency,
  JSON-validity and observed-cost evidence before production switching.

## Non-goals

- `NG-01` No runtime code, feature, schema, production config or deployment
  change is defined by this PRD.
- `NG-02` No feature package, epic or implementation sequence is created.
- `NG-03` No claim that `deepseek-chat` is identical to published DeepSeek V4
  Flash/Pro.
- `NG-04` No secret, token, API key, private phone data, Telegram session,
  encrypted value or internal endpoint is owned here.
- `NG-05` No promotion of draft market size, revenue, KPI/SLO or persona numbers
  from `.protocols/`/product copy.

## Product scope

### In scope

- Public Telegram channel add/subscription flow.
- Authorized follower-user MTProto resolve/join and bounded recurring import.
- JSON-validated DeepSeek classification and accepted-post delivery.
- Source attribution and user/post delivery ledger.
- Telegram Bot commands, inline keyboards and localized copy as the current UI.
- Dated provider pricing research and its no-switch/benchmark guard, routed
  through [R-001](../research/R-001/README.md) and
  [Product Roadmap](../product/roadmap.md).

### Out of scope

- Private-channel access, follower-pool scaling and long-term Telegram
  rate-limit guarantees.
- Unproven roadmap/product-copy capabilities.
- Customer-facing web/native-mobile UI.
- Production topology, infrastructure mutations, secret handling values and
  deploy execution.
- The future provider benchmark itself.

## UX and business rules

- `BR-01` A Telegram user follows a channel through one subscription relation.
- `BR-02` Only a classifier-accepted post is eligible for delivery.
- `BR-03` Failed Bot API sends create no successful delivery fact.
- `BR-04` One user/post pair is successfully delivered at most once.
- `BR-05` Delivered content includes the source link.
- `BR-06` Service follower accounts are not counted or described as organic
  product users.

Canonical rule definitions and evidence live in
[Domain Rules](../domain/rules.md); this PRD does not redefine their technical
implementation.

## Success metrics

| Metric ID | Metric | Baseline | Target | Measurement method / owner |
| --- | --- | --- | --- | --- |
| `MET-01` | Validated useful delivered posts per active user | `Unknown` | `TBD` | Product owner and canonical analytics source needed |
| `MET-02` | Valuable-post miss rate | `Unknown` | `TBD` | Representative labeled corpus/method needed |
| `MET-03` | Provider benchmark quality/latency/JSON validity/observed cost | Not run | Thresholds `TBD` | Separate benchmark research owner |

Existing numeric targets are not silently promoted. Canonical measurement gaps
and guardrails live in [Product Metrics](../product/metrics.md).

## Evidence and confidence ledger

| Evidence set | Supports | Freshness | Confidence / caveat |
| --- | --- | --- | --- |
| Current code/config/schema/tests | Rails stack, provider/model call, entities, queues, idempotency and response contract | Baseline inspected 2026-08-27; core slice last changed 2026-08-26 | High for implementation; code does not prove market/customer outcomes |
| [Production vertical slice](../../docs/Architecture/live-mtproto-vertical-slice.md) and [Spec 055](../../docs/Specs/055_Production_Mtproto_Delivery_Specification.md) | One public-channel initial/recurring sync and delivery path | 2026-08-26 | High for bounded recorded slice; not private channels/scale/long-term behavior |
| [Product problems](../../docs/Product/problems.md), [audience](../../docs/Product/target-audience.md), features and UX docs | Problem, audience, feature and UX intent | Mostly 2025; some 2026 update | Medium/low where no research/measurement is linked |
| [Draft PRD/metrics in `.protocols/`](../../.protocols/) | Historical hypotheses and desired process | AI-authored draft starting 2025-01-31 | Low for numeric/market/provider/current architecture claims |
| [R-001 provider research](../research/R-001/evidence.md) | Dated 2026-08-27 published rates, FX, current integration observation and ratios | Retrieved 2026-08-27 | High arithmetic/primary pricing; price volatile, model mismatch, no benchmark |

## Assumptions retained

- `ASM-01` Current repository code/config is the strongest implementation
  source; existing product docs remain intent/hypothesis sources where they
  conflict.
- `ASM-02` The 2026-08-26 vertical-slice record is accepted as historical
  production evidence but was not re-verified during this docs-only task.
- `ASM-03` Published rate cells are nominally comparable after dated FX
  normalization, but model/service equivalence and actual workload cost are not
  established.
- `ASM-04` Existing instructions remain authoritative; Memory Bank adds no
  managed agent block.

## Conflicts retained

| ID | Conflict | Governed disposition | Owner needed |
| --- | --- | --- | --- |
| `C-01` | Older C4/webhook text vs current long polling | Current README/supervisor/test/vertical slice win; webhook remains compatibility code | Engineering/operations |
| `C-02` | Older Redis claims vs Solid Cache/PostgreSQL config | Current Gemfile/database/cache config win | Engineering |
| `C-03` | Draft OpenAI/Anthropic/GPT/Claude claims vs current DeepSeek code | Current classifier/test/config win; older PRD remains draft provenance | Engineering/product |
| `C-04` | Broad feature/UX/metrics copy vs bounded current slice | Only evidence-backed current behavior promoted; rest remains hypothesis/future scope | Product |
| `C-05` | Instruction to use `ApplicationConfig` vs direct `ENV` in framework config | Application code uses `ApplicationConfig`; framework/bootstrap exception documented | Engineering |

## Risks and open questions

- `RISK-01` A cheaper nominal token rate can regress classification quality,
  latency or JSON validity.
- `RISK-02` Price/FX/model names can change after the retrieved-on date.
- `RISK-03` Older docs can be mistaken for current implemented scope.
- `RISK-04` Incomplete release/rollback/SLO ownership can make operational
  changes unsafe.

| ID | Open question | Owner | Blocks |
| --- | --- | --- | --- |
| `OQ-01` Who approves product outcomes, audience claims and benchmark thresholds? | Product owner | Metrics and benchmark acceptance |
| `OQ-02` Who owns domain language and engineering architecture? | Engineering/domain owner | Durable boundary decisions |
| `OQ-03` What are canonical SLOs, alerts, dashboards, release owner and rollback procedure? | Operations/infrastructure owner | Safe release/deployment |
| `OQ-04` Which representative posts and thresholds govern provider comparison? | Product + engineering | Benchmark execution |
| `OQ-05` What published/current backend corresponds to `deepseek-chat`? | LLM integration owner | Like-for-like model comparison |
| `OQ-06` Which product metrics are measured, and where is their source? | Product/analytics | Product outcome claims |

## Intentionally unadapted

- Secrets, credentials, encrypted files/values, private follower identity,
  phone/session data, Telegram stores, production state and infrastructure.
- Existing raw/historical docs, archived refactoring proposals, superseded
  client alternatives and demo UI details not needed for current owners.
- Unsupported numeric market/KPI/SLO/revenue claims and future feature scope.
- No `UC-*`, ADR, epic or feature package was instantiated: the adaptation
  created no delivery work and current `WF-01` is already linked directly to
  strong code/spec evidence.

## Downstream features

None. A future provider benchmark is a new Research Flow, not a feature. Any
implementation proposal after that benchmark must repeat Task Routing and create
its own canonical delivery owner.
