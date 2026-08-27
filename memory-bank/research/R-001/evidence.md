---
title: "R-001: Evidence Log"
doc_kind: research
doc_function: canonical
purpose: Retrieved-on sources, published rates, current integration observations and reproducible calculations for R-001.
derived_from:
  - brief.md
  - ../../flows/research.md
status: active
audience: humans_and_agents
---

# R-001: Evidence Log

No credentials, wallet contents, private data or restricted provider material
were collected. External rate facts below were supplied as retrieved on
2026-08-27 and are recorded with their original public URLs.

## Sources

### SRC-01

- Source: [Official DeepSeek API pricing](https://api-docs.deepseek.com/quick_start/pricing)
- Date/freshness: retrieved 2026-08-27.
- Context: direct provider V4 Flash/Pro published input/output prices per 1M
  tokens, with peak and off-peak rates.
- Quality/access note: primary publisher source; prices are volatile and do not
  establish equivalence with No Fluff `deepseek-chat`.

### SRC-02

- Source: [NeuralDeep pricing](https://neuraldeep.ru/pricing)
- Date/freshness: retrieved 2026-08-27.
- Context: public PAYG DeepSeek V4 Flash/Pro RUB prices per 1M tokens.
- Quality/access note: primary vendor pricing page; nominal published rates.

### SRC-03

- Source: [NeuralDeep public wallet rates](https://neuraldeep.ru/api/public/wallet-prices)
- Date/freshness: retrieved 2026-08-27.
- Context: public machine-readable wallet price record; wallet is token-based in
  RUB.
- Quality/access note: primary vendor public endpoint; wallet mechanics are not
  a quality or model-equivalence guarantee.

### SRC-04

- Source: [CBR daily exchange-rate XML for 2026-08-27](https://www.cbr.ru/scripts/XML_daily.asp?date_req=27/08/2026)
- Date/freshness: rate date and retrieval date 2026-08-27.
- Context: official USD/RUB rate used only for normalization.
- Quality/access note: primary regulator source; recorded rate is `84.2820` RUB
  per USD.

### SRC-05

- Source: repository baseline
  [`Content::PostClassifier`](../../../app/services/content/post_classifier.rb),
  [`config/no_fluff.yml`](../../../config/no_fluff.yml), and
  [classifier test](../../../test/services/content/post_classifier_test.rb) at
  `812b087b19213036a002fb605d4554762b43981e`.
- Date/freshness: inspected 2026-08-27; relevant code/config last changed
  2026-08-26.
- Context: current provider/model integration contract.
- Quality/access note: primary repository evidence; it does not identify the
  external backend model behind the legacy model name.

### SRC-06

- Source: [research intake/trigger](brief.md#intake), preserving the explicit
  task-authority operational observation supplied 2026-08-27.
- Date/freshness: observed/reported 2026-08-27.
- Context: current direct DeepSeek access worked; no OpenAI key was configured.
- Quality/access note: first-party task-authority statement, not independently
  re-inspected because production/secrets were out of scope. No key value or
  secret-store detail was requested or recorded.

## Observations

### OBS-01 — current integration

No Fluff code calls RubyLLM with provider `deepseek` and configured model
`deepseek-chat`; the 2026-08-27 operational observation says direct access
worked and no OpenAI key was configured.

- Supports: [SRC-05](#src-05), [SRC-06](#src-06).
- Applies to: `RQ-01`.
- Boundary: does not prove which published DeepSeek V4 product, if any, is
  identical to `deepseek-chat`, and does not expose any credential.

### OBS-02 — published direct DeepSeek rates

Published direct rates per 1M tokens:

| Model | Period | Input USD | Output USD |
| --- | --- | ---: | ---: |
| V4 Flash | off-peak | 0.22 | 0.66 |
| V4 Flash | peak | 0.44 | 1.32 |
| V4 Pro | off-peak | 0.66 | 1.98 |
| V4 Pro | peak | 1.32 | 3.96 |

- Supports: [SRC-01](#src-01).
- Boundary: comparison is only against the currently published V4 models, not
  an assertion about legacy `deepseek-chat` identity.

### OBS-03 — published NeuralDeep rates

Published NeuralDeep PAYG rates per 1M tokens:

| Model | Input RUB | Output RUB |
| --- | ---: | ---: |
| DeepSeek V4 Flash | 14.7 | 29.4 |
| DeepSeek V4 Pro | 71.4 | 142.8 |

The public wallet is token-based in RUB.

- Supports: [SRC-02](#src-02), [SRC-03](#src-03).
- Boundary: these rates do not establish model quality, latency, JSON validity
  or actual No Fluff workload cost.

### OBS-04 — normalization rate

The CBR rate used for normalization is `84.2820 RUB/USD` for 2026-08-27.

- Supports: [SRC-04](#src-04).
- Boundary: a dated FX rate, not a stable future conversion.

### OBS-05 — derived nominal comparison

Formula:

```text
direct RUB per 1M = published direct USD per 1M × 84.2820
ratio = NeuralDeep RUB per 1M ÷ direct RUB per 1M
```

`ratio < 1.0` means NeuralDeep's published nominal rate is lower for that cell;
`ratio > 1.0` means higher.

| Model | Tokens | Direct off-peak RUB | Direct peak RUB | NeuralDeep RUB | Ratio vs off-peak | Ratio vs peak |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| V4 Flash | input | 18.5420 | 37.0841 | 14.7 | 0.79x | 0.40x |
| V4 Flash | output | 55.6261 | 111.2522 | 29.4 | 0.53x | 0.26x |
| V4 Pro | input | 55.6261 | 111.2522 | 71.4 | 1.28x | 0.64x |
| V4 Pro | output | 166.8784 | 333.7567 | 142.8 | 0.86x | 0.43x |

- Supports: [OBS-02](#obs-02--published-direct-deepseek-rates),
  [OBS-03](#obs-03--published-neuraldeep-rates), and
  [OBS-04](#obs-04--normalization-rate).
- Boundary: this table disproves «NeuralDeep is always cheaper» for the compared
  cells: V4 Pro off-peak input is `1.28x` direct. It also does not compare
  model/service equivalence or observed workload.

### OBS-06 — candidate named by the decision trigger

The candidate for a future benchmark is NeuralDeep
`deepseek-v4-flash`. V4 Pro is not selected as the first candidate because no
current requirement/evidence shows its higher-priced tier is needed.

- Supports: task trigger [SRC-06](#src-06) plus rate comparison
  [OBS-05](#obs-05--derived-nominal-comparison).
- Boundary: candidate status is not production approval and not evidence of
  acceptable quality.

## Collection log

| Date | Activity | Result | Deviation / reason |
| --- | --- | --- | --- |
| 2026-08-27 | Recorded supplied primary-source prices and CBR rate | All requested source facts linked | No independent refetch required; facts were supplied with retrieved contents/date |
| 2026-08-27 | Inspected current code/config/test | Direct `deepseek` + `deepseek-chat` contract confirmed | Production/secrets intentionally not inspected |
| 2026-08-27 | Recomputed RUB values and ratios | Ratios reproduce the supplied comparison | Rounded direct RUB to four decimals, ratios to two |

## Evidence quality check

- [x] Each material observation traces to one or more `SRC-*`.
- [x] Every public source has a clickable original URL; local evidence has a
  stable repository link.
- [x] Source claims, observations and interpretation boundaries are separated.
- [x] Freshness, model mismatch, access boundary and price volatility are
  explicit.
