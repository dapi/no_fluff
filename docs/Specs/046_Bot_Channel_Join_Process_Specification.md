# Спецификация 046: Bot Channel Join Process

## Общее описание
Процесс автоматического вступления Telegram бота в каналы, добавленные в систему, для мониторинга контента. Включает управление состоянием вступления, обработку ошибок и уведомление администраторов.

## Основные функции

### 1. Установка состояний вступления бота в канал
- **Состояния**:
  - `not_joined` - бот еще не вступал в канал
  - `joining` - процесс вступления в прогрессе
  - `joined` - бот успешно вступил в канал
  - `join_failed` - не получилось вступить в канал

### 2. Job для вступления в канал
- **Название**: `Channels::BotJoinJob`
- **Очередь**: `channels`
- **Триггер**: После добавления нового канала в систему
- **Retries**: 3 попытки с экспоненциальным backoff

### 3. Мониторинг только активных каналов
- Учитывать состояние `bot_join_status` при выборе каналов для мониторинга
- Мониторить только каналы со статусом `joined`
- Пропускать каналы со статусами `not_joined`, `joining`, `join_failed`

### 4. Обработка результатов вступления
- **Успешное вступление**:
  - Обновить статус на `joined`
  - Отправить уведомление администраторам
  - Начать мониторинг канала

- **Неудачное вступление**:
  - Обновить статус на `join_failed`
  - Сохранить причину ошибки
  - Отправить уведомление администраторам с деталями

## Детали состояний

### Bot Join Status (enum)
```ruby
enum bot_join_status: {
  not_joined: 0,    # Бот еще не пытался вступить
  joining: 1,       # Процесс вступления в прогрессе
  joined: 2,        # Бот успешно вступил
  join_failed: 3    # Не получилось вступить
}
```

### Поля модели Channel
```ruby
# Существующие поля + новые:
t.string :bot_join_status, default: 'not_joined'
t.text :bot_join_error, null: true
t.datetime :bot_join_at, null: true
```

## Process Flow

### 1. Добавление канала
```
User добавляет канал
       ↓
ChannelService.add_channel_to_database
       ↓
Если канал создан успешно → Channels::BotJoinJob.perform_later(channel.id)
```

### 2. Процесс вступления бота
```
Channels::BotJoinJob.perform(channel.id)
       ↓
Обновить статус на joining
       ↓
Попытаться вступить в канал через Telegram API
       ↓
Если успех → статус joined, уведомить админов
Если ошибка → статус join_failed, сохранить ошибку, уведомить админов
```

### 3. Мониторинг каналов
```
Channels::MonitorJob.perform
       ↓
Только каналы где active: true И bot_join_status: 'joined'
       ↓
Запуск FetchPostsJob для каждого подходящего канала
```

## Error handling

### Типы ошибок вступления
- **Channel is private** - канал приватный, требуется приглашение
- **Bot was kicked** - бота удалили из канала
- **Too many attempts** - превышен лимит попыток вступления
- **Invalid invite link** - невалидная ссылка-приглашение
- **Bot permissions insufficient** - недостаточно прав у бота
- **API rate limit** - превышен лимит запросов к Telegram API
- **Network error** - проблемы с сетью
- **Unknown error** - неизвестная ошибка

### Стратегия обработки ошибок
- Retry 3 раза с increasing interval (1, 5, 15 минут)
- Сохранять детальную информацию об ошибке
- Отправлять уведомление администраторам после финальной неудачи
- Блокировать повторные попытки на 1 час после 3 неудач

## Уведомления администраторам

### Успешное вступление
```
✅ Бот вступил в канал @channel_username
Канал: [Название] (@username)
ID: [telegram_id]
Подписчиков: [count]
Время вступления: [timestamp]
```

### Неудачное вступление
```
❌ Не удалось вступить в канал @channel_username
Канал: [Название] (@username)
ID: [telegram_id]
Ошибка: [error_message]
Код ошибки: [error_code]
Время: [timestamp]
Попыток: [attempt_count]
```

## Integration points

### Telegram Bot API методы
- `get_chat()` - проверка доступа к каналу
- `join_chat()` - вступление в публичный канал
- `accept_chat_join_request()` - принятие запроса на вступление
- `leave_chat()` - выход из канала (если нужно)

### Существующие Job'ы
- `Channels::MonitorJob` - обновить фильтр каналов
- `Channels::FetchPostsJob` - проверять статус перед выполнением
- `Content::ProcessPostJob` - без изменений

### Административные функции
- Уведомления через существующий `ErrorNotificationService`
- Команда для ретрая встуления в проблемные каналы
- Статистика по каналам с проблемами вступления

## Performance requirements

### Время выполнения
- BotJoinJob: < 30 секунд
- Проверка статуса канала: < 5 секунд
- Обновление мониторинга: без изменений

### Rate limiting
- Максимум 10 попыток вступления в минуту
- Использовать существующий rate limiter для Telegram API
- Batch обработка для уведомлений админов

## Безопасность

### Проверки
- Валидировать telegram_id перед попыткой вступления
- Проверять права бота перед вступлением
- Логировать все попытки вступления

### Ограничения
- Не вступать в приватные каналы без приглашения
- Блокировать подозрительную активность
- Валидировать все входящие данные

---

# Acceptance Criteria

## Feature: Автоматическое вступление бота в каналы

### Scenario: Успешное вступление в публичный канал
**Given** администратор добавляет публичный канал "@example_channel"
**When** канал сохраняется в базе данных
**Then** создается задача Channels::BotJoinJob
**And** статус канала bot_join_status = "not_joined"
**When** задача выполняется
**Then** бот пытается вступить в канал
**And** статус обновляется на "joining"
**If** вступление успешно
**Then** статус обновляется на "joined"
**And** bot_join_at устанавливается в текущее время
**And** администраторы получают уведомление об успехе

### Scenario: Неудачное вступление (приватный канал)
**Given** администратор добавляет приватный канал
**When** Channels::BotJoinJob пытается вступить
**And** канал приватный/недоступен
**Then** статус обновляется на "join_failed"
**And** bot_join_error сохраняет описание ошибки
**And** администраторы получают уведомление об ошибке
**And** канал не участвует в мониторинге

### Scenario: Retry механизм
**Given** первая попытка вступления неудачна (временная ошибка)
**When** задача.retry_on срабатывает
**Then** через 1 минуту повторная попытка
**If** вторая попытка неудачна
**Then** через 5 минут третья попытка
**If** все попытки неудачны
**Then** финальный статус "join_failed"
**And** администраторам отправляется финальное уведомление

### Scenario: Мониторинг только вступивших каналов
**Given** есть 3 канала:
- channel_1 с bot_join_status = "joined"
- channel_2 с bot_join_status = "not_joined"
- channel_3 с bot_join_status = "join_failed"
**When** Channels::MonitorJob запускается
**Then** обрабатывается только channel_1
**And** channel_2 и channel_3 игнорируются

---

# Критерии успеха

## Функциональные критерии
- [ ] Бот автоматически вступает в новые каналы
- [ ] Статусы вступления корректно отслеживаются
- [ ] Ошибки вступления обрабатываются и сохраняются
- [ ] Администраторы получают уведомления о результатах
- [ ] Мониторинг работает только для вступивших каналов
- [ ] Retry механизм работает корректно

## Нефункциональные критерии
- [ ] Процесс вступления занимает < 30 секунд
- [ ] Все ошибки логируются
- [ ] Rate limiting соблюдаются
- [ ] Нет дублирования задач
- [ ] Корректная работа при высокой нагрузке

## Интеграционные критерии
- [ ] Работает с существующим Channels::MonitorJob
- [ ] Интегрируется с Telegram::ChannelService
- [ ] Использует существующую систему уведомлений
- [ ] Совместим с Solid Queue
- [ ] Не нарушает существующую логику добавления каналов

---

# Архитектура

## Диаграмма зависимостей
```
ChannelService.add_channel_to_database
           ↓
   Channels::BotJoinJob
           ↓
   Telegram Bot API
           ↓
   Обновление Channel.bot_join_status
           ↓
   Уведомление администраторов

Channels::MonitorJob
           ↓
   фильтр Channel.where(bot_join_status: 'joined')
           ↓
   Channels::FetchPostsJob
```

## Поток данных
1. Пользователь добавляет канал через ChannelService
2. Канал сохраняется в БД со статусом not_joined
3. Создается BotJoinJob для вступления
4. Job пытается вступить через Telegram API
5. Обновляет статус и сохраняет результат
6. Отправляет уведомление администраторам
7. MonitorJob использует только каналы со статусом joined

---

# Техническая спецификация

## Новые поля в модели Channel
```ruby
class AddBotJoinFieldsToChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :channels, :bot_join_status, :string, default: 'not_joined', null: false
    add_column :channels, :bot_join_error, :text
    add_column :channels, :bot_join_at, :datetime
    add_index :channels, :bot_join_status
    add_index :channels, [:bot_join_status, :active]
  end
end
```

## Обновление модели Channel
```ruby
class Channel < ApplicationRecord
  # ... существующий код ...

  enum bot_join_status: {
    not_joined: 0,
    joining: 1,
    joined: 2,
    join_failed: 3
  }

  # Scopes
  scope :joined, -> { where(bot_join_status: 'joined') }
  scope :not_joined, -> { where(bot_join_status: 'not_joined') }
  scope :joining, -> { where(bot_join_status: 'joining') }
  scope :join_failed, -> { where(bot_join_status: 'join_failed') }

  # Methods
  def start_joining!
    update!(bot_join_status: 'joining')
  end

  def mark_as_joined!
    update!(bot_join_status: 'joined', bot_join_at: Time.current, bot_join_error: nil)
  end

  def mark_as_join_failed!(error_message)
    update!(bot_join_status: 'join_failed', bot_join_error: error_message)
  end

  def bot_can_monitor?
    active? && joined?
  end
end
```

## Класс Channels::BotJoinJob
```ruby
class Channels::BotJoinJob < ApplicationJob
  queue_as :channels
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(channel_id)
    with_error_context(channel_id: channel_id, action: 'bot_join') do
      channel = Channel.find(channel_id)

      Rails.logger.info "Starting bot join process for channel #{channel.username}"

      # Обновляем статус
      channel.start_joining!

      # Пытаемся вступить в канал
      success = attempt_to_join_channel(channel)

      if success
        channel.mark_as_joined!
        notify_admins_success(channel)
        Rails.logger.info "Bot successfully joined channel #{channel.username}"
      else
        channel.mark_as_join_failed!(error_message)
        notify_admins_failure(channel, error_message)
        Rails.logger.error "Bot failed to join channel #{channel.username}: #{error_message}"
      end
    end
  end

  private

  def attempt_to_join_channel(channel)
    # Логика вступления через Telegram API
  end

  def notify_admins_success(channel)
    # Отправка уведомления об успехе
  end

  def notify_admins_failure(channel, error)
    # Отправка уведомления об ошибке
  end
end
```

## Обновление Channels::MonitorJob
```ruby
class Channels::MonitorJob < ApplicationJob
  def perform(*args)
    # Только каналы где бот вступил
    channels = Channel.joined
                     .joins(:subscriptions)
                     .where(subscriptions: { active: true })
                     .active
                     .needs_monitoring

    # ... остальная логика без изменений
  end
end
```

---

# Тест-план

## Unit тесты
- [ ] Channel.model корректно работает с новыми полями
- [ ] Channel.scopes возвращают правильные выборки
- [ ] Channel#bot_can_monitor? работает корректно
- [ ] Channels::BotJoinJob.perform успешно вступает в канал
- [ ] Channels::BotJoinJob.handle ошибки вступления
- [ ] Retry механизм работает корректно

## Integration тесты
- [ ] BotJoinJob интегрируется с Telegram Bot API
- [ ] Уведомления администраторам отправляются
- [ ] MonitorJob использует только joined каналы
- [ ] ChannelService создает BotJoinJob после добавления канала

## End-to-end тесты
- [ ] Полный сценарий добавления канала → вступления бота → мониторинга
- [ ] Полный сценарий неудачного вступления с уведомлениями
- [ ] Полный сценарий retry механизма

## Performance тесты
- [ ] Load testing: 50 каналов в минуту
- [ ] Memory usage testing
- [ ] Response time testing

---

# Связанные документы
- [Документация telegram-bot gem](../gems/telegram-bot.md)
- [C4 Model архитектура](../Architecture/c4-model.md)
- [Конфигурация очередей](../../config/queue.yml)
- [Существующая Channel модель](../../app/models/channel.rb)
- [Channels::MonitorJob](../../app/jobs/channels/monitor_job.rb)