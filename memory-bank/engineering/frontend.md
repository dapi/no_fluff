---
title: No Fluff Frontend Engineering
doc_kind: engineering
doc_function: canonical
purpose: Engineering contract for the actual Telegram Bot interaction surface and localization boundary.
derived_from:
  - ../dna/governance.md
  - ../product/context.md
status: active
audience: humans_and_agents
canonical_for:
  - frontend_surfaces
  - telegram_bot_ui_contract
  - localization_contract
---

# Frontend Engineering

## UI surfaces

| Surface | Status | Entry points | Boundary |
| --- | --- | --- | --- |
| Telegram Bot messages and inline keyboards | Current product UI | `app/controllers/telegram/`, `app/services/telegram/commands/`, callback handlers | Telegram clients render the visual UI; repository owns text, callback payloads and message composition |
| Rails `/up` health route | Operational endpoint | `config/routes.rb` | Not customer UI |
| Solid Queue dashboard | Operational/internal mount | `config/routes.rb` | No customer product contract asserted |
| Customer-facing web/native mobile | N/A for current evidence | None confirmed | Do not infer from assets/layouts or demo design docs |

## Interaction patterns

- Commands and callbacks route to service/command objects; inline keyboards use
  helpers from `Telegram::KeyboardHelpers`.
- Channel input accepts `@username`, bare username and `t.me` URL forms under
  the current validation rules.
- A delivered post is a Telegram message containing the source text and source
  link. Formatting change must preserve attribution and Bot API limits.
- Settings expose delivery frequency, content format and filter strictness.
  Their persistence is current; full effect on the production delivery path is
  not assumed.

## Localization

- Bot user-facing text belongs in
  [`config/locales/ru.yml`](../../config/locales/ru.yml) and
  [`config/locales/en.yml`](../../config/locales/en.yml), accessed with full
  `I18n.t` keys.
- Do not hard-code new bot copy in Ruby. Existing hard-coded compatibility text
  does not create a new convention.
- Tests should assert the full `I18n.t` value when interpolation is absent,
  following the authoritative repository instruction.
- Russian is the Rails default locale; English and Russian locale files exist.

## Visual/design boundary

Telegram clients own fonts, message bubbles and native layout. Existing
[Telegram UI demo specification](../../docs/Design/telegram-ui-design-specification.md)
describes a demonstration interface and is not canonical runtime UI guidance.
Current source discovery is indexed in [UI Design Guide](ui-design-guide/README.md).

## Change checks

- Verify callback payload, I18n key, representative command/callback test and
  Telegram message composition for any changed interaction.
- Browser screenshot verification is N/A unless a future task introduces a
  real web surface and updates this owner first.
