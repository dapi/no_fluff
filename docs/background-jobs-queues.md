# Background Jobs & Queues

## Обзор

В проекте используется **Solid Queue** для обработки фоновых задач. Задачи разделены на несколько очередей с разными приоритетами для оптимизации производительности и пользовательского опыта.

## Очереди и их приоритеты

Очереди обрабатываются в следующем порядке (от высокого приоритета к низкому):

### 1. `realtime` - Высший приоритет
**Назначение:** Срочные операции, требующие немедленного выполнения

**Параметры:**
- Threads: 3
- Processes: 2 (по умолчанию, настраивается через `REALTIME_CONCURRENCY`)
- Polling interval: 0.1 сек

**Использование:**
```ruby
class Telegram::SendMessageJob < ApplicationJob
  queue_as :realtime

  def perform(user_id, message)
    # Отправка сообщения пользователю
  end
end
```

**Примеры задач:**
- Отправка команд пользователю в Telegram
- Немедленная доставка дайджеста по запросу `/digest`
- Обработка критических уведомлений

---

### 2. `digest` и `default` - Средне-высокий приоритет
**Назначение:** Пользовательские функции, критичные для UX

**Параметры:**
- Threads: 5
- Processes: 3 (по умолчанию, настраивается через `DIGEST_CONCURRENCY`)
- Polling interval: 0.5 сек

**Использование:**
```ruby
class Digest::DeliverJob < ApplicationJob
  queue_as :digest

  def perform(digest_id)
    # Отправка дайджеста
  end
end
```

**Примеры задач:**
- `Digest::BuildJob` - формирование дайджестов
- `Digest::DeliverJob` - отправка дайджестов
- Стандартные задачи без явно указанной очереди

---

### 3. `content` и `channels` - Средний приоритет
**Назначение:** Обработка контента и мониторинг каналов

**Параметры:**
- Threads: 4
- Processes: 2 (по умолчанию, настраивается через `CONTENT_CONCURRENCY`)
- Polling interval: 1 сек

**Использование:**
```ruby
class Channels::MonitorJob < ApplicationJob
  queue_as :channels

  def perform
    # Мониторинг каналов
  end
end

class Content::ProcessPostJob < ApplicationJob
  queue_as :content

  def perform(post_id)
    # Обработка поста
  end
end
```

**Примеры задач:**
- `Channels::MonitorJob` - периодический мониторинг каналов
- `Content::ProcessPostJob` - сохранение и нормализация постов
- `Content::ClassifyJob` - AI классификация постов

---

### 4. `ai` и `low_priority` - Низкий приоритет
**Назначение:** Фоновые задачи обслуживания и очистки

**Параметры:**
- Threads: 2
- Processes: 1 (по умолчанию, настраивается через `BACKGROUND_CONCURRENCY`)
- Polling interval: 2 сек

**Использование:**
```ruby
class AI::CleanupChatsJob < ApplicationJob
  queue_as :ai

  def perform
    # Архивация старых чатов
  end
end
```

**Примеры задач:**
- `AI::CleanupChatsJob` - архивация и удаление старых AI чатов
- Cleanup задачи
- Периодическая оптимизация данных
- Генерация аналитики

---

## Конфигурация

Конфигурация очередей находится в `config/queue.yml`.

### Переменные окружения для production

```bash
# Количество процессов для каждого типа очередей
REALTIME_CONCURRENCY=2      # realtime задачи
DIGEST_CONCURRENCY=3        # digest и default задачи
CONTENT_CONCURRENCY=2       # content и channels задачи
BACKGROUND_CONCURRENCY=1    # ai и low_priority задачи
```

### Development и Test

В development и test окружениях используется дефолтная конфигурация с минимальными ресурсами.

---

## Best Practices

### Выбор правильной очереди

1. **Используйте `realtime`** только для операций, критичных для UX:
   - Ответы на команды пользователя
   - Немедленные уведомления

2. **Используйте `digest`** для операций, связанных с дайджестами:
   - Формирование дайджестов
   - Отправка дайджестов

3. **Используйте `content`** для обработки контента:
   - Классификация постов
   - Обработка медиа

4. **Используйте `channels`** для мониторинга:
   - Периодический сбор постов
   - Обновление информации о каналах

5. **Используйте `ai`** для AI операций:
   - Cleanup чатов
   - Архивация данных

6. **Используйте `low_priority`** для всего остального:
   - Генерация отчетов
   - Фоновая оптимизация

### Retry стратегии

```ruby
class MyJob < ApplicationJob
  queue_as :content

  # Повтор при ошибках API
  retry_on ExternalAPI::Error, wait: :exponentially_longer, attempts: 5

  # Игнорирование если запись удалена
  discard_on ActiveJob::DeserializationError
end
```

### Мониторинг

- Логируйте важные метрики (tokens, latency, success rate)
- Используйте structured logging для анализа
- Настройте алерты для критичных очередей

---

## Примеры использования

### Немедленная отправка сообщения
```ruby
Telegram::SendMessageJob.perform_later(user.id, "Hello!")
```

### Отложенная отправка дайджеста
```ruby
Digest::DeliverJob.set(wait: 1.hour).perform_later(digest.id)
```

### Периодический мониторинг
```ruby
# В initializer или через Solid Queue recurring jobs
Channels::MonitorJob.set(cron: "*/5 * * * *").perform_later
```

### Batch обработка
```ruby
posts.each do |post|
  Content::ClassifyJob.perform_later(post.id)
end
```
