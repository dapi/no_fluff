# Спецификация 052: FollowerUser Pool Management

## Мета информация

- **Номер:** 052
- **Название:** Followeruser Pool Management
- **Автор:**
- **Создана:** 2025-11-02
- **Статус:** delivered
- **Связанные спецификации:**



## Обзор

Спецификация описывает систему управления пулом FollowerUser аккаунтов для масштабирования мониторинга каналов. Включает load balancing, health monitoring, failover механизмы и автоматическое распределение нагрузки между аккаунтами.

## Проблема

Один FollowerUser аккаунт имеет ограничения:
- Максимум 500 каналов
- 50-100 вступлений в день
- Single point of failure
- Неравномерная нагрузка

## Решение

Multi-user pool система с автоматическим управлением нагрузкой:
- Load balancing между аккаунтами
- Health monitoring каждого пользователя
- Автоматический failover
- Динамическая ребалансировка

## Архитектура

### 1. Pool Structure
```ruby
# Пул аккаунтов с разными ролями
class FollowerUser < ApplicationRecord
  enum workload_level: { light: 0, medium: 1, heavy: 2, overloaded: 3 }
  enum priority: { normal: 0, high: 1, critical: 2 }

  # Workload metrics
  decimal :workload_score, precision: 5, scale: 2, default: 0.0
  integer :channels_count, default: 0
  integer :max_channels, default: 400

  # Health metrics
  decimal :health_score, precision: 5, scale: 2, default: 100.0
  integer :consecutive_errors, default: 0
end
```

### 2. Load Balancing Strategy
```ruby
class FollowerUsers::PoolManager
  def self.assign_channel(channel)
    # Находим лучший доступный аккаунт
    best_user = find_best_available_user(channel)

    if best_user
      assign_channel_to_user(best_user, channel)
    else
      handle_no_available_users(channel)
    end
  end

  def self.find_best_available_user(channel)
    available_users = FollowerUser.authorized
      .where('channels_count < max_channels')
      .where('daily_joins_count < daily_joins_limit')
      .where('consecutive_errors < 3')
      .order(:workload_score)

    # Специализация под тип канала
    specialized = available_users.where(specialization: channel.specialization)
    specialized.any? ? specialized.first : available_users.first
  end
end
```

### 3. Health Monitoring
```ruby
class FollowerUsers::HealthMonitor
  HEALTH_CHECKS = [
    :telegram_connection,
    :session_validity,
    :rate_limit_status,
    :device_compatibility
  ].freeze

  def self.perform_health_check(follower_user)
    health_results = HEALTH_CHECKS.map { |check| send(check, follower_user) }
    overall_health = calculate_overall_health(health_results)

    follower_user.update!(health_score: overall_health)

    # Алерты при критических проблемах
    alert_critical_health(follower_user) if overall_health < 30

    overall_health
  end
end
```

### 4. Failover System
```ruby
class FollowerUsers::FailoverManager
  def self.handle_user_failure(follower_user, error)
    follower_user.increment!(:consecutive_errors)

    if follower_user.consecutive_errors >= 5
      mark_user_unavailable(follower_user)
      reassign_user_channels(follower_user)
    end

    alert_user_failure(follower_user, error)
  end

  def self.reassign_user_channels(failed_user)
    channels = failed_user.channels

    channels.find_each do |channel|
      new_user = FollowerUsers::PoolManager.find_best_available_user(channel)

      if new_user
        reassign_channel(channel, failed_user, new_user)
      else
        channel.update!(assignment_status: :pending_reassignment)
      end
    end
  end
end
```

## Основные компоненты

### 1. Channel Assignment Service
- Автоматический выбор оптимального пользователя
- Специализация под типы каналов
- Учет workload и health метрик

### 2. Load Balancer
- Регулярная проверка баланса нагрузки
- Trigger-based ребалансировка
- Перераспределение перегруженных каналов

### 3. Health Monitor
- Проверка состояния каждого аккаунта
- Telegram connection тесты
- Session validity проверки

### 4. Failover Manager
- Автоматическое обнаружение проблемных аккаунтов
- Переназначение каналов
- Recovery попытки

## Процессы

### 1. Channel Assignment
```
1. Новый канал добавляется в систему
2. PoolManager находит лучший доступный аккаунт
3. Учитывается специализация и workload
4. Канал назначается пользователю
5. Запускается процесс вступления
```

### 2. Load Rebalancing
```
1. Регулярная проверка workload баланса
2. При дисбалансе >30% запускается ребалансировка
3. Выбираются каналы для переноса
4. Каналы переназначаются менее загруженным аккаунтам
```

### 3. Health Monitoring
```
1. Ежечасная проверка каждого аккаунта
2. Тестирование Telegram connection
3. Проверка session validity
4. Расчет общего health score
5. Алерты при критических проблемах
```

### 4. Failover Process
```
1. Обнаружение ошибки или сбоя
2. Инкремент consecutive_errors
3. При 5+ ошибках - аккаунт помечается как недоступный
4. Каналы переназначаются другим пользователям
5. Попытка восстановления через 24 часа
```

## Метрики и Monitoring

### Pool Metrics
- Total accounts: 3-50 аккаунтов
- Authorized accounts: % активных
- Healthy accounts: % со здоровьем >70
- Pool efficiency: % использования емкости
- Daily joins capacity: суммарная емкость

### Individual Metrics
- Workload score: 0.0-1.0 нагрузка
- Health score: 0-100 здоровье
- Channels assigned: количество каналов
- Error rate: % ошибочных операций
- Success rate: % успешных вступлений

## Admin Interface

### Pool Overview Dashboard
- Общая статистика пула
- График нагрузки по аккаунтам
- Health status всех пользователей
- Алерты и предупреждения

### Individual Account Management
- Детали каждого аккаунта
- История назначений каналов
- Health метрики
- Ручное управление статусом

### Pool Controls
- Добавление новых аккаунтов
- Настройка лимитов и приоритетов
- Ручная ребалансировка
- Emergency операции

## Критерии успешности

### Функциональные
- [ ] Автоматическое назначение каналов оптимальным пользователям
- [ ] Load balancing между 2+ аккаунтами
- [ ] Health monitoring всех аккаунтов
- [ ] Автоматический failover при проблемах
- [ ] Динамическая ребалансировка нагрузки

### Масштабирование
- [ ] Поддержка до 50 follower users
- [ ] Мониторинг до 20000 каналов
- [ ] Graceful degradation при проблемах
- [ ] Performance под нагрузкой

### Надежность
- [ ] Detection проблемных аккаунтов < 5 минут
- [ ] Automatic recovery attempts
- [ ] Manual override возможности
- [ ] Complete audit trail

## Риски и митигация

### 1. Cascading Failures
- **Риск**: Последовательные отказы нескольких аккаунтов
- **Митигация**: Early detection, резервные аккаунты, graceful degradation

### 2. Load Imbalance
- **Риск**: Неравномерное распределение нагрузки
- **Митигация**: Regular rebalancing, workload metrics, automatic triggers

### 3. Health Check Failures
- **Риск**: Ложные срабатывания health monitoring
- **Митигация**: Multiple health checks, threshold tuning, manual verification

### 4. Assignment Conflicts
- **Риск**: Конкурентное назначение каналов
- **Митигация**: Database transactions, locking mechanisms, retry logic

## Технические требования

### Performance
- Assignment latency: < 1 секунда
- Health check time: < 30 секунд
- Rebalancing time: < 5 минут
- Failover detection: < 5 минут

### Reliability
- 99.9% uptime для pool management
- Automatic recovery от временных сбоев
- Data consistency гарантируется
- Complete audit trail

### Scalability
- Горизонтальное масштабирование до 50 аккаунтов
- Линейная производительность при росте пула
- Эффективная работа при 20000+ каналах

---

## Статус: draft

Эта спецификация описывает pool management систему для FollowerUser аккаунтов и должна быть реализована после базовой FollowerUser модели и Channel Assignment логики.

**Связанные документы**:
- [046 User-based Channel Access](./046_Bot_Channel_Join_Process_Specification_Updated.md)
- [053 FollowerUser Lifecycle](./053_FollowerUser_Lifecycle_Specification.md)
- [054 Channel Activity System](./054_Channel_Activity_System_Specification.md)