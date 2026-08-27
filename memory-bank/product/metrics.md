---
title: No Fluff Product Metrics
doc_kind: product
doc_function: canonical
purpose: Каноничное место для product measurement gaps, candidate success signals и guardrails No Fluff.
derived_from:
  - ../dna/governance.md
  - context.md
status: active
audience: humans_and_agents
canonical_for:
  - product_metrics
  - success_measurement
---

# Product Metrics

## Current status

Canonical measured North Star, baselines, targets, dashboard и named metric
owner в репозитории не найдены. Existing numeric targets в
[`docs/Product/user-flow.md`](../../docs/Product/user-flow.md) и
[`.protocols/`](../../.protocols/) являются draft/hypothesis material, а не
measured baseline.

## Candidate North Star

| Metric ID | Metric | Why it matters | Baseline | Target | Owner / cadence |
| --- | --- | --- | --- | --- | --- |
| `NSM-01` | Validated useful delivered posts per active user | Отражает accepted content, а не raw model output | `Unknown` | `TBD` | Product owner confirmation required |

`Time saved per user` остаётся product hypothesis: current instrumentation and
measurement definition не найдены.

## Product metrics needing ownership

| Metric ID | Metric | Baseline | Target | Candidate measurement | Status |
| --- | --- | --- | --- | --- | --- |
| `MET-01` | Delivered-post usefulness rate | `Unknown` | `TBD` | Join delivery ledger with explicit user feedback | Instrumentation/owner unconfirmed |
| `MET-02` | Valuable-post miss rate | `Unknown` | `TBD` | Representative labeled corpus or review sample | No canonical method |
| `MET-03` | Active subscribed users receiving content | `Unknown` | `TBD` | Canonical analytics query/dashboard | Data owner unconfirmed |
| `MET-04` | User-perceived time saved | `Unknown` | `TBD` | Research/measurement design required | Hypothesis only |

## Provider-evaluation guardrails

| Guardrail ID | Signal | Why it must not regress | Threshold | Current owner |
| --- | --- | --- | --- | --- |
| `GR-01` | Quality on representative No Fluff posts | Cheaper filtering is harmful if useful content is lost or fluff passes | `TBD` | Product + engineering |
| `GR-02` | End-to-end classification latency | Affects import-to-delivery delay | `TBD` | Engineering |
| `GR-03` | JSON-valid response rate | Classifier rejects invalid schema | `TBD` | Engineering |
| `GR-04` | Observed cost per representative corpus | Published rates alone may not equal workload cost | `TBD` | Product + engineering |

The decision to define and measure these guardrails is linked from
[R-001](../research/R-001/decision.md); no benchmark result is asserted here.

## Instrumentation constraints

- `ICON-01` No canonical product analytics dashboard or query owner was found.
- `ICON-02` Service follower accounts must not count as organic users.
- `ICON-03` Provider prices and exchange rates require retrieved-on dates.
- `ICON-04` Model-name mismatch must be recorded alongside provider cost data.

## Metric change policy

- Define owner, exact calculation, source, baseline and target before promoting
  a draft metric to an approved product target.
- Feature/test metrics remain local until accepted here as shared product
  metrics.
