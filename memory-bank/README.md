---
title: No Fluff Memory Bank Index
doc_kind: project
doc_function: index
purpose: Корневая навигация по evidence-backed Memory Bank проекта No Fluff.
derived_from:
  - dna/principles.md
  - dna/governance.md
status: active
audience: humans_and_agents
---

# No Fluff Memory Bank

Memory Bank дополняет, но не заменяет existing repository instructions,
`docs/`, runtime code и external infrastructure owners. Код владеет
реализацией; canonical owners ниже владеют intent, domain language,
engineering/ops contracts and governed decisions.

## Brownfield baseline

- [Governed PRD-001](prd/PRD-001-no-fluff-brownfield-baseline.md) — current
  product scope, evidence/confidence, conflicts, assumptions and open gaps.
- [Historical intake](../brownfield-intake-prd.md) — pre-template discovery
  record retained only as provenance; it is not an active owner.
- Repository evidence baseline: No Fluff `main` commit
  `812b087b19213036a002fb605d4554762b43981e`, inspected 2026-08-27.

## Canonical owner navigation

- [Product](product/README.md) — problem, users, promise, evidence-bounded
  metrics/marketing and current roadmap guard.
- [Domain](domain/README.md) — current public-channel concepts, rules, states,
  event boundary and provisional context map.
- [Engineering](engineering/README.md) — Rails/Telegram/MTProto/LLM architecture,
  Telegram UI, tests, validation, autonomy, coding and Git conventions.
- [Operations](ops/README.md) — Dip development, config/secrets procedure,
  environments, external infrastructure ownership, release and runbook gaps.

## Governed work and evidence

- [PRDs](prd/README.md) — product-level initiative/baseline wrappers.
- [Research](research/README.md) — evidence-backed research packages, including
  [R-001 DeepSeek vs NeuralDeep pricing](research/R-001/README.md).
- [Use Cases](use-cases/README.md) — stable project scenarios; currently no
  instantiated `UC-*`.
- [ADRs](adr/README.md) — architecture decisions; no ADR was created for a
  decision that leaves architecture unchanged.
- [Epics](epics/README.md) and [Features](features/README.md) — delivery package
  registries; this documentation-only adaptation instantiated none.

## Governance and flows

- [DNA](dna/README.md) — SSoT, dependency, frontmatter, lifecycle and
  cross-reference contracts.
- [Flows](flows/README.md) — routing, research, use case, delivery and incident
  lifecycles plus templates.
- [Prompts](prompts/README.md) — reusable human-facing prompt catalog from the
  upstream payload.

## Existing source-of-truth boundaries

- Protected repository instruction files remain authoritative and are not
  managed by Memory Bank. No managed agent block is installed.
- Existing product/spec/implementation/history remains in [`docs/`](../docs/)
  and is linked rather than indiscriminately copied.
- Deployment configuration for BrandyMint/Pismenny projects is canonically
  owned by `~/code/brandymint/infra`; this adaptation did not inspect or change
  it.
- Secrets belong in `pass`/approved runtime injection, never in Memory Bank.

## Template provenance

Installed on 2026-08-27 from the tracked downstream payload of
[`dapi/memory-bank` commit `ac2423809f1e43b4892dd0feaebd722b90926982`](https://github.com/dapi/memory-bank/commit/ac2423809f1e43b4892dd0feaebd722b90926982):
`template/memory-bank/` → `memory-bank/` and `template/init.sh` → `init.sh`.
Generic governance/flows/templates remain upstream-shaped; project owner layers
were adapted from No Fluff evidence, and irrelevant generic UI surface drafts
were removed.

## CLI adoption boundary

`memory-bank-cli lint` applies to this tree. A normal CLI ownership-lock repair
would also install the broader upstream root payload and a managed agent block.
The current task explicitly forbids that protected-file mutation and limits the
copied payload to `memory-bank/` plus `init.sh`, so `memory-bank/.lock` is
intentionally absent. Future ownership-aware `pull`/`update` needs an explicit
policy decision that preserves these boundaries; do not run `doctor --fix` or
`init` blindly.
