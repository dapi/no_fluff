# Phase 2: Multi-User Pool (3 недели)

## 📋 Обзор Phase 2

Вторая фаза имплементации спецификации 046. Расширяем систему для поддержки пула FollowerUser аккаунтов с автоматическим load balancing.

**Цель Phase 2**: Масштабируемая система, поддерживающая до 50 follower users с автоматическим распределением нагрузки.

---

## 📊 Статус и Progress

**Статус**: planned
**Последнее обновление**: 2025-01-31
**Ответственный**: Данил Письменный
**Timeline**: 21 день
**Priority**: P1 (High)
**Dependencies**: Phase 1 completion
**Success Criteria**: Load balancing между 5+ пользователями работает

---

## 🎯 Предварительные условия

**Требуется завершение Phase 1:**
- ✅ FollowerUser модель и базовый функционал
- ✅ TelegramUserClient с работающим вступлением в каналы
- ✅ Background jobs инфраструктура
- ✅ Базовая обработка ошибок

---

## 🎯 Задачи Phase 2

### 1. Pool Manager Service
**Срок**: Неделя 1 (Дни 15-17)
**Зависимости**: Phase 1 completion

#### Задачи:
- [ ] Создать `app/services/follower_users/pool_manager.rb`
- [ ] Реализовать алгоритм выбора оптимального пользователя:
  ```ruby
  def self.find_best_available_user(channel)
    available_users = FollowerUser.authorized
      .where('channels_count < max_channels')
      .where('daily_joins_count < daily_joins_limit')
      .where('consecutive_errors < 3')
      .order(:workload_score)
  end
  ```
- [ ] Добавить специализацию под типы каналов
- [ ] Реализовать priority based assignment
- [ ] Добавить distributed locks для race condition prevention
- [ ] Написать unit тесты

#### Файлы для создания:
- `app/services/follower_users/pool_manager.rb`
- `app/services/follower_users/user_selector.rb`
- `lib/pool_lock_manager.rb`
- `test/services/follower_users/pool_manager_test.rb`

---

### 2. Channel Assignment Service
**Срок**: Неделя 1 (Дни 17-19)
**Зависимости**: Pool Manager

#### Задачи:
- [ ] Расширить `app/services/channels/channel_assignment_service.rb`
- [ ] Реализовать multi-user assignment логику
- [ ] Добавить разные стратегии assignment:
  - least_loaded
  - specialized
  - priority_based
  - round_robin
- [ ] Реализовать автоматическую оптимизацию
- [ ] Добавить batch assignment для множественных каналов
- [ ] Написать интеграционные тесты

#### Файлы для создания:
- `app/services/channels/channel_assignment_service.rb`
- `app/services/channels/assignment_strategies/`
- `test/services/channels/channel_assignment_service_test.rb`

---

### 3. Load Balancer Service
**Срок**: Неделя 2 (Дни 20-22)
**Зависимости**: Channel Assignment

#### Задачи:
- [ ] Создать `app/services/follower_users/load_balancer.rb`
- [ ] Реализовать детекцию дисбаланса нагрузки
- [ ] Создать алгоритмы ребалансировки
- [ ] Реализовать trigger-based rebalancing
- [ ] Добавить manual rebalancing controls
- [ ] Создать rebalancing background jobs
- [ ] Написать тесты для балансировки

#### Файлы для создания:
- `app/services/follower_users/load_balancer.rb`
- `app/services/follower_users/rebalancing_service.rb`
- `app/jobs/follower_users/rebalance_pool_job.rb`
- `test/services/follower_users/load_balancer_test.rb`

---

### 4. Health Monitoring
**Срок**: Неделя 2 (Дни 22-24)
**Зависимости**: Load Balancer

#### Задачи:
- [ ] Расширить `app/services/follower_users/health_monitor.rb`
- [ ] Создать comprehensive health checks:
  - Telegram connection
  - Session validity
  - Rate limit status
  - Device compatibility
- [ ] Реализовать automatic health scoring
- [ ] Создать систему алертов
- [ ] Добавить health dashboard data collection
- [ ] Создать periodic health check jobs
- [ ] Написать health monitoring тесты

#### Файлы для создания:
- `app/services/follower_users/health_monitor.rb`
- `app/services/follower_users/health_check_service.rb`
- `app/jobs/follower_users/health_check_job.rb`
- `test/services/follower_users/health_monitor_test.rb`

---

### 5. Failover Manager
**Срок**: Неделя 3 (Дни 25-27)
**Зависимости**: Health Monitoring

#### Задачи:
- [ ] Создать `app/services/follower_users/failover_manager.rb`
- [ ] Реализовать детекцию проблемных пользователей
- [ ] Создать automatic channel reassignment
- [ ] Реализовать recovery механизмы
- [ ] Добавить manual override возможности
- [ ] Создать failover notification систему
- [ ] Написать failover тесты

#### Файлы для создания:
- `app/services/follower_users/failover_manager.rb`
- `app/services/follower_users/recovery_service.rb`
- `app/services/follower_users/failover_notifier.rb`
- `test/services/follower_users/failover_manager_test.rb`

---

### 6. Enhanced Background Jobs
**Срок**: Неделя 3 (Дни 27-29)
**Зависимости**: Failover Manager

#### Задачи:
- [ ] Обновить существующие jobs для multi-user поддержки
- [ ] Создать `app/jobs/channels/pool_channel_join_job.rb`
- [ ] Создать `app/jobs/follower_users/pool_maintenance_job.rb`
- [ ] Создать `app/jobs/follower_users/workload_optimization_job.rb`
- [ ] Добавить job priority management
- [ ] Реализовать job rate limiting
- [ ] Обновить `config/queue.yml` для новых очередей

#### Файлы для создания:
- `app/jobs/channels/pool_channel_join_job.rb`
- `app/jobs/follower_users/pool_maintenance_job.rb`
- `config/queue.yml` (обновить)
- `test/jobs/channels/pool_channel_join_job_test.rb`

---

### 7. Multi-User Testing
**Срок**: Неделя 3 (Дни 29-35)
**Зависимости**: Enhanced Background Jobs

#### Задачи:
- [ ] Создать 2-3 тестовых follower users
- [ ] Протестировать load balancing алгоритмы
- [ ] Тестировать failover сценарии
- [ ] Проверить performance под нагрузкой
- [ ] Создать load testing suite
- [ ] Провести stress testing
- [ ] Демонстрация multi-user работы

#### Тесты для создания:
- `test/integration/multi_user_pool_test.rb`
- `test/system/load_balancing_test.rb`
- `test/performance/pool_performance_test.rb`
- `test/integration/failover_scenarios_test.rb`

---

## 🧪 Тестирование Strategy для Phase 2

### Pool Management Tests
```ruby
# test/services/follower_users/pool_manager_test.rb
class PoolManagerTest < ActiveSupport::TestCase
  test "find_best_available_user selects least loaded user" do
    users = create_list(:follower_user, 3, :authorized)
    users[0].update!(channels_count: 50)
    users[1].update!(channels_count: 100)
    users[2].update!(channels_count: 25)

    best_user = PoolManager.find_best_available_user(create(:channel))
    assert_equal users[2], best_user
  end

  test "excludes users with consecutive errors" do
    good_user = create(:follower_user, :authorized, consecutive_errors: 0)
    bad_user = create(:follower_user, :authorized, consecutive_errors: 5)

    available = PoolManager.available_users
    assert_includes available, good_user
    assert_not_includes available, bad_user
  end
end
```

### Load Balancing Tests
```ruby
# test/integration/load_balancing_test.rb
class LoadBalancingTest < ActionDispatch::IntegrationTest
  test "distributes channels evenly across users" do
    users = create_list(:follower_user, 3, :authorized)
    channels = create_list(:channel, 15)

    # Assign all channels
    channels.each { |channel| ChannelAssignmentService.assign_channel(channel) }

    # Verify distribution
    user_channels = users.map { |u| u.channels.count }
    assert user_channels.max - user_channels.min < 2
  end
end
```

### Failover Tests
```ruby
# test/integration/failover_scenarios_test.rb
class FailoverScenariosTest < ActionDispatch::IntegrationTest
  test "reassigns channels when user becomes unhealthy" do
    primary_user = create(:follower_user, :authorized)
    backup_user = create(:follower_user, :authorized)
    channels = create_list(:channel, 5, follower_user: primary_user)

    # Simulate user failure
    primary_user.update!(consecutive_errors: 10, health_score: 0.0)

    # Trigger failover
    FailoverManager.handle_user_failure(primary_user)

    # Verify reassignment
    primary_user.reload
    backup_user.reload
    assert_equal 0, primary_user.channels.count
    assert_equal 5, backup_user.channels.count
  end
end
```

---

## 📊 Success Metrics для Phase 2

### Technical Metrics
- [ ] **Channel join success rate**: > 95%
- [ ] **Load balancing efficiency**: > 90%
- [ ] **Failover response time**: < 30 секунд
- [ ] **Pool health coverage**: 100%
- [ ] **Test coverage**: > 90%

### Business Metrics
- [ ] **Supports 5+ follower users**
- [ ] **Monitors 1000+ channels**
- [ ] **System uptime**: > 99.5%
- [ ] **Admin intervention reduction**: > 70%

### Performance Metrics
- [ ] **Assignment time**: < 2 секунды
- [ ] **Pool rebalancing time**: < 5 минут
- [ ] **Concurrent channel joins**: 50+
- [ ] **Failover time**: < 1 минута

---

## 🎯 Definition of Done для Phase 2

### Requirements:
- [ ] Load balancing работает между 5+ пользователями
- [ ] Health monitoring функционален
- [ ] Failover работает автоматически
- [ ] Система выдерживает 1000+ каналов
- [ ] Все тесты проходят
- [ ] Performance benchmarks достигнуты

### Demo Requirements:
- [ ] Создать 5 follower users
- [ ] Добавить 100+ каналов
- [ ] Показать равномерное распределение
- [ ] Демонстрировать failover
- [ ] Показать health monitoring

---

## 📋 Dependencies для Phase 3

**Что должно быть готово:**
- ✅ Pool Manager с load balancing
- ✅ Health monitoring система
- ✅ Failover механизмы
- ✅ Multi-user background jobs
- ✅ Comprehensive testing framework

**Следующий шаг**: После завершения Phase 2 можно начинать Phase 3: Advanced Features.

---

## 🚀 Rollout Instructions

### Week 1: Pool Management
1. Создать Pool Manager
2. Реализовать assignment стратегии
3. Тестировать с 2-3 пользователями

### Week 2: Health & Failover
1. Добавить health monitoring
2. Реализовать failover
3. Тестировать сценарии отказов

### Week 3: Load Testing
1. Создать 5+ пользователей
2. Добавить 100+ каналов
3. Провести load testing
4. Оптимизировать performance

---

## ⚠️ Риски и митигация

### High Risk:
1. **Race conditions в assignment**
   - **Mitigation**: Distributed locks with Redis
   - **Backup**: Retry mechanisms with exponential backoff

2. **Load balancing algorithm complexity**
   - **Mitigation**: Start with simple algorithms
   - **Backup**: Manual override capabilities

### Medium Risk:
1. **Health check accuracy**
   - **Mitigation**: Multiple health indicators
   - **Backup**: Manual health status updates

---

**📍 Status**: Ready for implementation after Phase 1
**🎯 Target**: Multi-user pool with load balancing
**📅 Duration**: 21 days
**👤 Owner**: Данил Письменный