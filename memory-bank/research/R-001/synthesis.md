---
title: "R-001: Research Synthesis"
doc_kind: research
doc_function: canonical
purpose: Findings, confidence, limitations and direct answer synthesized from pricing evidence R-001.
derived_from:
  - brief.md
  - evidence.md
status: active
audience: humans_and_agents
---

# R-001: Research Synthesis

## Findings

| ID | Finding | Evidence | Confidence | Implication |
| --- | --- | --- | --- | --- |
| `FND-01` | Current No Fluff directly selects provider `deepseek` and model name `deepseek-chat`; live access was reported working on 2026-08-27, with no OpenAI key configured | [OBS-01](evidence.md#obs-01--current-integration) | High for code, medium/high for dated operational observation | Defines current baseline; does not map it to V4 |
| `FND-02` | NeuralDeep V4 Flash nominal published rates are lower than converted direct V4 Flash rates in all four peak/off-peak input/output cells: 0.79x/0.53x off-peak and 0.40x/0.26x peak | [OBS-05](evidence.md#obs-05--derived-nominal-comparison) | High for arithmetic on dated rates | Supports Flash as a cost candidate, not an immediate switch |
| `FND-03` | NeuralDeep V4 Pro is not uniformly cheaper: off-peak input is 1.28x direct, while off-peak output is 0.86x and peak input/output are 0.64x/0.43x | [OBS-05](evidence.md#obs-05--derived-nominal-comparison) | High | Directly rejects «always cheaper» and weakens Pro-first rationale |
| `FND-04` | Published token rates alone cannot establish safe production substitution because current `deepseek-chat` is not proven identical to V4 and no representative quality/latency/JSON-validity/observed-cost benchmark exists | [OBS-01](evidence.md#obs-01--current-integration), [OBS-02](evidence.md#obs-02--published-direct-deepseek-rates), [OBS-03](evidence.md#obs-03--published-neuraldeep-rates) | High | Invalidates `HYP-01`; immediate switch is not justified |
| `FND-05` | NeuralDeep `deepseek-v4-flash` is the proportionate first benchmark candidate; Pro is unnecessary unless Flash fails an explicit quality requirement | [OBS-06](evidence.md#obs-06--candidate-named-by-the-decision-trigger) | Medium | Defines next research candidate, not production architecture |

## Limitations and disconfirming evidence

| ID | Limitation / signal | Effect | Mitigation / next question |
| --- | --- | --- | --- |
| `LIM-01` | Current `deepseek-chat` and published V4 products have a model-name mismatch | Blocks like-for-like quality/cost inference | Resolve model identity or benchmark outputs directly |
| `LIM-02` | Provider prices and FX rate are dated/volatile | Ratios may change after retrieval date | Re-fetch all rates and FX at benchmark/decision time |
| `LIM-03` | Comparison uses nominal token rates, not observed No Fluff billing | Does not establish total workload cost | Measure provider-reported usage/cost on the same corpus |
| `LIM-04` | No representative quality, latency or JSON-validity measurement | Cheap rate could regress core filter behavior | Define labeled corpus and thresholds before benchmark |
| `LIM-05` | Live access/OpenAI-key observation was supplied by task authority and not independently inspected | Dated operational fact may become stale | Reconfirm through authorized config procedure only when needed |
| `LIM-06` | NeuralDeep Pro off-peak input is 1.28x direct | Explicitly contradicts «always cheaper» | Preserve per-cell wording; never generalize |

## Answer to decision question

No. The dated prices make NeuralDeep V4 Flash a credible cost candidate, but
they do not justify an immediate production switch. Keep production on the
current direct DeepSeek `deepseek-chat` path and run a representative No Fluff
benchmark of quality, latency, JSON-validity and observed cost first. Start with
NeuralDeep `deepseek-v4-flash`; V4 Pro is not needed unless an explicit quality
result requires it. Do not claim NeuralDeep is always cheaper.

## Review check

- [x] Findings trace to linked observations and sources.
- [x] Confidence reflects evidence and model/access limitations.
- [x] Disconfirming Pro price and remaining uncertainty are visible.
