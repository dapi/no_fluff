# Спецификация: Уведомление пользователей о деактивации каналов

## Обзор

Спецификация описывает систему автоматического уведомления всех пользователей, подписанных на канал, в момент когда канал становится неактивным (деактивируется).

## Цель

Обеспечить своевременное информирование пользователей о том, что канал, на который они подписаны, перестал быть активным, чтобы пользователи могли принять решение о сохранении или удалении подписки.

## Триггеры события

Деактивация канала происходит при возникновении ошибок мониторинга:

1. **Ошибка мониторинга** - когда при попытке получить посты из канала происходит ошибка:
   - Бот заблокирован администратором канала
   - Канал удален или недоступен
   - Другие технические ошибки при доступе к каналу

## Сценарии использования

### Основной сценарий
1. При мониторинге канала возникает ошибка
2. Канал помечается как деактивированный (deactivated_at сохраняется)
3. Система находит всех подписчиков канала
4. Каждому подписчику отправляется уведомление о деактивации
5. Подписки сохраняются - пользователь решает удалить их самостоятельно

## Бизнес-правила

1. **Все подписчики должны быть уведомлены** - независимо от их настроек доставки
2. **Уведомление отправляется немедленно** - в режиме реального времени
3. **Подписки сохраняются** - пользователь решает удалить их самостоятельно
4. **Повторные уведомления** - не отправляются если канал уже деактивирован
5. **Язык уведомления** - используется язык пользователя из его профиля

## Технические требования

### Модель данных

#### Channel (изменения)
```ruby
# Удаляем поле
# active :boolean  # УДАЛИТЬ

# Новые поля
deactivated_at :datetime     # Время когда канал стал неактивным (NULL = активен)
deactivation_reason :string   # Текст ошибки при деактивации
```

**Статус канала определяется полем `deactivated_at`:**
- `deactivated_at IS NULL` - канал активен
- `deactivated_at IS NOT NULL` - канал деактивирован

### Процесс обработки

#### 1. Деактивация канала
```ruby
# Channel#deactivate! (новый метод)
def deactivate!(error_message)
  # Проверяем что канал еще не деактивирован
  return if deactivated_at.present?

  transaction do
    update!(
      deactivated_at: Time.current,
      deactivation_reason: error_message
    )

    # Создаем задачу на уведомление всех подписчиков
    NotifyChannelSubscribersJob.perform_later(self)
  end
end

# Channel#active? (новый метод)
def active?
  deactivated_at.blank?
end

# Channel#inactive? (новый метод)
def inactive?
  deactivated_at.present?
end
```

#### 2. Уведомление подписчиков
```ruby
# NotifyChannelSubscribersJob
class NotifyChannelSubscribersJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(channel)
    # Находим всех подписчиков канала
    subscribers = channel.telegram_users.includes(:subscriptions)

    subscribers.each do |user|
      SendChannelDeactivationNotificationJob.perform_later(channel, user)
    end
  end
end
```

#### 3. Отправка уведомления
```ruby
# SendChannelDeactivationNotificationJob
class SendChannelDeactivationNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(channel, user)
    # Формируем сообщение
    message = build_deactivation_message(user, channel)

    # Отправляем через Telegram
    response = TelegramClient.send_message(
      chat_id: user.telegram_id,
      text: message,
      parse_mode: :html
    )

    # Логируем результат
    unless response.ok?
      Bugsnag.notify("Failed to send channel deactivation notification",
                     metadata: {
                       user_id: user.id,
                       channel_id: channel.id,
                       error: response.error
                     })
    end
  end

  private

  def build_deactivation_message(user, channel)
    I18n.t('notifications.channel_deactivated',
           channel_name: channel.username,
           reason: channel.deactivation_reason,
           locale: user.language_code || 'ru')
  end
end
```

### Очереди

Для уведомлений используется очередь `default` - никаких дополнительных настроек очередей не требуется.

### Тексты уведомлений

#### config/locales/ru.yml
```yaml
ru:
  notifications:
    channel_deactivated: |
      <b>🔴 Канал %{channel_name} недоступен</b>

      Причина: %{reason}

      Канал перестал отслеживаться системой. Вы можете сохранить подписку на случай восстановления или удалить её через /subscriptions.

      <i>Это автоматическое уведомление.</i>
```

### Обработка ошибок

1. **Ошибка отправки** - автоматическая повторная попытка через экспоненциальную задержку (3 попытки)
2. **Пользователь заблокировал бота** - логирование ошибки в Bugsnag
3. **Лимиты Telegram API** - автоматическая повторная попытка через retry mechanism

### Метрики и мониторинг

1. **Количество деактивированных каналов** - счетчик каналов с deactivated_at не NULL
2. **Ошибки отправки уведомлений** - мониторинг через Bugsnag
3. **Активные подписки на деактивированные каналы** - для анализа поведения пользователей

## Тестирование

### Unit тесты
1. Тест метода Channel#deactivate! - проверка установки deactivated_at и deactivation_reason
2. Тест методов Channel#active? и Channel#inactive?
3. Тест формирования уведомлений для разных языков
4. Тест проверки повторной деактивации (не должно создавать задачи повторно)

### Integration тесты
1. Тест полного процесса: деактивация → создание задачи → отправка уведомлений
2. Тест обработки ошибок отправки (retry mechanism)
3. Тест работы с большим количеством подписчиков

### Performance тесты
1. Тест производительности при 1000+ подписчиков канала
2. Тест нагрузки на систему при одновременной деактивации нескольких каналов

## UI/UX требования

### Сообщение в Telegram
- Использовать HTML форматирование
- Эмодзи 🔴 для обозначения проблемы
- Четкое указание причины недоступности канала
- Подсказка о дальнейших действиях пользователя (/subscriptions)

### Действия пользователя
- Подписки сохраняются - пользователь решает удалить их самостоятельно
- В /subscriptions показываются деактивированные каналы с пометкой статуса

## Безопасность

1. **Валидация данных** - проверка ID пользователей и каналов
2. **Rate limiting** - защита от спама уведомлений
3. **Аудит** - логирование всех деактиваций и уведомлений
4. **Приватность** - не раскрывать причину если она содержит чувствительную информацию

## Запуск по этапам

### Этап 1: Базовая функциональность
- Добавление полей `deactivated_at` и `deactivation_reason` в модель Channel
- Удаление поля `active` из модели Channel
- Создание Job для уведомления подписчиков
- Базовые уведомления о деактивации

### Этап 2: Интеграция
- Интеграция с процессом мониторинга каналов
- Вызов deactivation при возникновении ошибок мониторинга
- Обновление скопов для работы с новым полем deactivated_at

### Этап 3: Тестирование и оптимизация
- Написание тестов
- Performance тестирование
- Мониторинг и аналитика

## Условия выполнения

- Rails 8 приложение с Solid Queue
- Telegram бот API для отправки сообщений
- PostgreSQL для хранения данных
- Поддержка интернационализации (I18n)
- Bugsnag для отслеживания ошибок