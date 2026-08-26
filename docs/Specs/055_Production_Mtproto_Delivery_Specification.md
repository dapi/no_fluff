# Спецификация 055: Production MTProto Delivery

## Мета информация

- **Номер:** 055
- **Статус:** implemented
- **Приоритет:** P0
- **Связанные спецификации:** 003, 046, 051

## Обзор и цель

Завершить следующий production-срез доставки контента: сохранять факт успешной доставки каждого `Post` каждому `TelegramUser`, регулярно синхронизировать активные публичные каналы через авторизованный MTProto follower user и добавлять публичный канал из бота через проверенный MTProto resolve/join-путь.

## Функциональные требования

1. `Delivery` — durable ledger пары `telegram_user`/`post` с уникальным индексом БД. Повторные и конкурентные запуски не посылают одно сообщение дважды. Запись создаётся только после успешного ответа Bot API; неудачная отправка остаётся доступной для retry.
2. Recurring-задача периодически ставит bounded MTProto sync только для активных, подписанных публичных каналов с авторизованным follower user. Один проход не создаёт повторных job или post.
3. Добавление публичного канала из Bot API использует MTProto resolve/join, сохраняет `Channel` и `Subscription` и ставит initial sync. Тексты результата берутся только из I18n.

## Нефункциональные требования и безопасность

- Postgres-уникальность — источник истины для идемпотентности.
- Чтение MTProto ограничено 1..100 сообщениями за sync.
- Сохраняются outbound Bot API polling, SOCKS5-конфигурация и шифрование follower session. Никакие секреты, номера, session strings, hashes и коды не попадают в логи, ответы или документацию.
- Ошибки внешних вызовов не создают ложный факт доставки; обработанные rescue уведомляют Bugsnag через существующий job/service механизм.

## Форматы данных

`deliveries`: `telegram_user_id`, `post_id`, `metadata jsonb`, timestamps; уникальный индекс `(telegram_user_id, post_id)`.

Recurring task вызывает `Channels::RecurringMtprotoChannelSyncJob` в очереди `channels`; каждая job вызывает sync с безопасным bounded limit.

## Edge cases

- Конкурирующие workers: конфликт уникального индекса означает «уже доставлено».
- Bot API возвращает `ok: false` или исключение: ledger не создаётся, job retryable.
- Нет authorized follower session: recurring задача ничего не ставит.
- Resolve/join неуспешен: не создаются Channel или Subscription.
- Повторное добавление пользователем возвращает существующее I18n-сообщение и не ставит дублирующий initial sync.

## Тестирование и критерии выполнения

- [x] Minitest покрывает ledger, retry и конкурентную уникальность.
- [x] Minitest покрывает выбор recurring каналов, bounded reads и отсутствие повторных imported posts/jobs.
- [x] Minitest покрывает MTProto add-path, persistence и enqueue initial sync.
- [x] Полный Rails suite, RuboCop, Brakeman и linux/amd64 Docker build проходят.

## Внедрение

Изменение подготовлено к деплою, но деплой и live verification выполняются отдельно владельцем production. Поэтому статус остаётся `implemented`, а не `delivered`.

## Статус: implemented

## История workflow

- 2026-08-26: `approved` → `in_progress` после явного approval пользователя.
- 2026-08-26: `in_progress` → `testing` после завершения трёх RED-GREEN-REFACTOR срезов.
- 2026-08-26: `testing` → `implemented` после полного test/lint/security/build набора.

## Связанные документы

- [План реализации](../Implementation/Spec_055_Production_Mtproto_Delivery_Implementation.md)
- [MTProto vertical slice](../Architecture/live-mtproto-vertical-slice.md)
- [ROADMAP](../ROADMAP.md)


## 10. История изменений

| Дата | Версия | Изменение | Автор |
|------|--------|-----------|--------|
| 2026-08-26 | Status | Статус изменен на 'implemented' | System |
