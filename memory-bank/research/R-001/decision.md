---
title: "R-001: Research Decision"
doc_kind: research
doc_function: canonical
purpose: No-switch decision rationale, benchmark recommendation and promotion map for R-001.
derived_from:
  - brief.md
  - ../../flows/research.md
  - synthesis.md
status: active
audience: humans_and_agents
---

# R-001: Research Decision

## Decision

| Field | Value |
| --- | --- |
| Decision owner | No Fluff owner acting as 2026-08-27 task authority |
| Decision date | 2026-08-27 |
| Decision reference | Explicit task decision, preserved through [brief](brief.md) and [evidence](evidence.md) |

Terminal disposition is owned only by sibling `brief.md`:
`research_status: invalidated` for the hypothesis that published prices alone
justify an immediate safe cost-reducing switch.

## Decision rationale

- `FND-02` makes NeuralDeep Flash a plausible nominal cost candidate.
- `FND-03`/`LIM-06` show NeuralDeep is not cheaper in every compared cell.
- `FND-04`/`LIM-01..04` show that price-only evidence cannot establish model
  equivalence, quality, latency, JSON validity or actual workload cost.
- Therefore production remains on the current direct DeepSeek path while a
  bounded benchmark is prepared. This is a no-change decision, not an accepted
  provider architecture ADR.

## Recommendation

- `REC-01` Do not switch production provider now. Confidence: high; basis
  `FND-03`, `FND-04`, `LIM-01..04`.
- `REC-02` Route a separate benchmark on representative No Fluff posts covering
  quality, latency, JSON-validity rate and observed cost, with explicit corpus,
  thresholds and owner. Do not use production as an implicit test environment.
- `REC-03` Use NeuralDeep `deepseek-v4-flash` as the first candidate. Add V4 Pro
  only if Flash fails an explicit quality requirement or new evidence makes Pro
  relevant.
- `REC-04` Re-fetch vendor rates and CBR normalization at benchmark/decision
  time; never claim NeuralDeep is always cheaper.

## Alternatives considered

| Alternative | Why not selected / what would change the decision |
| --- | --- |
| Immediate switch to NeuralDeep Flash | Rejected: missing model-equivalence and workload benchmark evidence. Could be reconsidered after accepted benchmark thresholds pass. |
| Use NeuralDeep V4 Pro first | Not selected: off-peak input is nominally 1.28x direct and no current quality requirement proves Pro necessary. |
| Conclude NeuralDeep is always cheaper | Rejected by the Pro off-peak input cell and price/model limitations. |
| Never evaluate an alternative provider | Not selected: Flash nominal rates justify a bounded benchmark, not indefinite dismissal. |

## Promotion and handoff map

| ID | Accepted or retained fact | Canonical downstream owner | Target route / link |
| --- | --- | --- | --- |
| `HD-01` | Current code path remains direct DeepSeek `deepseek-chat`; no architecture change | Engineering architecture | [Current LLM contract](../../engineering/architecture.md#llm-integration-contract) |
| `HD-02` | No production switch before representative benchmark; Flash is candidate, Pro conditional | Product roadmap | [Decision guard](../../product/roadmap.md#decision-guard) |
| `HD-03` | Benchmark signals are quality, latency, JSON validity and observed cost; thresholds unknown | Product metrics | [Provider guardrails](../../product/metrics.md#provider-evaluation-guardrails) |
| `HD-04` | Dated prices/ratios remain volatile research evidence, not evergreen product facts | Research evidence | [Evidence log](evidence.md) |

No feature package, ADR or deployment task was created. The future benchmark
must repeat Task Routing as research and add `plan.md` under its own package.

## Closure check

- [x] Sibling `brief.md` records matching terminal disposition.
- [x] Synthesis answers `RQ-01`; recommendations trace to `FND-*`/`LIM-*`.
- [x] Durable action is promoted to roadmap/metrics without duplicating dated
  price facts.
- [x] Handoff creates no implementation sequence, provider switch or deployment
  authorization.
