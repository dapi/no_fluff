---
title: No Fluff Development Environment
doc_kind: ops
doc_function: canonical
purpose: Canonical local setup, services, URL and daily commands for No Fluff.
derived_from:
  - ../dna/governance.md
  - config.md
status: active
audience: humans_and_agents
canonical_for:
  - local_development_workflow
---

# Development Environment

## Prerequisites

- macOS/Linux shell environment with `mise`, Docker daemon and Dip available to
  the mise-managed Ruby.
- Tool versions from [`mise.toml`](../../mise.toml): Ruby 3.4.10, Node 20.11.1,
  Yarn 1.22.19.
- No production credentials are required for documentation validation. Do not
  copy `.env` or secrets from another checkout.

## Setup

```bash
./init.sh
```

The script installs/trusts mise tool versions, verifies Docker/Dip and runs the
canonical `dip provision`: build dev image, start PostgreSQL 17, install Ruby
and Yarn dependencies, and prepare databases.

## Daily commands

| Task | Command |
| --- | --- |
| Provision/update dependencies and DB | `dip provision` |
| Full Rails tests | `dip test` |
| Targeted Rails command/test | `dip rails <args>` |
| Rails server | `dip rails s` |
| Rails console | `dip console` |
| Workers + Telegram poller | `dip jobs` |
| PostgreSQL console | `dip psql` |
| RuboCop | `dip rubocop` |
| Brakeman | `dip brakeman` |
| Stop local services | `dip down` |

`make provision`, `make test`, `make up` and `make down` are wrappers around the
same mise/Dip path.

## Local URL and UI verification

- Docker maps the Rails app to `http://localhost:3014`; `/up` is the health
  route.
- The real customer surface is Telegram, not a browser UI. Browser automation
  is N/A for normal bot changes unless a future task introduces a proven web
  surface.
- Starting the bot/jobs may contact external services when real credentials are
  loaded. Do not do so during documentation-only checks.

## Database and services

- PostgreSQL 17 is the required local service; primary/cache/queue/cable Rails
  database roles are configured.
- `dip test` prepares test databases before running Minitest.
- Container volumes retain database, bundle, node modules and Rails cache.
- Use existing migrations and `./bin/rails` generator rules for schema changes;
  this adaptation creates none.
