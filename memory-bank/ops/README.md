---
title: No Fluff Operations Index
doc_kind: ops
doc_function: index
purpose: Навигация по локальной разработке, конфигурации, environment, release ownership и operational gaps No Fluff.
derived_from:
  - ../dna/governance.md
  - ../flows/priming/context-priming.md
status: active
audience: humans_and_agents
---

# No Fluff Operations

## Priming inputs

Перед future ops/release work прочитай
[`ops.yaml`](../flows/priming/ops.yaml), выполни `operations_release`, затем
прочитай `~/code/brandymint/infra/AGENTS.md` до обращения к canonical
infrastructure repository.

## Аннотированный индекс

- [Development Environment](development.md) — `./init.sh`, Dip, Docker,
  PostgreSQL, local URL and daily commands.
- [Configuration](config.md) — `ApplicationConfig`, env naming, framework
  exceptions and secret ownership without values.
- [Stages](stages.md) — known/unknown environments, access boundary,
  observability and prohibited assumptions.
- [Release And Deployment](release.md) — split ownership between application
  build sources and canonical infrastructure; no deployment authorization.
- [Runbooks](runbooks/README.md) — current runbook gap and links to evidence,
  without invented commands.

## Scope boundary

This Memory Bank adaptation did not inspect or change production,
`~/code/brandymint/infra`, secret stores, Telegram sessions, runtime logs or
private account data, and did not deploy.
