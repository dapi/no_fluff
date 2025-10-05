# Спецификация: Уведомление пользователей о деактивации каналов

## Обзор

Спецификация описывает систему автоматического уведомления всех пользователей, подписанных на канал, в момент когда канал становится неактивным (деактивируется).

## Цель

Обеспечить своевременное информирование пользователей о том, что канал, на который они подписаны, перестал быть активным, чтобы пользователи могли принять решение о сохранении или удалении подписки.

## Триггеры события

Деактивация канала может произойти по следующим причинам:

1. **Ручная деактивация** - администратор системы вручную деактивирует канал
2. **Автоматическая деактивация** - система автоматически деактивирует канал при:
   - Отсутствии новых постов более N дней (настраиваемый порог)
   - Ошибках мониторинга канала (бот заблокирован, канал удален)
   - Недостаточной активности (количество постов ниже порога)

## Сценарии использования

### Основной сценарий
1. Система определяет, что канал должен быть деактивирован
2. Канал помечается как неактивный в базе данных
3. Система находит всех активных подписчиков канала
4. Каждому подписчику отправляется уведомление
5. Подписки не удаляются автоматически, но помечаются как неактивные

### Альтернативные сценарии

**Сценарий 1: Массовая деактивация**
- При деактивации нескольких каналов одновременно
- Уведомления группируются по пользователю
- Отправляется одно сообщение со списком всех затронутых каналов

**Сценарий 2: Временная деактивация**
- Канал деактивируется на время (технические работы)
- Отправляется уведомление о временном статусе
- При реактивации отправляется уведомление о восстановлении

## Бизнес-правила

1. **Все подписчики должны быть уведомлены** - независимо от их настроек доставки
2. **Уведомление отправляется немедленно** - в режиме реального времени
3. **Подписки сохраняются** - пользователь решает удалить их самостоятельно
4. **Повторные уведомления** - не отправляются если канал был ранее деактивирован
5. **Язык уведомления** - используется язык пользователя из его профиля

## Технические требования

### Модель данных

#### Channel (дополнения)
```ruby
# Новые поля
deactivation_reason :string   # 'manual', 'no_posts', 'monitoring_error', 'low_activity'
deactivated_at :datetime     # Время деактивации
deactivation_notified_at :datetime # Время отправки уведомлений
```

#### Subscription (дополнения)
```ruby
# Новые поля
channel_status_notified :boolean, default: false  # Было ли отправлено уведомление
last_status_notification_at :datetime              # Время последнего уведомления
```

#### ChannelDeactivationNotification (новая модель)
```ruby
class ChannelDeactivationNotification < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :channel
  belongs_to :subscription

  # Статусы доставки
  enum status: { pending: 0, sent: 1, failed: 2 }

  # Типы уведомлений
  enum notification_type: { deactivation: 0, reactivation: 1, temporary: 2 }

  validates :telegram_user_id, uniqueness: { scope: :channel_id, conditions: -> { where(status: :pending) } }
end
```

### Процесс обработки

#### 1. Деактивация канала
```ruby
# Channel#deactivate! (расширение)
def deactivate!(reason = :manual)
  transaction do
    update!(
      active: false,
      deactivation_reason: reason.to_s,
      deactivated_at: Time.current
    )

    # Создаем задачи на уведомление всех подписчиков
    CreateChannelDeactivationNotificationsJob.perform_later(self, reason)
  end
end
```

#### 2. Создание уведомлений
```ruby
# CreateChannelDeactivationNotificationsJob
class CreateChannelDeactivationNotificationsJob < ApplicationJob
  queue_as :notifications

  def perform(channel, reason)
    # Находим все активные подписки
    active_subscriptions = channel.subscriptions.active.includes(:telegram_user)

    # Создаем записи об уведомлениях
    notifications = active_subscriptions.map do |subscription|
      ChannelDeactivationNotification.create!(
        telegram_user: subscription.telegram_user,
        channel: channel,
        subscription: subscription,
        notification_type: :deactivation,
        status: :pending
      )
    end

    # Отправляем уведомления
    notifications.each do |notification|
      SendChannelStatusNotificationJob.perform_later(notification)
    end

    # Обновляем статус канала
    channel.update!(deactivation_notified_at: Time.current)
  end
end
```

#### 3. Отправка уведомлений
```ruby
# SendChannelStatusNotificationJob
class SendChannelStatusNotificationJob < ApplicationJob
  queue_as :notifications
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(notification)
    user = notification.telegram_user
    channel = notification.channel

    # Формируем сообщение
    message = build_deactivation_message(user, channel, notification.notification_type)

    # Отправляем через Telegram
    response = TelegramClient.send_message(
      chat_id: user.telegram_id,
      text: message,
      parse_mode: :html
    )

    # Обновляем статус
    if response.ok?
      notification.update!(status: :sent, sent_at: Time.current)
      notification.subscription.update!(
        channel_status_notified: true,
        last_status_notification_at: Time.current
      )
    else
      notification.update!(status: :failed, error_message: response.error)
      Bugsnag.notify("Failed to send channel deactivation notification",
                     metadata: {
                       notification_id: notification.id,
                       user_id: user.id,
                       channel_id: channel.id,
                       error: response.error
                     })
    end
  end

  private

  def build_deactivation_message(user, channel, type)
    case type
    when 'deactivation'
      I18n.t('notifications.channel_deactivated',
             channel_name: channel.username,
             reason: I18n.t("deactivation_reasons.#{channel.deactivation_reason}"),
             locale: user.language_code || 'ru')
    when 'reactivation'
      I18n.t('notifications.channel_reactivated',
             channel_name: channel.username,
             locale: user.language_code || 'ru')
    when 'temporary'
      I18n.t('notifications.channel_temporarily_deactivated',
             channel_name: channel.username,
             locale: user.language_code || 'ru')
    end
  end
end
```

### Очереди и приоритеты

```yaml
# config/queue.yml (дополнения)
workers:
  # Существующие воркеры...

  # Уведомления о статусе каналов
  - queues: "notifications"
    threads: 2
    processes: <%= ENV.fetch("NOTIFICATIONS_CONCURRENCY", 1) %>
    polling_interval: 0.1
    priority: 10  # Высокий приоритет для немедленной отправки
```

### Тексты уведомлений

#### config/locales/ru.yml
```yaml
ru:
  notifications:
    channel_deactivated: |
      <b>🔴 Канал %{channel_name} деактивирован</b>

      Причина: %{reason}

      Канал перестал отслеживаться системой. Вы можете сохранить подписку на случай восстановления или удалить её через /subscriptions.

      <i>Это автоматическое уведомление.</i>

    channel_reactivated: |
      <b>🟢 Канал %{channel_name} восстановлен</b>

      Отслеживание канала возобновлено. Продолжайте получать важные посты из этого источника.

      <i>Это автоматическое уведомление.</i>

    channel_temporarily_deactivated: |
      <b>🟡 Временные проблемы с каналом %{channel_name}</b>

      Канал временно недоступен для мониторинга. Мы пытаемся возобновить отслеживание. Подписка сохраняется.

      <i>Это автоматическое уведомление.</i>

  deactivation_reasons:
    manual: "Деактивирован администратором"
    no_posts: "Отсутствие новых постов длительное время"
    monitoring_error: "Ошибки мониторинга (бот заблокирован или канал удален)"
    low_activity: "Низкая активность канала"
```

### Обработка ошибок

1. **Ошибка отправки** - попытка повторной отправки через экспоненциальную задержку
2. **Пользователь заблокировал бота** - пометка уведомления как failed, логирование
3. **Долгая отправка** - таймаут через 30 секунд, пометка как failed
4. **Лимиты Telegram API** - автоматическая задержка и retry

### Метрики и мониторинг

1. **Количество уведомлений** - счетчик отправленных/неудачных уведомлений
2. **Время доставки** - среднее время от деактивации до отправки
3. **Реакции пользователей** - сколько пользователей удалили подписку после уведомления
4. **Ошибки** - мониторинг количества failed уведомлений

## Тестирование

### Unit тесты
1. Тест деактивации канала и создания задач
2. Тест создания записей об уведомлениях
3. Тест формирования сообщений для разных языков
4. Тест обновления статусов подписок

### Integration тесты
1. Тест полного процесса деактивации → уведомление
2. Тест обработки ошибок отправки
3. Тест массовой деактивации каналов
4. Тест повторной активации канала

### Performance тесты
1. Тест производительности при 1000+ подписчиков
2. Тест нагрузки на систему при массовой деактивации
3. Тест работы очередей уведомлений

## UI/UX требования

### Сообщение в Telegram
- Использовать HTML форматирование
- Понятные эмодзи для статусов (🔴 деактивация, 🟢 восстановление, 🟡 временно)
- Четкое указание причины деактивации
- Подсказка о дальнейших действиях пользователя

### Действия пользователя
- Предоставить быструю команду для управления подпиской
- Показать список затронутых каналов в /subscriptions
- Возможность восстановить подписку при реактивации канала

## Безопасность

1. **Валидация данных** - проверка ID пользователей и каналов
2. **Rate limiting** - защита от спама уведомлений
3. **Аудит** - логирование всех деактиваций и уведомлений
4. **Приватность** - не раскрывать причину если она содержит чувствительную информацию

## Запуск по этапам

### Этап 1: Базовая функциональность
- Добавление полей в модели
- Создание базовых Job для уведомлений
- Простые уведомления о деактивации

### Этап 2: Расширенная функциональность
- Уведомления о реактивации
- Временные уведомления
- Поддержка разных языков

### Этап 3: Оптимизация
- Массовые уведомления
- Аналитика и метрики
- Performance оптимизация

## Условия выполнения

- Rails 8 приложение с Solid Queue
- Telegram бот API для отправки сообщений
- PostgreSQL для хранения данных
- Поддержка интернационализации (I18n)