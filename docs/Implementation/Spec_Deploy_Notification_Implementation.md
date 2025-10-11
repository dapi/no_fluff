# План имплементации: Система уведомлений о деплое

## Этап 1: Создание модели и миграции

### 1.1 Создание модели DeployNotification
```bash
./bin/rails g model DeployNotification version:string:uniq metadata:jsonb
```

### 1.2 Настройка модели
- Добавить валидации и скоупы в `app/models/deploy_notification.rb`
- Настроить jsonb поле для metadata
- Добавить индексы для оптимизации
- Добавить `after_commit :notify_admins, on: :create` callback

## Этап 2: Создание Job для отправки уведомлений

### 2.1 Создание DeployNotificationJob
```bash
./bin/rails g job DeployNotification
```

### 2.2 Реализация логики отправки
- Определить как находить администраторов (TelegramUser с admin: true)
- Реализовать отправку через Telegram Bot API
- Добавить обработку ошибок и логирование
- Настроить retry механизмы

## Этап 3: Настройка очередей

### 3.1 Обновление конфигурации очередей
- Добавить очередь `notifications` в `config/queue.yml`
- Настроить отдельного воркера для notifications
- Установить приоритет ниже чем у content очереди

### 3.2 Настройка производительности
- Оптимизировать количество потоков для notifications
- Настроить polling interval

## Этап 4: Создание инициализатора

### 4.1 Создание файла инициализатора
- Создать `config/initializers/deploy_notification.rb`
- Реализовать получение версии приложения
- Добавить проверку существования записи
- Реализовать создание записи и запуск job

### 4.2 Определение версии приложения
- Использовать `AppVersion.to_s` для получения версии
- Убедиться что класс AppVersion доступен в инициализаторе

## Этап 5: Интеграция с Telegram

### 5.1 Определение администраторов
- Проверить существующую модель TelegramUser
- Добавить поле admin: true если отсутствует
- Создать миграцию для добавления поля

### 5.2 Форматирование уведомлений
- Создать шаблон сообщения о деплое
- Включить версию, время, и дополнительную информацию
- Добавить форматирование для лучшей читаемости

## Этап 6: Создание тестов

### 6.1 Unit тесты
- Тесты для модели DeployNotification
- Тесты валидаций и скоупов
- Тесты для jsonb поля metadata

### 6.2 Job тесты
- Тесты для DeployNotificationJob
- Моки для Telegram API
- Тесты обработки ошибок

### 6.3 Integration тесты
- Тест инициализатора
- Тест полного процесса деплоя
- Тесты с реальной базой данных

## Этап 7: Обработка ошибок и мониторинг

### 7.1 Error handling
- Добавить Bugsnag уведомления для ошибок
- Реализовать retry логику для job
- Добавить fallback механизмы

### 7.2 Мониторинг
- Добавить метрики для отслеживания деплоев
- Логирование всех этапов процесса
- Создание dashboard для мониторинга

## Этап 8: Документация

### 8.1 Техническая документация
- Обновить архитектурную документацию
- Добавить информацию о новой системе
- Создать troubleshooting guide

### 8.2 Пользовательская документация
- Инструкция для администраторов
- Описание формата уведомлений
- Настройки preferences

## Детальная реализация по шагам

### Шаг 1: Модель и миграция
```ruby
# Миграция
class CreateDeployNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_notifications do |t|
      t.string :version, null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :deploy_notifications, :version, unique: true
    add_index :deploy_notifications, :created_at
  end
end
```

```ruby
# Модель
class DeployNotification < ApplicationRecord
  validates :version, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_version, ->(version) { find_by(version: version) }

  after_commit :notify_admins, on: :create

  private

  def notify_admins
    DeployNotificationJob.perform_later(version, created_at, metadata)
  end
end
```

### Шаг 2: Job реализация
```ruby
class DeployNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(version, created_at, metadata = {})
    Rails.logger.info "Starting deploy notification for version #{version}"

    TelegramUser.where(admin: true).find_each do |admin|
      begin
        send_notification(admin, version, created_at, metadata)
      rescue => e
        Bugsnag.notify(e, {
          admin_id: admin.id,
          version: version,
          context: "deploy_notification"
        })
        Rails.logger.error "Failed to notify admin #{admin.id}: #{e.message}"
      end
    end

    Rails.logger.info "Completed deploy notification for version #{version}"
  end

  private

  def send_notification(admin, version, created_at, metadata)
    message = build_notification_message(version, created_at, metadata)
    # Telegram API call here
  end

  def build_notification_message(version, created_at, metadata)
    # Format message
  end
end
```

### Шаг 3: Инициализатор
```ruby
Rails.application.config.after_initialize do
  next unless defined?(Rails::Server) || Rails.env.production?

  version = AppVersion.to_s

  DeployNotification.find_or_create_by(version: version) do |record|
    record.metadata = build_metadata
  end
rescue => e
  Bugsnag.notify(e, { context: "deploy_notification_initializer" })
  Rails.logger.error "Deploy notification initialization failed: #{e.message}"
end
```

### Шаг 4: Конфигурация очередей
```yaml
# config/queue.yml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    # Existing workers...

    # Notifications worker
    - queues: "notifications"
      threads: 1
      processes: 1
      polling_interval: 2
```

## Checklist для имплементации

- [ ] Создать модель DeployNotification
- [ ] Создать миграцию
- [ ] Добавить валидации и скоупы
- [ ] Добавить `after_commit` callback в модель
- [ ] Создать DeployNotificationJob
- [ ] Реализовать отправку уведомлений
- [ ] Добавить обработку ошибок
- [ ] Настроить очереди
- [ ] Создать инициализатор
- [ ] Использовать AppVersion.to_s для получения версии
- [ ] Добавить тесты для модели
- [ ] Добавить тесты для callback
- [ ] Добавить тесты для job
- [ ] Добавить integration тесты
- [ ] Обновить документацию
- [ ] Тестировать в development
- [ ] Тестировать в production