---
title: No Fluff Configuration Guide
doc_kind: ops
doc_function: canonical
purpose: Configuration schema, environment naming, framework exceptions and secret-handling ownership for No Fluff.
derived_from:
  - ../dna/governance.md
  - ../engineering/architecture.md
status: active
audience: humans_and_agents
canonical_for:
  - operational_configuration_contract
  - secret_handling_procedure
---

# Configuration Guide

## Configuration architecture

| Layer | Owner | Role |
| --- | --- | --- |
| Application schema | [`ApplicationConfig`](../../config/configs/application_config.rb) | Anyway Config keys, types/defaults and required-key checks |
| Non-secret overlays | [`config/no_fluff.yml`](../../config/no_fluff.yml) | Test/development/production defaults; current model default is `deepseek-chat` |
| LLM adapter setup | [`config/initializers/ruby_llm.rb`](../../config/initializers/ruby_llm.rb) | Supplies configured keys/model to RubyLLM outside tests/dummy build |
| Framework runtime | `config/database.yml`, `queue.yml`, `recurring.yml` | Database roles, worker concurrency and recurring jobs; limited direct `ENV` use |
| Local containers | [`docker-compose.yml`](../../docker-compose.yml), [`dip.yml`](../../dip.yml) | Development services and safe dummy defaults |
| Production deployment | `~/code/brandymint/infra` | Canonical production manifests, secret injection and environment ownership; not inspected here |

Application code uses `ApplicationConfig`; direct environment access in Rails
adapter/bootstrap files is an observed scoped exception, not a general pattern.

## Naming convention

- Application prefix: `NO_FLUFF_` (case-insensitive mapping handled by Anyway
  Config).
- Important application groups: Telegram bot, Telegram MTProto, LLM provider,
  Active Record encryption, host/protocol and product limits.
- Framework/process exceptions include Rails/database variables and current
  worker concurrency keys such as `CHANNELS_CONCURRENCY` and
  `CONTENT_CONCURRENCY`.

## Important contracts (names only)

| Setting / group | Purpose | Default / sensitivity | Owner |
| --- | --- | --- | --- |
| `NO_FLUFF_LLM_DEFAULT_MODEL` | Classifier model name | `deepseek-chat` in repository config | Application config + classifier architecture |
| DeepSeek/OpenAI API-key settings | Provider credentials accepted by RubyLLM config | Secret; no value in repository docs | Secret procedure / runtime environment |
| Telegram bot token/username | Bot API identity and access | Token is secret | Secret procedure / application config |
| Telegram API id/hash/proxy | MTProto access path | Credentials/access data; sensitive | Secret procedure / application config |
| Active Record encryption keys | Encrypt follower/session fields | Secret and required outside test | Secret procedure / application config |
| Database connection settings | PostgreSQL roles/connectivity | Environment-specific | Rails config / infrastructure |

The dated operational observation that direct DeepSeek access worked and no
OpenAI key was configured on 2026-08-27 belongs to
[research evidence R-001](../research/R-001/evidence.md), not to a permanent
secret inventory.

## Secrets

- Store developer credentials in `pass`, never in Markdown, tracked config or
  plaintext `.env`.
- If local environment variables are needed, a project `.envrc` may load them
  from named `pass` entries. Exact entry names are `Unknown`; do not invent or
  overwrite entries.
- Keep only non-secret machine-local settings in ignored `.env`/`.env.local`.
- Production secret injection is owned by the canonical infrastructure repo.
  This document names no secret value, token, private phone or session string.
- Before replacing any existing plaintext secret in a future task, verify its
  destination `pass` entry is readable and separately report any Git-history
  exposure.

## Change protocol

1. Update `ApplicationConfig` schema/default owner when application config
   changes.
2. Update non-secret overlays and tests.
3. Update this operational contract without secret values.
4. For production/infrastructure change, route to `~/code/brandymint/infra` and
   follow its instructions/approval gates.
