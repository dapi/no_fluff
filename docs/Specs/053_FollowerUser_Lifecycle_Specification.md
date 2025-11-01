# Спецификация 053: FollowerUser Lifecycle Management

## Мета информация

- **Номер:** 053
- **Название:** Followeruser Lifecycle
- **Автор:**
- **Создана:** 2025-11-02
- **Статус:** delivered
- **Связанные спецификации:**



## Обзор

Спецификация описывает полный жизненный цикл FollowerUser аккаунтов: от создания до вывода из эксплуатации. Включает авторизацию, session management, безопасность, автоматическое обслуживание и compliance.

## Проблема

FollowerUser аккаунты требуют постоянного управления:
- Авторизация через Telegram App API
- Session управление и ротация
- Безопасность credential данных
- Мониторинг состояния здоровья
- Соблюдение Telegram ToS

## Решение

Комплексная система lifecycle management:
- Автоматизированная авторизация
- Secure session management
- Health monitoring и maintenance
- Security compliance
- Graceful degradation и recovery

## Жизненный цикл FollowerUser

### 1. Creation и Setup
```ruby
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
        priority: params[:priority] || 0,
        device_fingerprint: generate_device_fingerprint
      )

      # Start authorization process
      FollowerUsers::AuthorizationService.start_authorization(user)

      user
    end
  end
end
```

### 2. Authorization Flow
```ruby
class FollowerUsers::AuthorizationService
  def self.start_authorization(follower_user)
    client = TelegramUserClient.new(follower_user)
    auth_result = client.send_code_request(follower_user.phone_number)

    follower_user.update!(
      auth_status: :pending,
      session_string_encrypted: encrypt_session(auth_result.session_string)
    )

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

        # Initialize health monitoring
        FollowerUsers::HealthCheckJob.perform_later(follower_user.id)

        success_result("Follower user authorized successfully")
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

### 3. Session Management
```ruby
class FollowerUsers::SessionManager
  SESSION_ROTATION_INTERVAL = 30.days
  SESSION_VALIDITY_CHECK = 1.day

  def self.check_session_validity(follower_user)
    return unless follower_user.authorized?

    # Check session age
    days_since_auth = (Date.current - follower_user.last_authorized_at.to_date).to_i

    if days_since_auth >= SESSION_ROTATION_INTERVAL
      rotate_session(follower_user)
    else
      validate_session(follower_user)
    end
  end

  def self.rotate_session(follower_user)
    # Rotate session for security
    client = TelegramUserClient.new(follower_user)

    begin
      # Re-authorize with current credentials
      new_session = client.refresh_session
      follower_user.update!(
        session_string_encrypted: encrypt_session(new_session),
        last_authorized_at: Time.current
      )

      log_session_rotation(follower_user)
      success_result("Session rotated successfully")
    rescue => error
      handle_session_rotation_failure(follower_user, error)
    end
  end

  def self.validate_session(follower_user)
    client = TelegramUserClient.new(follower_user)

    begin
      test_result = client.test_connection

      unless test_result.success?
        follower_user.update!(auth_status: :restricted)
        alert_session_invalid(follower_user, test_result.error)
      end

      test_result.success?
    rescue => error
      follower_user.increment!(:consecutive_errors)
      false
    end
  end
end
```

### 4. Health Monitoring
```ruby
class FollowerUsers::HealthMonitor
  HEALTH_CHECK_INTERVAL = 1.hour
  CRITICAL_HEALTH_THRESHOLD = 30

  def self.perform_health_check(follower_user)
    health_checks = [
      check_telegram_connection(follower_user),
      check_session_validity(follower_user),
      check_rate_limit_status(follower_user),
      check_device_compatibility(follower_user),
      check_api_compliance(follower_user)
    ]

    overall_health = calculate_overall_health(health_checks)
    update_health_metrics(follower_user, overall_health, health_checks)

    # Trigger alerts and actions based on health
    handle_health_status(follower_user, overall_health)

    overall_health
  end

  private

  def self.check_telegram_connection(follower_user)
    client = TelegramUserClient.new(follower_user)

    begin
      test_result = client.test_connection
      {
        status: test_result.success? ? :healthy : :unhealthy,
        message: test_result.message,
        score: test_result.success? ? 100 : 0,
        details: test_result.details
      }
    rescue => error
      {
        status: :error,
        message: error.message,
        score: 0,
        details: { error_class: error.class.name }
      }
    end
  end

  def self.check_rate_limit_status(follower_user)
    usage_ratio = follower_user.daily_joins_count.to_f / follower_user.daily_joins_limit

    status = case usage_ratio
            when 0.0..0.5 then :healthy
            when 0.5..0.8 then :warning
            else :critical
            end

    score = case status
            when :healthy then 100
            when :warning then 70
            when :critical then 30
            end

    {
      status: status,
      message: "Daily usage: #{usage_ratio.round(2)}",
      score: score,
      details: { used: follower_user.daily_joins_count, limit: follower_user.daily_joins_limit }
    }
  end

  def self.handle_health_status(follower_user, health_score)
    case health_score
    when 0..CRITICAL_HEALTH_THRESHOLD
      # Critical health - take user out of pool
      follower_user.update!(workload_level: :overloaded)
      alert_critical_health(follower_user)
      trigger_failover_procedures(follower_user)
    when CRITICAL_HEALTH_THRESHOLD..50
      # Poor health - reduce workload
      follower_user.update!(workload_level: :heavy)
      alert_health_degradation(follower_user)
    when 50..80
      # Fair health - normal operation
      follower_user.update!(workload_level: :medium)
    else
      # Good health - can handle more load
      follower_user.update!(workload_level: :light)
    end
  end
end
```

### 5. Security Monitoring
```ruby
class FollowerUsers::SecurityMonitor
  SECURITY_CHECKS = [
    :suspicious_activity_pattern,
    :unusual_api_usage,
    :session_anomaly,
    :device_fingerprint_check,
    :geolocation_consistency,
    :credential_integrity
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

    log_security_check(follower_user, security_issues)
    security_issues
  end

  private

  def self.suspicious_activity_pattern(user)
    recent_activity = user.channel_joins.where('created_at > ?', 24.hours.ago)

    # Check for excessive activity
    if recent_activity.count > user.daily_joins_limit * 2
      return {
        suspicious: true,
        severity: :high,
        type: :excessive_joins,
        message: "Excessive join activity: #{recent_activity.count} joins"
      }
    end

    # Check for rapid succession joins
    join_times = recent_activity.pluck(:created_at)
    rapid_joins = detect_rapid_succession(join_times)

    if rapid_joins
      {
        suspicious: true,
        severity: :medium,
        type: :rapid_succession,
        message: "Rapid succession joins detected"
      }
    else
      { suspicious: false }
    end
  end

  def self.session_anomaly(user)
    # Check for session inconsistencies
    current_device = user.device_info
    expected_fingerprint = user.device_fingerprint

    if current_device['fingerprint'] != expected_fingerprint
      {
        suspicious: true,
        severity: :critical,
        type: :session_anomaly,
        message: "Device fingerprint mismatch detected"
      }
    else
      { suspicious: false }
    end
  end

  def self.credential_integrity(user)
    # Check for encrypted credential integrity
    begin
      decrypt_session(user.session_string_encrypted)
      { suspicious: false }
    rescue => error
      {
        suspicious: true,
        severity: :critical,
        type: :credential_corruption,
        message: "Credential corruption detected"
      }
    end
  end
end
```

### 6. Automated Maintenance
```ruby
class FollowerUsers::MaintenanceService
  # Daily maintenance tasks
  def self.perform_daily_maintenance
    FollowerUser.authorized.find_each do |user|
      reset_daily_counters(user)
      check_authorization_expiry(user)
      update_health_metrics(user)
      perform_security_scan(user)
    end

    generate_daily_report
  end

  # Weekly maintenance tasks
  def self.perform_weekly_maintenance
    rotate_sessions_if_needed
    cleanup_old_audit_logs
    update_device_fingerprints
    generate_performance_report
    review_security_incidents
  end

  # Monthly maintenance tasks
  def self.perform_monthly_maintenance
    full_security_audit
    update_telegram_compliance
    review_performance_metrics
    backup_critical_data
    plan_capacity_adjustments
  end

  private

  def self.reset_daily_counters(user)
    return unless user.last_reset_date < Date.current

    user.update!(
      daily_joins_count: 0,
      last_reset_date: Date.current
    )

    log_counter_reset(user)
  end

  def self.check_authorization_expiry(user)
    days_since_auth = (Date.current - user.last_authorized_at.to_date).to_i

    if days_since_auth >= 25  # 5 days before rotation
      alert_authorization_expiry(user, days_since_auth)
    end
  end

  def self.rotate_sessions_if_needed
    FollowerUser.authorized.find_each do |user|
      FollowerUsers::SessionManager.check_session_validity(user)
    end
  end
end
```

### 7. Decommissioning Process
```ruby
class FollowerUsers::DecommissionService
  def self.decommission_follower_user(follower_user, reason = :manual)
    ActiveRecord::Base.transaction do
      # Step 1: Stop new assignments
      follower_user.update!(auth_status: :restricted)

      # Step 2: Reassign all channels
      reassign_all_channels(follower_user)

      # Step 3: Clean up sessions
      cleanup_user_sessions(follower_user)

      # Step 4: Mark as decommissioned
      follower_user.update!(
        auth_status: :banned,
        decommissioned_at: Time.current,
        decommission_reason: reason
      )

      # Step 5: Archive data
      archive_user_data(follower_user)

      log_decommissioning(follower_user, reason)
    end
  end

  private

  def self.reassign_all_channels(follower_user)
    channels = follower_user.channels
    reassignment_count = 0

    channels.find_each do |channel|
      new_user = FollowerUsers::PoolManager.find_best_available_user(channel)

      if new_user
        reassign_channel(channel, follower_user, new_user)
        reassignment_count += 1
      else
        channel.update!(assignment_status: :pending_reassignment)
      end
    end

    notify_channel_reassignment(follower_user, reassignment_count)
  end

  def self.cleanup_user_sessions(follower_user)
    # Invalidate all active sessions
    follower_user.update!(session_string_encrypted: nil)

    # Notify external services
    notify_session_cleanup(follower_user)
  end
end
```

## Admin Interface

### User Management Dashboard
- Создание новых FollowerUser
- Авторизация и session management
- Health status мониторинг
- Security alerts и incidents

### Lifecycle Controls
- Manual session rotation
- Security scan triggers
- Maintenance operations
- Decommissioning procedures

### Compliance Monitoring
- Telegram ToS compliance статус
- Security incident reports
- Audit trail доступа
- Performance metrics

## Критерии успешности

### Security
- [ ] Secure credential хранение
- [ ] Session rotation каждые 30 дней
- [ ] Security anomaly detection
- [ ] Full audit trail
- [ ] Automated compliance checking

### Reliability
- [ ] Automatic session recovery
- [ ] Health monitoring accuracy > 95%
- [ ] Zero credential corruption
- [ ] Graceful degradation handling
- [ ] Complete backup capabilities

### Maintainability
- [ ] Automated daily/weekly/monthly tasks
- [ ] Clear decommissioning process
- [ ] Comprehensive logging
- [ ] Performance monitoring
- [ ] Manual override capabilities

## Риски и митигация

### 1. Session Hijacking
- **Риск**: Компрометация session
- **Митигация**: Regular rotation, device fingerprinting, anomaly detection

### 2. Credential Corruption
- **Риск**: Потеря access данных
- **Митигация**: Regular integrity checks, backup procedures, recovery protocols

### 3. Authorization Failures
- **Риск**: Невозможность авторизации
- **Митигация**: Multiple retry attempts, manual override, backup users

### 4. Security Breaches
- **Риск**: Unauthorized access
- **Митигация**: Comprehensive monitoring, immediate alerts, rapid response procedures

---

## Статус: draft

Эта спецификация описывает полный lifecycle управления FollowerUser аккаунтами и должна быть реализована после базовой модели и pool management системы.

**Связанные документы**:
- [046 User-based Channel Access](./046_Bot_Channel_Join_Process_Specification_Updated.md)
- [052 FollowerUser Pool Management](./052_FollowerUser_Pool_Management_Specification.md)
- [054 Channel Activity System](./054_Channel_Activity_System_Specification.md)