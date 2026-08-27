---
title: No Fluff Coding Style
doc_kind: engineering
doc_function: convention
purpose: Project-specific Rails, Ruby, I18n, configuration, migration and error-handling conventions.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Coding Style

## Authority and scope

[`CLAUDE.md`](../../CLAUDE.md), current code and repository tooling remain
authoritative. This document is a navigation/summary owner and does not rewrite
or replace protected instructions.

## Ruby and Rails

- Follow Rails naming/module layout and the local style of the touched file.
- Generate new models/tables through `./bin/rails g model`; use `jsonb`, not
  `json`, for JSON database fields.
- Rails commands use `./bin/rails` in the native environment or the documented
  Dip wrapper in local Docker development.
- Use service objects/jobs for existing boundaries; do not introduce a new
  abstraction without evidence that it reduces risk or duplication.
- Migrations and generated code are reviewed for indexes already supplied by
  `references` and for rollback/data implications.

## User-facing text and localization

- New Telegram bot text belongs in `config/locales/` and is retrieved through
  `I18n.t` with a full key.
- Non-interpolated text assertions use the full translated value rather than a
  hard-coded substring.

## Configuration and errors

- Application code reads settings through `ApplicationConfig`, not direct
  `ENV`. Rails framework/bootstrap configuration is an observed exception and
  must remain scoped to config files.
- A rescued error is reported through Bugsnag/existing error services with
  useful sanitized context where possible.
- Never log secrets, Telegram session material, private phone data or encrypted
  values.

## Tooling contract

- Formatter/linter: RuboCop configured by [`.rubocop.yml`](../../.rubocop.yml).
- Apply `rubocop -A` only to changed Ruby files before staging, then run the
  relevant lint/test surfaces.
- Security scan: Brakeman.
- JavaScript/CSS tooling is limited to the existing Yarn/PostCSS/Sass setup; no
  separate customer frontend architecture is established.

## Change discipline

- Do not rewrite unrelated code/docs to normalize style.
- Tests-first is required for runtime behavior changes; this Memory Bank
  adaptation changes no runtime behavior.
- Existing specification statuses and checklists are updated only when the task
  actually implements their scope.
