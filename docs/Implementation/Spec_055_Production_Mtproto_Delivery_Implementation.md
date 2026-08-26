# План реализации спецификации 055: Production MTProto Delivery

## Ссылка

[Спецификация 055](../Specs/055_Production_Mtproto_Delivery_Specification.md)

## Статус: implemented

### Этап 1: Durable delivery ledger — RED-GREEN-REFACTOR

- [x] 1.1 RED: написать model/job тесты для idempotent delivery, Bot API failure и DB uniqueness.
- [x] 1.2 GREEN: сгенерировать `Delivery` через `./bin/rails g model`, добавить jsonb metadata и unique index.
- [x] 1.3 GREEN: создавать ledger только после успешного send и пропускать существующий.
- [x] 1.4 REFACTOR: применить RuboCop к изменённым Ruby-файлам.

### Этап 2: Recurring MTProto synchronization — RED-GREEN-REFACTOR

- [x] 2.1 RED: покрыть eligible channel selection, bounded recurring sync и дедупликацию jobs/posts.
- [x] 2.2 GREEN: добавить recurring job и production/development schedule в `config/recurring.yml`.
- [x] 2.3 GREEN: выбрать активные subscribed public channels с authorized follower session.
- [x] 2.4 REFACTOR: применить RuboCop к изменённым Ruby-файлам.

### Этап 3: MTProto public-channel addition — RED-GREEN-REFACTOR

- [x] 3.1 RED: покрыть resolve/join, persistence, subscription и initial sync без Bot API membership.
- [x] 3.2 GREEN: заменить add path на MTProto resolve/join и I18n outcome keys.
- [x] 3.3 REFACTOR: применить RuboCop к изменённым Ruby-файлам.

### Этап 4: Verification and handoff

- [x] 4.1 Обновить архитектуру и ROADMAP.
- [x] 4.2 Запустить полный Rails suite, RuboCop, Brakeman и linux/amd64 Docker build.
- [x] 4.3 Fetch/rebase `main`, проверить intended diff, commit и push.
- [x] 4.4 Подготовить handoff parent agent для deploy/live verification; статус `delivered` не устанавливать до этого шага.
