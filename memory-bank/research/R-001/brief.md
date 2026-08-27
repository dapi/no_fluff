---
title: "R-001: DeepSeek vs NeuralDeep Pricing"
doc_kind: research
doc_function: canonical
purpose: Canonical decision question, boundaries, method and terminal disposition for provider-pricing research R-001.
derived_from:
  - ../../flows/research.md
  - ../../product/context.md
  - ../../product/metrics.md
  - ../../engineering/architecture.md
status: active
research_status: invalidated
audience: humans_and_agents
---

# R-001: DeepSeek vs NeuralDeep Pricing

## Intake

| Field | Value |
| --- | --- |
| Source / trigger | Explicit 2026-08-27 task to govern the supplied current pricing conclusion; adaptation provenance begins in [`brownfield-intake-prd.md`](../../../brownfield-intake-prd.md) |
| Research owner | No Fluff engineering/product research role; named owner not recorded |
| Decision owner | No Fluff owner acting as task authority |
| Research mode | `technical_discovery` |
| Decision deadline / timebox | Dated desk research retrieved and decided 2026-08-27 |

## Decision question

- `RQ-01` Is currently published DeepSeek-vs-NeuralDeep pricing evidence
  sufficient to switch No Fluff production from its direct DeepSeek
  `deepseek-chat` integration, and if not, what is the evidence-bounded next
  step?

## Working hypotheses

- `HYP-01` Published token rates alone establish a safe, cost-reducing immediate
  production switch to NeuralDeep. Terminal result: invalidated because model
  identity and representative quality/latency/JSON-validity/observed-cost
  evidence are missing, and NeuralDeep is not cheaper in every compared cell.
- `HYP-02` NeuralDeep `deepseek-v4-flash` is the proportionate first benchmark
  candidate; V4 Pro need not be benchmarked first unless Flash fails quality or
  another explicit requirement needs Pro. Status: recommendation, not proven
  production choice.

## Compact method record

- Method and source strategy: dated desk research using primary published
  DeepSeek prices, NeuralDeep pricing plus its public wallet-rate endpoint, the
  official CBR USD/RUB daily rate, current repository code/config/tests, and the
  task-authority operational observation.
- Collection window and context: all external facts were supplied as retrieved
  on 2026-08-27; repository evidence baseline is
  `812b087b19213036a002fb605d4554762b43981e`.
- Evidence-quality criteria: primary publisher/regulator source, exact per-1M
  unit, explicit currency and dated freshness; calculations must be
  reproducible from recorded inputs.
- Privacy/security/vendor constraints: no provider credentials, production
  environment, secret store, wallet, Telegram session or private data was
  inspected. Only absence/presence observations supplied by task authority are
  recorded without values.
- Bias risks and disconfirming signal: nominal price can dominate attention over
  model quality and actual workload. NeuralDeep Pro off-peak input ratio above
  `1.0x` and the `deepseek-chat`/V4 name mismatch disconfirm an «always cheaper,
  equivalent model» interpretation.

`plan.md` is omitted because the completed activity is a compact public-source
comparison. The future benchmark has a plan trigger and must be separately
routed.

## Scope

- `RSC-01` Current No Fluff classifier/provider/model selection visible in code
  and the dated task-authority live-access/key-presence observations.
- `RSC-02` Published DeepSeek V4 Flash/Pro direct peak/off-peak token prices.
- `RSC-03` Published NeuralDeep PAYG V4 Flash/Pro RUB token prices and wallet
  billing basis.
- `RSC-04` USD→RUB normalization with the CBR 2026-08-27 rate and derived
  NeuralDeep/direct ratios.

## Non-scope

- `RNS-01` No claim that legacy `deepseek-chat` is identical to V4 Flash or V4
  Pro.
- `RNS-02` No quality, latency, JSON-validity, throughput or observed workload
  benchmark.
- `RNS-03` No provider/account reliability, support, tax, fee or full billing
  analysis beyond the supplied published token rates.
- `RNS-04` No production config/key/provider switch, deployment or secret
  inspection.

## Assumptions and known evidence

| ID | Statement | Type | Source / confidence |
| --- | --- | --- | --- |
| `ASM-01` | Per-1M input/output units are comparable after currency conversion for a nominal rate table | Assumption | Medium; model/service equivalence is explicitly excluded |
| `ASM-02` | CBR USD/RUB 84.2820 is the normalization rate for retrieved-on date | Evidence | [SRC-04](evidence.md#src-04); high |
| `EVD-01` | Current classifier explicitly uses DeepSeek provider and configured `deepseek-chat` model | Evidence | [SRC-05](evidence.md#src-05); high |
| `EVD-02` | Direct DeepSeek access worked and no OpenAI key was configured on 2026-08-27 | Task-authority observation | [SRC-06](evidence.md#src-06); medium/high, not independently re-inspected |

## Stopping condition

- `STOP-01` Stop after every supplied published rate and current integration
  fact is provenance-linked, ratios are reproducible, limitations are explicit,
  and the immediate switch question has a governed disposition. Condition met
  on 2026-08-27.

## Open questions

| Question | Blocks | Owner | Resolution evidence |
| --- | --- | --- | --- |
| Which published/current backend model corresponds to No Fluff `deepseek-chat`? | Like-for-like model comparison | LLM integration owner | Provider/model identity record |
| What representative No Fluff corpus and quality threshold are acceptable? | Provider benchmark | Product owner | Labeled corpus and acceptance contract |
| What latency, JSON-validity and cost thresholds are acceptable? | Provider benchmark | Product + engineering owners | Benchmark method/threshold owner |

## Boundary check

- [x] Question/hypotheses are separated from findings.
- [x] Known facts point to clickable source records.
- [x] No delivery scope, selected production solution, ADR or implementation
  sequence is created.
- [x] Privacy, security and access constraints are explicit.
