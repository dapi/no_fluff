---
title: No Fluff Stages And Non-Local Environments
doc_kind: ops
doc_function: canonical
purpose: Known environment boundaries, access ownership and operational gaps without endpoints or credentials.
derived_from:
  - ../dna/governance.md
  - config.md
status: active
audience: humans_and_agents
canonical_for:
  - environment_inventory
  - non_local_access_boundary
---

# Stages And Non-Local Environments

## Environment inventory

| Environment | Purpose | Canonical access owner | Status / evidence |
| --- | --- | --- | --- |
| `development` | Local Docker/Dip work | This repository | Documented in [`development.md`](development.md) |
| `test` | Automated Rails tests | This repository / CI | `config/environments/test.rb` and CI |
| `production` | Real users/live traffic | `~/code/brandymint/infra` | Production-proven slice dated 2026-08-26; not re-inspected |
| `staging` / `sandbox` | `Unknown` | Needs operations owner | Do not infer existence from generic tooling or Bugsnag stage names |

## Access and authority

- This document grants no production, Kubernetes, infrastructure, secret or
  account access.
- Before any future non-local operation, read
  `~/code/brandymint/infra/AGENTS.md`, select the applicable environment and
  obtain the required approval for mutating/live actions.
- Do not record internal endpoints, namespaces, credentials, private phone data
  or smoke-account identity here.

## Health, version and observability

- Rails exposes `/up` as an application boot health check.
- Application/jobs use logs, Bugsnag and existing error-notification services.
- Repository-local `bin/verify-production` and Makefile verification targets
  are evidence of an operational check, but canonical invocation/targets belong
  to infrastructure instructions.
- Canonical dashboard links, SLOs, alert thresholds, escalation owner and
  production version-check procedure are `Unknown` in this repository.

## Production evidence boundary

The [2026-08-26 vertical slice](../../docs/Architecture/live-mtproto-vertical-slice.md)
records one public-channel production verification. It does not establish
private-channel behavior, follower-pool scale, long-term rate limits or a
general reusable test account.
