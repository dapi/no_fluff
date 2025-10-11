# Реализация: Уведомления о деактивации каналов

## Обзор

Документация по реализации системы уведомлений пользователей при деактивации каналов, на которые они подписаны.

## Компоненты реализации

### 1. Расширение Telegram::ChannelService

**Файл**: `app/services/telegram/channel_service.rb`

**Метод**: `deactivate_channel_with_notifications!(channel, reason: nil)`

**Пример использования**:
```ruby
service = Telegram::ChannelService.new(Telegram.bot)
channel = Channel.find(123)

result = service.deactivate_channel_with_notifications!(channel, reason: 'admin_decision')

if result[:success]
  puts result[:message]  # "✅ Канал @channel деактивирован! Уведомления отправлены 5 подписчикам"
  puts "Подписчиков: #{result[:subscribers_count]}"
else
  puts "Ошибка: #{result[:message]}"
end
```

**Возвращаемое значение**:
```ruby
{
  success: true/false,
  message: "Сообщение для пользователя/администратора",
  subscribers_count: 5  # Только если success: true
}
```

### 2. TelegramNotificationService

**Файл**: `app/services/telegram_notification_service.rb`

**Основные методы**:

#### `send_channel_deactivation_notification(user, channel, reason)`
Отправляет уведомление пользователю о деактивации канала.

**Параметры**:
- `user` - TelegramUser
- `channel` - Channel
- `reason` - String или nil (причина деактивации)

#### `send_admin_deactivation_notification(admin_chat_id, channel, stats)`
Отправляет отчет администратору о результатах рассылки.

**Статистика**:
```ruby
stats = {
  total: 10,    # Всего подписчиков
  sent: 8,      # Успешно отправлено
  errors: 1,    # Ошибки отправки
  skipped: 1    # Пропущено (нет chat_id)
}
```

### 3. ChannelDeactivationNotificationJob

**Файл**: `app/jobs/channel_deactivation_notification_job.rb`

**Очередь**: `:notifications`

**Retry политика**: Экспоненциальный backoff, 5 попыток

**Использование**:
```ruby
# Прямой вызов (для тестов)
ChannelDeactivationNotificationJob.perform_now(channel, reason: 'inactive')

# Фоновое выполнение
ChannelDeactivationNotificationJob.perform_later(channel, reason: 'violation')
```

### 4. Локализация

**Файл**: `config/locales/ru.yml`

**Ключи**:
- `telegram_bot.channels.deactivate.*` - сообщения сервиса
- `telegram_bot.channel_deactivation.notification.*` - уведомления пользователям
- `telegram_bot.channel_deactivation.admin_notification.*` - уведомления администраторам

## Конфигурация

### Solid Queue

**Файл**: `config/queue.yml`

```yaml
workers:
  # Notifications (channel deactivation, user notifications)
  - queues: "notifications"
    threads: 2
    processes: <%= ENV.fetch("NOTIFICATIONS_CONCURRENCY", 1) %>
    polling_interval: 0.3
```

### Environment Variables

- `NOTIFICATIONS_CONCURRENCY` - количество процессов для очереди уведомлений (по умолчанию: 1)

## Причины деактивации

Предопределенные причины:
- `admin_decision` - "Решение администратора"
- `inactive` - "Канал неактивен длительное время"
- `violation` - "Нарушение правил платформы"
- `technical` - "Технические проблемы"

Можно использовать произвольный текст причины.

## Интеграция с существующим кодом

### Административные команды

Для добавления административной команды деактивации:

```ruby
# app/controllers/concerns/telegram/admin_commands.rb
def handle_channel_deactivation
  # Парсинг username канала
  username = extract_channel_username(params[:text])
  return unless username

  # Поиск канала
  channel = Channel.find_by(username: username)
  return reply_with("Канал не найден") unless channel

  # Деактивация с уведомлениями
  service = Telegram::ChannelService.new(bot)
  result = service.deactivate_channel_with_notifications!(channel, reason: 'admin_decision')

  reply_with(result[:message])
end
```

### Прямое использование

```ruby
# В любом месте кода
channel = Channel.find(params[:id])
service = Telegram::ChannelService.new(Telegram.bot)

if channel.active?
  result = service.deactivate_channel_with_notifications!(channel, reason: params[:reason])

  Rails.logger.info "Channel #{channel.username} deactivation: #{result}"
end
```

## Тестирование

### Unit тесты
- `test/services/telegram_channel_service_test.rb` - тесты расширения сервиса
- `test/services/telegram_notification_service_test.rb` - тесты сервиса уведомлений
- `test/jobs/channel_deactivation_notification_job_test.rb` - тесты фоновой задачи

### Integration тесты
- `test/integration/channel_deactivation_integration_test.rb` - полный процесс

### Performance тесты
- `test/performance/channel_deactivation_performance_test.rb` - тесты производительности

### Retry тесты
- `test/jobs/channel_deactivation_retry_test.rb` - тесты обработки ошибок

## Запуск тестов

```bash
# Все тесты функциональности
rails test test/services/telegram_notification_service_test.rb
rails test test/jobs/channel_deactivation_notification_job_test.rb
rails test test/integration/channel_deactivation_integration_test.rb

# Performance тесты (только при необходимости)
rails test test/performance/channel_deactivation_performance_test.rb

# Тесты retry механизма
rails test test/jobs/channel_deactivation_retry_test.rb
```

## Мониторинг и логирование

### Логи
Все операции логируются в `Rails.logger`:
- Запуск деактивации канала
- Результаты отправки уведомлений
- Ошибки и retry попытки

### Bugsnag
Критические ошибки отправляются в Bugsnag с контекстом:
- ID канала и пользователя
- Причина деактивации
- Тип операции

### Метрики
Можно добавить кастомные метрики:
- Количество деактивированных каналов
- Процент успешной доставки уведомлений
- Время обработки деактивации

## Безопасность

### Проверка прав
Метод `deactivate_channel_with_notifications!` не включает проверку прав администратора.
Эту проверку нужно реализовать на уровне вызывающего кода.

```ruby
# Пример проверки прав
unless current_user.admin?
  return { success: false, message: 'Доступ запрещен' }
end

result = service.deactivate_channel_with_notifications!(channel, reason: 'admin_decision')
```

### Rate limiting
Очередь `:notifications` использует настройки из `config/queue.yml` для ограничения скорости отправки.

## Производительность

### Оптимизации
- Использование `find_each` для пакетной обработки подписчиков
- `includes(:telegram_user)` для предзагрузки данных
- Задержки между отправками для соблюдения лимитов Telegram API

### Рекомендации
- Для каналов с >10,000 подписчиков рассмотреть разбивку на несколько задач
- Мониторить время выполнения для больших каналов
- Настроить concurrency в зависимости от нагрузки

## Troubleshooting

### Проблема: Уведомления не отправляются
**Решение**:
1. Проверить настройки Solid Queue
2. Проверить `ApplicationConfig.admin_chat_id` для admin уведомлений
3. Проверить наличие `chat_id` у пользователей

### Проблема: Медленная обработка
**Решение**:
1. Увеличить `NOTIFICATIONS_CONCURRENCY`
2. Проверить индексы в базе данных
3. Оптимизировать запросы к Subscription

### Проблема: Ошибки retry
**Решение**:
1. Проверить логи на наличие конкретных ошибок
2. Проверить доступность Telegram API
3. Проверить корректность токена бота

## Будущие улучшения

1. **Пакетная обработка** для очень больших каналов
2. **Персонализация** уведомлений на основе предпочтений
3. **Аналитика** реакций пользователей на уведомления
4. **Webhook** для внешних систем о деактивации каналов
5. **Шаблоны** уведомлений для разных типов каналов

## Версионирование

- **Версия 1.0** - Базовая функциональность
- **Версия 1.1** - Performance оптимизации
- **Версия 1.2** - Расширенные причины деактивации

## Поддержка

При возникновении проблем:
1. Проверить логи приложения
2. Проверить логи Solid Queue
3. Проверить статус Bugsnag
4. Связаться с командой разработки