# Спецификация 046: User-based Channel Access System

## Мета информация

- **Номер:** 046
- **Название:** Bot Channel Join Process Old
- **Автор:**
- **Создана:** 2025-11-02
- **Статус:** delivered
- **Связанные спецификации:**



## 🚨 ВАЖНОЕ ИЗМЕНЕНИЕ АРХИТЕКТУРЫ

### Проблема Telegram API
**Telegram Bot API НЕ позволяет ботам самостоятельно вступать в каналы и чаты.** Бот может быть добавлен только вручную администратором канала.

### Решение: Multi-User Pool Access
Для мониторинга каналов необходимо использовать:
1. **User Account Pool (Follower Users)** - пул аккаунтов Telegram пользователей
2. **Telegram App API** - приложение с `api_id` и `api_hash`
3. **User Authorization** - вход под учетными данными follower users
4. **Load Balancing** - распределение нагрузки между аккаунтами

## Общее описание
Система доступа к каналам через пул follower users для масштабируемого мониторинга контента. Включает управление состоянием доступа, load balancing, обработку ошибок и уведомление администраторов.

## Архитектура

### 1. Multi-User Pool Architecture
- **Назначение**: Пул FollowerUser аккаунтов для распределенного мониторинга
- **Масштаб**: 3-50 аккаунтов для преодоления лимитов Telegram
- **Load Balancing**: Автоматическое распределение каналов между аккаунтами
- **Ограничения**: 500 каналов/аккаунт, 50 вступлений/день

### 2. Базовые модели данных

#### Channel Model (ключевые поля)
```ruby
enum user_access_status: {
  not_joined: 0,    # Пользователь еще не вступал
  joining: 1,       # Процесс вступления в прогрессе
  joined: 2,        # Пользователь успешно вступил
  join_failed: 3,   # Не получилось вступить
  access_revoked: 4 # Доступ отозван (кикнули)
}

# Follower User assignment
reference :follower_user            # Назначенный follower user
enum :assignment_status, default: :unassigned
  # unassigned: 0  # Не назначен
  # assigned: 1    # Назначен
  # pending_reassignment: 2  # Ожидает переназначения
```

#### FollowerUser Model (базовая структура)
```ruby
# Учетные данные и авторизация
string :phone_number, null: false
enum auth_status: { pending: 0, authorized: 1, restricted: 2, banned: 3 }

# Capacity и метрики
integer :max_channels, default: 400
integer :daily_joins_limit, default: 50
integer :channels_count, default: 0
decimal :workload_score, precision: 5, scale: 2, default: 0.0

# Health monitoring
decimal :health_score, precision: 5, scale: 2, default: 100.0
integer :consecutive_errors, default: 0
```

### 3. Основной процесс вступления в канал
```ruby
class Channels::UserJoinJob < ApplicationJob
  def perform(channel_id, follower_user_id)
    # 1. Проверка доступности пользователя
    follower_user = FollowerUser.find(follower_user_id)
    return unless follower_user.authorized?

    # 2. Создание MTProto клиента
    client = TelegramUserClient.new(follower_user)

    # 3. Попытка вступления в канал
    result = client.join_channel(channel.username)

    # 4. Обработка результата
    if result.success?
      channel.update!(user_access_status: :joined)
      follower_user.increment!(:daily_joins_count)
    else
      handle_join_failure(channel, follower_user, result.error)
    end
  end
end
```

## Процесс работы

### 1. Добавление нового канала
```
1. Администратор добавляет канал
2. ChannelAssignmentService находит лучший follower user
3. Канал назначается пользователю
4. Запускается UserJoinJob
5. Follower user вступает в канал
6. Статус обновляется на joined
```

### 2. Load Balancing
```
1. Pool Manager проверяет нагрузку аккаунтов
2. При дисбалансе >30% запускается ребалансировка
3. Каналы перераспределяются между пользователями
4. Обновляются workload метрики
```

## Критерии успешности

### Функциональные требования
- [ ] Автоматическое вступление в 95% публичных каналов
- [ ] Load balancing между аккаунтами
- [ ] Надежная обработка ошибок
- [ ] Мониторинг статуса доступа

### Масштабирование
- [ ] Поддержка до 50 follower users
- [ ] Мониторинг до 20000 каналов
- [ ] Автоматическая ребалансировка
- [ ] Graceful degradation

### Безопасность
- [ ] Соблюдение Telegram rate limits
- [ ] Безопасное хранение учетных данных
- [ ] Устойчивость к блокировкам
- [ ] Автоматический failover

---

## Статус: draft (пересмотренная версия)

**Важное изменение**: Архитектура полностью пересмотрена с учетом ограничений Telegram API. Требуется детальная проработка user-based подхода.

## 📊 FollowerUser Управление и Lifecycle

### 1. Создание и настройка FollowerUser
```ruby
# app/services/follower_users/creation_service.rb
class FollowerUsers::CreationService
  def self.create_follower_user(params)
    ActiveRecord::Base.transaction do
      user = FollowerUser.create!(
        phone_number: params[:phone_number],
        username: params[:username],
        first_name: params[:first_name],
        last_name: params[:last_name],
        specialization: params[:specialization] || 'public',
        max_channels: params[:max_channels] || 400,
        daily_joins_limit: params[:daily_joins_limit] || 50,
        priority: params[:priority] || 0
      )

      # Generate device fingerprint
      user.update!(device_fingerprint: generate_device_fingerprint)

      # Start authorization process
      FollowerUsers::AuthorizationService.start_authorization(user)

      user
    end
  end
end
```

### 2. Authorization и Session Management
```ruby
# app/services/follower_users/authorization_service.rb
class FollowerUsers::AuthorizationService
  def self.start_authorization(follower_user)
    # Создаем MTProto клиент
    client = TelegramUserClient.new(follower_user)

    # Отправляем код подтверждения
    auth_result = client.send_code_request(follower_user.phone_number)

    follower_user.update!(
      auth_status: :pending,
      session_string_encrypted: encrypt_session(auth_result.session_string)
    )

    # Уведомляем администратора о необходимости ввода кода
    notify_admin_code_required(follower_user)
  end

  def self.complete_authorization(follower_user, code)
    client = TelegramUserClient.new(follower_user)

    begin
      auth_result = client.complete_authorization(code)

      if auth_result.success?
        follower_user.update!(
          auth_status: :authorized,
          session_string_encrypted: encrypt_session(auth_result.session_string),
          last_authorized_at: Time.current,
          device_info: auth_result.device_info
        )

        # Запускаем health check
        FollowerUsers::HealthCheckJob.perform_later(follower_user.id)

        success_result("Follower user successfully authorized")
      else
        error_result("Authorization failed", auth_result.error)
      end

    rescue => error
      follower_user.increment!(:consecutive_errors)
      error_result("Authorization error", error.message)
    end
  end
end
```

### 3. Activity Score - Метрика активности каналов
```yaml
# Что такое activity_score и зачем нужен:

activity_score:
  definition: "Числовой показатель активности канала (0.0-1.0)"

  components:
    - post_frequency: "Как часто постят в канале (30%)"
    - last_activity: "Время последнего поста (25%)"
    - engagement_rate: "Уровень вовлеченности (25%)"
    - content_relevance: "Релевантность контента для NoFluff (20%)"

  calculation: |
    activity_score = (
      (posts_per_day / max_posts_per_day) * 0.3 +
      (recency_score) * 0.25 +
      (avg_views / max_views) * 0.25 +
      (content_relevance_score) * 0.25
    ).round(2)

  usage:
    load_balancing: "Нагружать активные каналы на разные аккаунты"
    rebalancing: "Переносить неактивные каналы при ребалансировке"
    cleanup: "Удалять каналы с activity_score < 0.1"
    monitoring: "Следить за резкими изменениями активности"
```

```ruby
# app/services/channels/activity_calculator.rb
class Channels::ActivityCalculator
  def self.calculate_activity_score(channel)
    # 1. Post frequency (0-30 posts per day = 0-1.0)
    post_frequency = calculate_post_frequency(channel)

    # 2. Recency score (how recent was last activity)
    recency_score = calculate_recency_score(channel)

    # 3. Engagement rate
    engagement_score = calculate_engagement_score(channel)

    # 4. Content relevance for NoFluff
    relevance_score = calculate_content_relevance(channel)

    # Weighted calculation
    activity_score = (
      post_frequency * 0.3 +
      recency_score * 0.25 +
      engagement_score * 0.25 +
      relevance_score * 0.2
    ).round(2)

    channel.update!(activity_score: activity_score, last_activity_at: Time.current)
    activity_score
  end

  private

  def self.calculate_post_frequency(channel)
    # Posts per day in last week
    posts_count = channel.posts.where('created_at > ?', 1.week.ago).count
    [posts_count / 7.0 / 30.0, 1.0].min  # Normalize to 0-1
  end

  def self.calculate_recency_score(channel)
    return 0.0 unless channel.last_post_at

    hours_ago = (Time.current - channel.last_post_at) / 1.hour

    case hours_ago
    when 0..6      then 1.0    # Last 6 hours
    when 6..24     then 0.8    # Last day
    when 24..72    then 0.5    # Last 3 days
    when 72..168   then 0.2    # Last week
    else                0.0    # Older than week
    end
  end
end
```

### 4. Health Monitoring и Maintenance
```ruby
# app/services/follower_users/health_monitor.rb
class FollowerUsers::HealthMonitor
  HEALTH_CHECK_INTERVAL = 1.hour

  def self.perform_health_check(follower_user)
    health_checks = [
      check_telegram_connection(follower_user),
      check_session_validity(follower_user),
      check_rate_limit_status(follower_user),
      check_device_compatibility(follower_user)
    ]

    overall_health = calculate_overall_health(health_checks)

    follower_user.update!(
      health_score: overall_health,
      last_activity_at: Time.current
    )

    # Trigger alerts if health is critical
    if overall_health < 30
      alert_critical_health(follower_user, health_checks)
    end

    overall_health
  end

  private

  def self.check_telegram_connection(follower_user)
    client = TelegramUserClient.new(follower_user)

    begin
      test_result = client.test_connection
      { status: test_result.success? ? :healthy : :unhealthy,
        message: test_result.message,
        score: test_result.success? ? 100 : 0 }
    rescue => error
      { status: :error, message: error.message, score: 0 }
    end
  end

  def self.check_session_validity(follower_user)
    # Check if session is still valid
    days_since_auth = (Date.current - follower_user.last_authorized_at.to_date).to_i

    if days_since_auth > 30
      { status: :warning, message: "Session older than 30 days", score: 50 }
    else
      { status: :healthy, message: "Session valid", score: 100 }
    end
  end
end
```

### 5. Admin UI для управления FollowerUser Pool
```yaml
# Административный интерфейс:

dashboard_sections:
  pool_overview:
    - total_accounts: "Всего аккаунтов"
    - authorized_accounts: "Авторизованных"
    - healthy_accounts: "Здоровых"
    - overloaded_accounts: "Перегруженных"
    - total_channels_assigned: "Всего каналов"
    - pool_efficiency: "Эффективность пула"

  individual_accounts:
    - user_details: "Детали аккаунта"
    - health_metrics: "Метрики здоровья"
    - assigned_channels: "Назначенные каналы"
    - daily_usage: "Дневное использование"
    - error_history: "История ошибок"

  pool_management:
    - add_new_account: "Добавить новый аккаунт"
    - authorize_account: "Авторизовать аккаунт"
    - adjust_limits: "Настроить лимиты"
    - set_specialization: "Установить специализацию"
    - manual_rebalance: "Ручная ребалансировка"

  alerts_and_notifications:
    - health_alerts: "Алерты здоровья"
    - rate_limit_warnings: "Предупреждения о лимитах"
    - authorization_required: "Требуется авторизация"
    - failed_operations: "Сбои операций"
```

### 6. Automated Lifecycle Management
```ruby
# app/services/follower_users/lifecycle_manager.rb
class FollowerUsers::LifecycleManager
  # Ежедневные задачи
  def self.perform_daily_maintenance
    FollowerUser.authorized.find_each do |user|
      reset_daily_counters(user)
      check_authorization_expiry(user)
      update_health_metrics(user)
    end
  end

  # Еженедельные задачи
  def self.perform_weekly_maintenance
    rebalance_load_if_needed
    cleanup_inactive_channels
    rotate_sessions_if_needed
    generate_performance_report
  end

  private

  def self.reset_daily_counters(user)
    return unless user.last_reset_date < Date.current

    user.update!(
      daily_joins_count: 0,
      last_reset_date: Date.current
    )
  end

  def self.cleanup_inactive_channels
    # Удалять каналы с activity_score < 0.1 и неактивные > 30 дней
    Channel.where('activity_score < 0.1 AND last_activity_at < ?', 30.days.ago)
      .find_each do |channel|
      FollowerUsers::ChannelReassignmentService.reassign_channel(channel)
    end
  end
end
```

### 7. Security and Compliance Monitoring
```ruby
# app/services/follower_users/security_monitor.rb
class FollowerUsers::SecurityMonitor
  SECURITY_CHECKS = [
    :suspicious_activity_pattern,
    :unusual_api_usage,
    :session_anomaly,
    :device_fingerprint_check,
    :geolocation_consistency
  ].freeze

  def self.perform_security_check(follower_user)
    security_issues = []

    SECURITY_CHECKS.each do |check|
      result = send(check, follower_user)
      security_issues << result if result[:suspicious]
    end

    if security_issues.any?
      handle_security_issues(follower_user, security_issues)
    end

    security_issues
  end

  private

  def self.suspicious_activity_pattern(user)
    # Проверка на подозрительные паттерны активности
    recent_joins = user.channel_joins.where('created_at > ?', 24.hours.ago)

    if recent_joins.count > user.daily_joins_limit * 2
      { suspicious: true, type: :excessive_joins,
        message: "Excessive join activity detected" }
    else
      { suspicious: false }
    end
  end
end
```

---

## Следующие шаги:
1. **Phase 1**: Создать FollowerUser модель (multi-user ready) и миграцию
2. **Phase 1**: Настроить Telegram App API
3. **Phase 1**: Выбрать и интегрировать MTProto библиотеку
4. **Phase 1**: Реализовать TelegramUserClient service
5. **Phase 2**: Добавить ChannelAssignmentService
6. **Phase 2**: Реализовать PoolManager для load balancing
7. **Phase 2**: Создать Health Monitoring систему
8. **Phase 2**: Реализовать Activity Score расчет
9. **Phase 3**: Добавить LoadBalancer для ребалансировки
10. **Phase 3**: Реализовать FailoverManager
11. **Phase 3**: Создать Lifecycle Management
12. **Phase 4**: Создать Dashboard для мониторинга пула
13. **Phase 4**: Добавить Security Monitoring

**Связанные документы**:
- [Оригинальная спецификация](./046_Bot_Channel_Join_Process_Specification.md)
- [Multi-Follower User Strategy](./Architecture/multi-follower-user-strategy.md)
- [Telegram Rate Limits Analysis](./Architecture/telegram-rate-limits-analysis.md)
- [Telegram ToS Requirements](./Architecture/telegram-tos-requirements.md)
- [Telegram API obtaining api_id](https://core.telegram.org/api/obtaining_api_id)
- [План реализации](../Implementation/046_Bot_Channel_Join_Process_Implementation.md) - требует обновления