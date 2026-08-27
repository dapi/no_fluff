---
title: Telegram Bot UI Guide
doc_kind: engineering
doc_function: reference
purpose: Curated source paths and representative patterns for No Fluff Telegram messages, commands, keyboards and callbacks.
derived_from:
  - README.md
  - ../frontend.md
status: active
audience: humans_and_agents
must_not_define:
  - product_requirements
  - domain_rules
  - frontend_architecture_contract
  - feature_interface_requirements
  - implementation_sequence
---

# Telegram Bot UI Guide

## Surface and entry points

- Commands: [`StartCommand`](../../../app/services/telegram/commands/start_command.rb),
  [`ChannelCommand`](../../../app/services/telegram/commands/channel_command.rb)
  and command scanner/manager.
- Callback handling:
  [`SettingsHandler`](../../../app/services/telegram/callback_handlers/settings_handler.rb)
  and Telegram controllers.
- Keyboard helpers: [`app/controllers/concerns/telegram/keyboard_helpers.rb`](../../../app/controllers/concerns/telegram/keyboard_helpers.rb).
- Copy: [`config/locales/ru.yml`](../../../config/locales/ru.yml) and
  [`config/locales/en.yml`](../../../config/locales/en.yml).
- Delivery composition: [`Content::DeliverPostsJob`](../../../app/jobs/content/deliver_posts_job.rb).

## Existing patterns

| Pattern | Existing use | Source | Review entry point |
| --- | --- | --- | --- |
| Welcome + inline actions | `/start`, onboarding and settings buttons | [`StartCommand`](../../../app/services/telegram/commands/start_command.rb) | Start-command/controller tests |
| Channel input and outcome | `/add`/remove with username or `t.me` URL | [`ChannelCommand`](../../../app/services/telegram/commands/channel_command.rb), [`ChannelService`](../../../app/services/telegram/channel_service.rb) | Channel command/service tests |
| Settings keyboard | Frequency, format and strictness callbacks | [`SettingsAgent`](../../../app/services/telegram/settings_agent.rb) | Settings handler/agent tests |
| Delivered post | Source text plus canonical `t.me` link | [`DeliverPostsJob`](../../../app/jobs/content/deliver_posts_job.rb) | [`deliver_posts_job_test.rb`](../../../test/jobs/content/deliver_posts_job_test.rb) |

## Rules for changes

- Add/change user-facing copy through I18n; preserve callback payload
  compatibility or update handlers/tests together.
- Preserve source attribution for delivered posts.
- Verify error/empty/success states at the service/command level. Telegram owns
  native loading/disabled/visual states not represented in repository code.
- Do not use the Telegram-like web demo design documents as component API or
  proof of a customer web surface.

## Maintenance

Before UI work, confirm the linked paths against current checkout and inspect
the nearest tests. Update this map when reusable entry points materially change.
