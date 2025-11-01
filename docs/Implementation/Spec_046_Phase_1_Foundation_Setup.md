# Phase 1: Foundation Setup (2 недели)

## 📋 Обзор Phase 1

Первая фаза имплементации спецификации 046. Создаем базовую инфраструктуру для работы с одним follower user.

**Цель Phase 1**: Минимально работающий продукт - система может автоматически вступать в Telegram каналы через одного пользователя.

---

## 📊 Статус и Progress

**Статус**: planned
**Последнее обновление**: 2025-01-31
**Ответственный**: Данил Письменный
**Timeline**: 14 дней
**Priority**: P0 (Critical)
**Dependencies**: None
**Success Criteria**: Автоматическое вступление в каналы работает

---

## 🎯 Задачи Phase 1

### 1. Database Schema Changes
**Срок**: День 1-2
**Зависимости**: Нет

#### Задачи:
- [ ] Создать FollowerUser модель и миграцию
  ```bash
  rails g model FollowerUser phone_number:string:index:{unique:true} username:string first_name:string last_name:string auth_status:integer default:0 session_string_encrypted:text api_credentials_encrypted:text device_info:jsonb daily_joins_limit:integer default:50 daily_joins_count:integer default:0 last_reset_date:date max_channels:integer default:400 channels_count:integer default:0 workload_score:decimal{5,2} default:0.0 health_score:decimal{5,2} default:100.0 consecutive_errors:integer default:0 priority:integer default:0 specialization:string last_authorized_at:timestamp last_successful_join:timestamp last_activity_at:timestamp
  ```
- [ ] Обновить Channel модель новыми полями
  ```bash
  rails g migration AddFollowerUserToChannels follower_user:references index:true assignment_status:integer assigned_at:timestamp last_activity_at:timestamp activity_score:decimal{5,2} default:0.0
  ```
- [ ] Добавить индексы для оптимизации
- [ ] Добавить encrypts для защиты данных
- [ ] Проверить миграции в тестовой среде

#### Файлы для создания:
- `app/models/follower_user.rb`
- `app/models/concerns/channel_access.rb`
- `db/migrate/*_create_follower_users.rb`
- `db/migrate/*_add_follower_user_to_channels.rb`

---

### 2. ApplicationConfig Setup
**Срок**: День 2-3
**Зависимости**: Database schema

#### Задачи:
- [ ] Создать `config/configs/application_config.rb` с telegram конфигурацией
- [ ] Зарегистрировать приложение на https://my.telegram.org
- [ ] Получить api_id и api_hash
- [ ] Настроить follower users конфигурацию
- [ ] Добавить security settings для session encryption
- [ ] Настроить environment variables
- [ ] Создать validation для required credentials
- [ ] Создать follower user Telegram аккаунт

#### Файлы для создания:
- `config/configs/application_config.rb`
- `docs/setup/application_config_setup.md`
- `.env.example` (template для environment variables)

#### Конфигурация ApplicationConfig:
```ruby
# config/configs/application_config.rb
class ApplicationConfig
  telegram_app do
    api_id { ENV.fetch('TELEGRAM_API_ID') }
    api_hash { ENV.fetch('TELEGRAM_API_HASH') }

    default_credentials do
      api_id
      api_hash
    end
  end

  follower_users do
    max_daily_joins { 50 }
    max_channels_per_user { 400 }
    health_check_interval { 1.hour }
    session_encryption_key { ENV.fetch('SESSION_ENCRYPTION_KEY') }
    device_fingerprint_enabled { true }
  end
end
```

---

### 3. MTProto Library Integration
**Срок**: День 3-4
**Зависимости**: Telegram API credentials

#### Задачи:
- [ ] Исследовать доступные MTProto библиотеки для Ruby
  - telegram-rb
  - tdlib-ruby
  - pyrogram (через Python bridge)
- [ ] Выбрать наиболее подходящую библиотеку
- [ ] Создать gemfile запись
- [ ] Установить и настроить библиотеку
- [ ] Создать базовый TelegramUserClient wrapper

#### Файлы для создания:
- `Gemfile` (добавить gem)
- `app/services/telegram/user_client.rb`
- `app/services/telegram/session_manager.rb`
- `app/models/concerns/telegram_credentials.rb`

#### Архитектура с ApplicationConfig:
```ruby
# app/services/telegram/user_client.rb
class TelegramUserClient
  def initialize(follower_user)
    @follower_user = follower_user
    @credentials = @follower_user.api_credentials
  end

  def create_client
    ::Telegram::Client.new(
      api_id: @credentials[:api_id],
      api_hash: @credentials[:api_hash],
      session: @follower_user.decrypt_session
    )
  end

  def rate_limit_delay
    ApplicationConfig.follower_users.rate_limit_delay_between_requests
  end
end

# app/models/concerns/telegram_credentials.rb
module TelegramCredentials
  extend ActiveSupport::Concern

  def api_credentials
    {
      api_id: api_id || ApplicationConfig.telegram_app.default_credentials.api_id,
      api_hash: api_hash || ApplicationConfig.telegram_app.default_credentials.api_hash
    }
  end

  def decrypt_session
    return nil unless session_string_encrypted

    key = ApplicationConfig.follower_users.session_encryption_key
    encryptor = ActiveSupport::MessageEncryptor.new(key)
    encryptor.verify_and_decrypt(session_string_encrypted)
  end
end
```

---

### 4. Basic TelegramUserClient Service
**Срок**: День 4-6
**Зависимости**: MTProto Library

#### Задачи:
- [ ] Создать `app/services/telegram/user_client.rb` с ApplicationConfig интеграцией
- [ ] Реализовать базовые методы:
  ```ruby
  def initialize(follower_user)
  def create_client
  def join_channel(username)
  def leave_channel(username)
  def test_connection
  def get_channel_info(username)
  ```
- [ ] Добавить обработку ошибок и retry логику
- [ ] Интегрировать с session management через ApplicationConfig
- [ ] Добавить rate limiting на основе ApplicationConfig
- [ ] Написать unit тесты

#### Integration с ApplicationConfig:
```ruby
# app/services/telegram/user_client.rb (детали)
class TelegramUserClient
  include TelegramCredentials

  def join_channel(username)
    client = create_client
    rate_limit_delay # Использует ApplicationConfig
    client.join_channel(username)
  rescue ::Telegram::Errors::FloodWait => e
    Rails.logger.warn "Rate limited, waiting: #{e.delay}s"
    sleep(e.delay)
    retry
  rescue StandardError => e
    TelegramErrorHandler.handle_error(e, @follower_user)
    raise
  end
end
```

#### Файлы для создания:
- `app/services/telegram/user_client.rb`
- `test/services/telegram/user_client_test.rb`
- `app/services/telegram/error_handler.rb`
- `app/services/telegram/session_manager.rb`
- `app/models/concerns/telegram_credentials.rb`

---

### 5. Basic Channel Access Service
**Срок**: День 6-8
**Зависимости**: TelegramUserClient

#### Задачи:
- [ ] Создать `app/services/channels/channel_access_service.rb`
- [ ] Реализовать базовое вступление в канал с ApplicationConfig:
  ```ruby
  def self.join_channel(channel)
    follower_user = FollowerUser.authorized.first
    return error_result("No authorized follower user") unless follower_user

    client = TelegramUserClient.new(follower_user)
    result = client.join_channel(channel.username)

    # Update channel status based on result
    channel.update!(
      user_access_status: result.success? ? :joined : :join_failed,
      last_activity_at: Time.current,
      follower_user: follower_user
    )
  end
  ```
- [ ] Добавить обработку различных статусов
- [ ] Реализовать notification систему
- [ ] Написать unit тесты

#### Файлы для создания:
- `app/services/channels/channel_access_service.rb`
- `app/services/channels/notification_service.rb`
- `test/services/channels/channel_access_service_test.rb`

---

### 6. Background Jobs
**Срок**: День 8-10
**Зависимости**: Channel Access Service

#### Задачи:
- [ ] Создать `app/jobs/channels/channel_join_job.rb`
  ```ruby
  class Channels::ChannelJoinJob < ApplicationJob
    queue_as :channel_access
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(channel_id, follower_user_id = nil)
      # Implementation
    end
  end
  ```
- [ ] Создать `app/jobs/channels/channel_access_check_job.rb`
- [ ] Создать `app/jobs/follower_users/health_check_job.rb`
- [ ] Настроить очереди в `config/queue.yml`
- [ ] Написать unit тесты

#### Файлы для создания:
- `app/jobs/channels/channel_join_job.rb`
- `app/jobs/channels/channel_access_check_job.rb`
- `app/jobs/follower_users/health_check_job.rb`
- `config/queue.yml`
- `test/jobs/channels/channel_join_job_test.rb`

---

### 7. Error Handling and Notifications
**Срок**: День 10-11
**Зависимости**: Background Jobs

#### Задачи:
- [ ] Создать `app/services/channels/error_handler.rb`
- [ ] Реализовать обработку FLOOD_WAIT ошибок
- [ ] Создать систему уведомлений администраторов
- [ ] Интегрировать с Bugsnag
- [ ] Добавить логирование всех операций
- [ ] Написать тесты на error handling

#### Файлы для создания:
- `app/services/channels/error_handler.rb`
- `app/services/notifications/admin_notifier.rb`
- `lib/telegram_logger.rb`
- `test/services/channels/error_handler_test.rb`

---

### 8. Initial Testing
**Срок**: День 12-14
**Зависимости**: Все предыдущие задачи

#### Задачи:
- [ ] Создать тестовый follower user с ApplicationConfig
- [ ] Написать интеграционные тесты для вступления в канал
- [ ] Протестировать с реальными Telegram API
- [ ] Проверить rate limiting поведение (использует ApplicationConfig)
- [ ] Тестировать обработку ошибок
- [ ] Проверить session encryption/decryption
- [ ] Демонстрация работы системы

#### Testing с ApplicationConfig:
```ruby
# test/integration/channel_join_test.rb
class ChannelJoinTest < ActionDispatch::IntegrationTest
  test "full channel join workflow with ApplicationConfig" do
    channel = create(:channel)

    # Trigger join job
    Channels::ChannelJoinJob.perform_later(channel.id)

    # Wait for completion
    assert_performed_enqueued_jobs(1)
    perform_enqueued_jobs

    # Verify results
    channel.reload
    assert_equal 'joined', channel.user_access_status
    assert_not_nil channel.follower_user
    assert_not_nil channel.last_activity_at
  end
end
```

#### Тесты для создания:
- `test/integration/channel_join_workflow_test.rb`
- `test/system/follower_user_management_test.rb`
- `test/models/follower_user_test.rb`
- `test/models/channel_test.rb`
- `test/services/telegram/user_client_test.rb`
- `test/services/telegram/session_manager_test.rb`

---

## 🧪 Тестирование Strategy для Phase 1

### Unit Tests
```ruby
# test/models/follower_user_test.rb
class FollowerUserTest < ActiveSupport::TestCase
  test "can_join_channel? returns false when daily limit reached" do
    user = create(:follower_user, daily_joins_count: 50, daily_joins_limit: 50)
    assert_not user.can_join_channel?
  end

  test "workload_score calculation" do
    user = create(:follower_user, channels_count: 200, max_channels: 400)
    assert_equal 0.5, user.calculate_workload_score
  end

  test "api_credentials fallback to ApplicationConfig defaults" do
    user = create(:follower_user, api_id: nil, api_hash: nil)

    credentials = user.api_credentials
    assert_equal ApplicationConfig.telegram_app.default_credentials.api_id, credentials[:api_id]
    assert_equal ApplicationConfig.telegram_app.default_credentials.api_hash, credentials[:api_hash]
  end
end

# test/services/telegram/user_client_test.rb
class TelegramUserClientTest < ActiveSupport::TestCase
  test "uses ApplicationConfig for rate limiting" do
    follower_user = create(:follower_user, :authorized)
    client = TelegramUserClient.new(follower_user)

    ApplicationConfig.stub(:follower_users, double(rate_limit_delay_between_requests: 2)) do
      # Test that rate limiting delay is called
      client.send(:rate_limit_delay)
    end
  end
end
```

### Integration Tests
```ruby
# test/integration/channel_join_test.rb
class ChannelJoinTest < ActionDispatch::IntegrationTest
  test "full channel join workflow with ApplicationConfig" do
    # Create channel
    channel = create(:channel)

    # Trigger join job
    Channels::ChannelJoinJob.perform_later(channel.id)

    # Wait for completion
    assert_performed_enqueued_jobs(1)
    perform_enqueued_jobs

    # Verify results
    channel.reload
    assert_equal 'joined', channel.user_access_status
    assert_not_nil channel.follower_user
  end

  test "handles missing follower user gracefully" do
    channel = create(:channel)

    # Mock no authorized follower users
    FollowerUser.stub(:authorized, []) do
      Channels::ChannelJoinJob.perform_later(channel.id)
      perform_enqueued_jobs

      channel.reload
      assert_equal 'join_failed', channel.user_access_status
    end
  end
end
```

---

## 📊 Success Metrics для Phase 1

### Technical Metrics
- [ ] **Channel join success rate**: > 90%
- [ ] **Background job success rate**: > 95%
- [ ] **Test coverage**: > 85%
- [ ] **API response time**: < 5 секунд

### Business Metrics
- [ ] **Auto-join functionality**: Работает
- [ ] **Single channel monitoring**: Работает
- [ ] **Manual intervention reduction**: > 50%

---

## 🎯 Definition of Done для Phase 1

### Requirements:
- [ ] FollowerUser может вступить в канал автоматически
- [ ] Background jobs работают стабильно
- [ ] Базовая обработка ошибок реализована
- [ ] Мониторинг одного канала работает
- [ ] Все тесты проходят
- [ ] Базовая документация создана

### Demo Requirements:
- [ ] Добавить канал в систему
- [ ] Автоматическое вступление работает
- [ ] Статус канала обновляется
- [ ] Ошибки обрабатываются корректно

---

## 📋 Dependencies для Phase 2

**Что должно быть готово:**
- ✅ FollowerUser модель и миграции
- ✅ TelegramUserClient базовый функционал
- ✅ Background jobs инфраструктура
- ✅ Error handling framework
- ✅ Базовое тестирование

**Следующий шаг**: После завершения Phase 1 можно начинать Phase 2: Multi-User Pool.

---

## 🚀 Rollout Instructions

### Day 1-2: Database Setup
1. Запустить миграции
2. Создать первого FollowerUser
3. Настроить encryption

### Day 3-7: Core Services
1. Настроить Telegram API
2. Реализовать TelegramUserClient
3. Создать Channel Access Service

### Day 8-14: Testing & Demo
1. Написать тесты
2. Провести интеграционное тестирование
3. Подготовить демо

---

**📍 Status**: Ready for implementation
**🎯 Target**: MVP - работающее автоматическое вступление в каналы
**📅 Duration**: 14 дней
**👤 Owner**: Данил Письменный