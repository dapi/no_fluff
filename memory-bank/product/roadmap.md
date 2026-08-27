---
title: No Fluff Product Roadmap
doc_kind: product
doc_function: roadmap
purpose: Evidence-bounded product themes and open bets for No Fluff without duplicating the existing feature backlog.
derived_from:
  - ../dna/governance.md
  - context.md
  - vision.md
  - metrics.md
  - ../research/R-001/decision.md
status: active
audience: humans_and_agents
canonical_for:
  - product_roadmap
  - product_themes
---

# Product Roadmap

## Horizons

| Horizon | Theme | Intended outcome | Candidate owner | Dependency | Status |
| --- | --- | --- | --- | --- | --- |
| `now` | Preserve the production-proven public-channel flow | Continue import → classify → deliver without duplicate delivery | Existing Spec 055/code | Current tests and operational checks | active |
| `next` | Benchmark provider candidate before any production switch | Compare quality, latency, JSON validity and observed cost on representative No Fluff posts | Follow-up research/benchmark package; no feature yet | Corpus, thresholds and owner confirmation from [R-001 decision](../research/R-001/decision.md) | planned |
| `later` | Broader product roadmap | `Unknown` until existing themes are revalidated against current evidence | Existing [`docs/ROADMAP.md`](../../docs/ROADMAP.md) remains legacy backlog owner | Product owner and measured signals | idea |

## Decision guard

Production remains on the current direct DeepSeek path. NeuralDeep
`deepseek-v4-flash` is only the candidate for the next benchmark; it is not an
approved production provider. DeepSeek V4 Pro is not a current preferred
candidate because no evidence shows the expected quality needs it.

This guard is the promoted durable action from [research R-001](../research/R-001/README.md).
It does not authorize benchmark execution against production, a provider
switch, deployment or secret/config change.

## Open bets

- `BET-01` NeuralDeep Flash may reduce observed workload cost without material
  quality, latency or JSON-validity regression. Status: unvalidated.
- `OQ-01` Representative corpus, acceptance thresholds and accountable owners
  remain `TBD`.
- `OQ-02` The relation between current `deepseek-chat` and published DeepSeek V4
  models remains unresolved.

## Ownership boundary

The existing feature-level roadmap and specification lifecycle remain in
[`docs/ROADMAP.md`](../../docs/ROADMAP.md), the
[documentation index](../../docs/README.md) and individual specification files.
This governed roadmap does not copy their feature backlog or mark their items
complete.
