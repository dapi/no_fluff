---
title: Testing Policy
doc_kind: engineering
doc_function: canonical
purpose: "Описывает testing policy репозитория: обязательность test case design, требования к automated regression coverage и допустимые manual-only gaps."
derived_from:
  - ../dna/governance.md
  - ../flows/behavior-specification.md
  - ../flows/feature.md
  - ../flows/feature-requirements.md
  - validation-profiles.md
status: active
canonical_for:
  - repository_testing_policy
  - feature_test_case_inventory_rules
  - automated_test_requirements
  - sufficient_test_coverage_definition
  - manual_only_verification_exceptions
  - simplify_review_discipline
  - verification_context_separation
  - bdd_automation_policy
must_not_define:
  - feature_acceptance_criteria
  - feature_scope
audience: humans_and_agents
---

# Testing Policy

## No Fluff Test Stack

- **Framework:** Minitest through Rails (`ActiveSupport::TestCase`,
  `ActiveJob::TestCase` and integration/controller surfaces). RSpec is not used.
- **Data:** Rails fixtures are preferred. Shared helpers live in
  `test/support/`; DatabaseRewinder cleans database state; Mocha and the
  Telegram client stub isolate external calls.
- **Canonical full local suite:** `dip test` (or `make test`, which delegates to
  Dip). It prepares test databases and runs `rails test` in the dev container.
- **Targeted suite:** `dip rails test <test-path>` after the local environment is
  provisioned.
- **Lint/security:** `dip rubocop` and `dip brakeman`.
- **CI jobs:** `scan_ruby` (Brakeman), `lint` (RuboCop), and `test` (database
  preparation plus Rails tests) in [CI](../../.github/workflows/ci.yml).
- **External APIs:** Telegram and LLM calls are mocked/stubbed in automated
  tests. Live/manual verification requires an explicit scoped task and must not
  expose credentials, sessions or private data.

## Core Rules

- Выбранный [`validation profile`](validation-profiles.md) задаёт minimum validation/evidence floor независимо от delivery flow; project-specific policy может только усиливать его.
- Любое изменение поведения, которое можно проверить детерминированно, обязано получить automated regression coverage.
- Любой новый или измененный contract обязан получить contract-level automated verification.
- Любой bugfix обязан добавить regression test на воспроизводимый сценарий.
- Required automated tests считаются закрывающими риск только если они проходят локально и в CI.
- Manual-only verify допустим только как явное исключение и не заменяет automated coverage там, где automation реалистична.

## BDD Automation Policy

[`Behavior Specification Practice`](../flows/behavior-specification.md)
определяет Discovery и Formulation; этот policy определяет automation boundary.

- BDD не требует Gherkin, Cucumber, browser automation или E2E-only tests.
- Для каждого required `SC-*` / `NEG-*` выбирай самый низкий надёжный unit,
  component, contract, integration или E2E surface, который доказывает
  observable outcome.
- Один behavior example может проверяться несколькими техническими тестами;
  каждый test surface должен быть виден в `implementation-plan.md#test-strategy`.
- Имя, tag или metadata теста должны сохранять ссылку на `SC-*` / `NEG-*`, если
  project framework это допускает без brittle coupling.
- Test code не владеет requirement или expected behavior. При изменении
  expected verdict сначала обнови canonical `UC/domain/brief` owner, затем
  examples, `CHK-*`, plan и code.
- Gherkin, если выбран downstream-проектом, является executable projection
  canonical `SC-*` / `NEG-*`, а не параллельным source of truth.

## Ownership Split

- Canonical validation profile decision живёт только в owner-е, назначенном [`validation-profiles.md`](validation-profiles.md); testing policy и execution artifacts не выбирают profile повторно.
- Canonical test cases delivery-единицы задаются в `brief.md` через `SC-*`, feature-specific `NEG-*`, `CHK-*` и `EVID-*`.
- Design pack, если нужен, aggregate-владеет selected design, C4 applicability/model, `CTR-*`, `INV-*`, `FM-*` и локальными `RB-*`. Root `design.md` остаётся default owner, а явно делегированный constituent — непосредственным owner перечисленных IDs; ни один design artifact не подменяет canonical verify contract.
- `implementation-plan.md` владеет только стратегией исполнения: какие test surfaces будут добавлены или обновлены, какие gaps временно остаются manual-only и почему.

## Feature Flow Expectations

Canonical lifecycle gates живут в [../flows/feature.md](../flows/feature.md):

- к `Problem Ready` `brief.md` уже фиксирует validation profile decision и test case inventory;
- к `Solution Ready` весь required design pack готов по relation, ownership, publication/lifecycle и consistency rules из Feature Flow;
- к `Plan Ready` `implementation-plan.md` содержит `Test Strategy` с planned automated coverage и manual-only gaps;
- к `Done` required tests добавлены, локальные команды зелёные и CI не противоречит локальному verify.

## Что Считается Sufficient Coverage

For each applicable `REQ-*`, preserve the `brief.md` verification method and evidence contract. Quality requirements include an observable threshold and a repeatable measurement/check. The plan maps each changed implementation, test, and config path plus symbol/section back to a `REQ-*` or explicit supporting rationale; review checks that mapping in both directions.

- Покрыт основной changed behavior и ближайший regression path.
- Покрыты новые или измененные contracts, события, schema или integration boundaries.
- Покрыты критичные failure modes из `FM-*` в required `design.md`, bug history или acceptance risks.
- Покрыты feature-specific negative/edge scenarios, если они меняют verdict.
- Required `SC-*` / `NEG-*` прослеживаются через `CHK-*` к automated test либо
  явно approved manual-only gap и concrete `EVID-*`.
- Процент line coverage сам по себе недостаточен: нужен scenario- и contract-level coverage.

## Когда Manual-Only Допустим

- Сценарий зависит от live infra, внешних систем, hardware, недетерминированной среды или human оценки UI.
- Для каждого manual-only gap: причина, ручная процедура, owner follow-up.
- Для каждого manual-only gap соблюдены approval requirements выбранного validation profile.
- Если manual-only gap оставляет без regression protection критичный путь, feature не считается завершённой.

## Simplify Review

Отдельный проход верификации после функционального тестирования. Цель: убедиться, что реализация минимально сложна.

- Выполняется после прохождения tests, но до closure gate.
- Паттерны: premature abstractions, глубокая вложенность, дублирование логики, dead code, overengineering.
- Три похожие строки лучше premature abstraction. Абстракция оправдана только когда она реально уменьшает риск или повтор.

## Verification Context Separation

Artifact review и implementation review имеют разные объекты проверки и evidence:

1. **Artifact review** — до соответствующего lifecycle gate проверяет governed requirements/design/plan artifacts, их grounding, ownership, completeness и traceability.
2. **Implementation review** — после execution проверяет delivered code и repository diff против принятых canonical artifacts.
3. **Функциональная верификация** — tests проходят, acceptance scenarios покрыты.
4. **Simplify review** — код минимально сложен.
5. **Acceptance test** — end-to-end по `SC-*`.

Artifact review не является доказательством качества реализации, а implementation review не исправляет задним числом непройденный artifact gate. Для compact feature packages проходы допустимы в одной сессии, если их объекты, verdicts и evidence зафиксированы раздельно; обязательный review или simplify review не пропускается.

## Project-specific conventions

- Mirror source layout under `test/models`, `test/services`, `test/jobs`,
  `test/controllers`, `test/integration` or the nearest existing category.
- Prefer fixtures over factories; reuse `test/support` helpers and existing
  Telegram/LLM mocks instead of contacting remote services.
- Behavior changes follow RED-GREEN-REFACTOR. A bug fix adds a deterministic
  regression test when the scenario is reproducible.
- For non-interpolated localized copy, assert the full `I18n.t` value rather
  than a hard-coded substring.
- Before handoff for Ruby behavior changes: affected tests, full `dip test`
  when proportionate, RuboCop and Brakeman/required CI surfaces.
- For documentation-only changes: validate frontmatter, links/navigation,
  applicable upstream Memory Bank validators, `bash -n init.sh`, and existing
  project documentation checks. A Rails runtime suite is not evidence for
  Markdown correctness and is not required solely because documentation
  changed.

## Manual-only exceptions

- Live Telegram/MTProto/LLM behavior, external provider quality and production
  deployment may require manual evidence, but only under a separately scoped
  authorized task.
- Record procedure, environment boundary, owner and follow-up for every such
  gap. Never turn the production pilot into a reusable test account record.

## Adoption status

- [x] Real local commands documented.
- [x] Required CI suites listed.
- [x] Deterministic data and mock pattern documented.
- [x] Manual-only boundary documented.
- [x] No conflict introduced with [Feature Flow](../flows/feature.md).
