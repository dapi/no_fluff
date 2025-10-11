# Спецификация: Система уведомлений о деплое

## Обзор

Система автоматического уведомления разработчиков и администраторов о новых версиях приложения, развернутых на сервере.

## Требования

### Функциональные требования

1. **Автоматическое создание уведомления о деплое**
   - При запуске приложения должна создаваться запись о новой версии
   - Уникальность версии определяется по ключу `version`
   - Если запись с такой версией уже существует - игнорируется

2. **Модель данных**
   - `DeployNotification` - модель для хранения уведомлений о деплое
   - Поля: `version` (string, unique), `metadata` (jsonb)
   - `created_at` используется как время деплоя

3. **Фоновая задача**
   - После создания записи должна запускаться job для отправки уведомлений
   - Job отправляет уведомления всем администраторам

4. **Механизм инициализации**
   - Инициализация должна происходить в `config/initializers`
   - Автоматический запуск при старте приложения

### Нефункциональные требования

1. **Idempotency** - Повторные запуски с той же версией не должны создавать дубликаты
2. **Asynchronous processing** - Уведомления отправляются асинхронно
3. **Error handling** - Ошибки отправки должны логироваться, но не останавливать приложение
4. **Performance** - Инициализация не должна замедлять запуск приложения

## Модель данных

### DeployNotification

```ruby
# app/models/deploy_notification.rb
class DeployNotification < ApplicationRecord
  validates :version, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_version, ->(version) { find_by(version: version) }
end
```

### Миграция

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_deploy_notifications.rb
class CreateDeployNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_notifications do |t|
      t.string :version, null: false, index: { unique: true }
      t.jsonb :metadata, default: {}
      t.timestamps
    end
  end
end
```

## Job для отправки уведомлений

```ruby
# app/jobs/deploy_notification_job.rb
class DeployNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(version, created_at, metadata = {})
    # Найти всех администраторов
    # Отправить уведомления каждому
    # Логировать результаты
  end
end
```

## Инициализатор

```ruby
# config/initializers/deploy_notification.rb
Rails.application.config.after_initialize do
  # Получить текущую версию
  # Проверить наличие записи
  # Создать запись при необходимости
  # Запустить job
end
```

## Интеграция с существующей системой

### Настройки очередей

- Добавить новую очередь `notifications` в `config/queue.yml`
- Настроить отдельного воркера для уведомлений

### Администраторы

- Использовать существующую модель `TelegramUser` с флагом `admin: true`
- Или создать отдельную модель/таблицу для администраторов

### Уведомления

- Интеграция с Telegram Bot API
- Формат сообщения с информацией о версии и времени деплоя

## Требования к безопасности

1. **Version validation** - Валидация формата версии
2. **Admin verification** - Проверка прав администратора
3. **Rate limiting** - Ограничение частоты уведомлений
4. **Audit trail** - Логирование всех отправленных уведомлений

## Тестирование

1. **Unit тесты** для модели `DeployNotification`
2. **Job тесты** для `DeployNotificationJob`
3. **Integration тесты** для инициализатора
4. **End-to-end тесты** для полного процесса

## Метрики и мониторинг

1. **Deploy tracking** - Количество успешных деплоев
2. **Notification delivery** - Процент доставленных уведомлений
3. **Error tracking** - Ошибки отправки уведомлений
4. **Performance** - Время инициализации и отправки