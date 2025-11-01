# Implementation Plan: Spec 046 - User-based Channel Access System

## 📋 Обзор плана

⚠️ **ВНИМАНИЕ**: Этот план разбит на отдельные файлы для каждого этапа.

**Новая структура:**
- **Master Plan**: [Spec_046_Master_Plan.md](./Spec_046_Master_Plan.md) - общий обзор и dependencies
- **Phase 1**: [Spec_046_Phase_1_Foundation_Setup.md](./Spec_046_Phase_1_Foundation_Setup.md) - 2 недели, базовая инфраструктура
- **Phase 2**: [Spec_046_Phase_2_Multi_User_Pool.md](./Spec_046_Phase_2_Multi_User_Pool.md) - 3 недели, multi-user pool
- **Phase 3**: [Spec_046_Phase_3_Advanced_Features.md](./Spec_046_Phase_3_Advanced_Features.md) - 3 недели, продвинутые функции

**Рекомендация**: Используйте отдельные файлы этапов для имплементации. Этот файл оставлен для исторических целей.

---

## 🎯 Phase 1: Foundation Setup (Недели 1-2)

### Цель Phase 1
Создать базовую инфраструктуру для работы с одним follower user, подготовить основу для будущей multi-user системы.

### Задачи и чекбоксы:

#### 1.1 Database Schema Changes
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

#### 1.2 Telegram App API Setup
- [ ] Зарегистрировать приложение на https://my.telegram.org
- [ ] Получить api_id и api_hash
- [ ] Создать follower user Telegram аккаунт
- [ ] Сохранить credentials в encrypted виде
- [ ] Создать documentation по настройке

#### 1.3 MTProto Library Integration
- [ ] Исследовать доступные MTProto библиотеки для Ruby
  - telegram-rb
  - tdlib-ruby
  - pyrogram (через Python bridge)
- [ ] Выбрать наиболее подходящую библиотеку
- [ ] Создать gemfile запись
- [ ] Установить и настроить библиотеку
- [ ] Создать базовый TelegramUserClient wrapper

#### 1.4 Basic TelegramUserClient Service
- [ ] Создать `app/services/telegram/user_client.rb`
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
- [ ] Интегрировать с session management
- [ ] Написать unit тесты

#### 1.5 Basic Channel Access Service
- [ ] Создать `app/services/channels/channel_access_service.rb`
- [ ] Реализовать базовое вступление в канал:
  ```ruby
  def self.join_channel(channel)
    follower_user = FollowerUser.authorized.first
    return error_result("No authorized follower user") unless follower_user

    client = TelegramUserClient.new(follower_user)
    result = client.join_channel(channel.username)

    # Update channel status based on result
  end
  ```
- [ ] Добавить обработку различных статусов
- [ ] Реализовать notification систему
- [ ] Написать unit тесты

#### 1.6 Background Jobs
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

#### 1.7 Error Handling and Notifications
- [ ] Создать `app/services/channels/error_handler.rb`
- [ ] Реализовать обработку FLOOD_WAIT ошибок
- [ ] Создать систему уведомлений администраторов
- [ ] Интегрировать с Bugsnag
- [ ] Добавить логирование всех операций
- [ ] Написать тесты на error handling

#### 1.8 Initial Testing
- [ ] Создать тестовый follower user
- [ ] Написать интеграционные тесты для вступления в канал
- [ ] Протестировать с реальными Telegram API
- [ ] Проверить rate limiting поведение
- [ ] Тестировать обработку ошибок
- [ ] Демонстрация работы системы

---

## 🎯 Phase 2: Multi-User Pool (Недели 3-5)

### Цель Phase 2
Расширить систему для поддержки пула FollowerUser аккаунтов с автоматическим load balancing.

### Задачи и чекбоксы:

#### 2.1 Pool Manager Service
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
- [ ] Написать unit тесты

#### 2.2 Channel Assignment Service
- [ ] Расширить `app/services/channels/channel_assignment_service.rb`
- [ ] Реализовать multi-user assignment логику
- [ ] Добавить разные стратегии assignment:
  - least_loaded
  - specialized
  - priority_based
  - round_robin
- [ ] Реализовать автоматическую оптимизацию
- [ ] Написать интеграционные тесты

#### 2.3 Load Balancer Service
- [ ] Создать `app/services/follower_users/load_balancer.rb`
- [ ] Реализовать детекцию дисбаланса нагрузки
- [ ] Создать алгоритмы ребалансировки
- [ ] Реализовать trigger-based rebalancing
- [ ] Добавить manual rebalancing controls
- [ ] Написать тесты для балансировки

#### 2.4 Health Monitoring
- [ ] Расширить `app/services/follower_users/health_monitor.rb`
- [ ] Создать comprehensive health checks:
  - Telegram connection
  - Session validity
  - Rate limit status
  - Device compatibility
- [ ] Реализовать automatic health scoring
- [ ] Создать систему алертов
- [ ] Добавить health dashboard data collection
- [ ] Написать health monitoring тесты

#### 2.5 Failover Manager
- [ ] Создать `app/services/follower_users/failover_manager.rb`
- [ ] Реализовать детекцию проблемных пользователей
- [ ] Создать automatic channel reassignment
- [ ] Реализовать recovery механизмы
- [ ] Добавить manual override возможности
- [ ] Написать failover тесты

#### 2.6 Multi-User Testing
- [ ] Создать 2-3 тестовых follower users
- [ ] Протестировать load balancing алгоритмы
- [ ] Тестировать failover сценарии
- [ ] Проверить performance под нагрузкой
- [ ] Демонстрация multi-user работы

---

## 🎯 Phase 3: Advanced Features (Недели 6-8)

### Цель Phase 3
Добавить продвинутые функции: activity scoring, автоматизированное обслуживание, admin интерфейс.

### Задачи и чекбоксы:

#### 3.1 Activity Score System
- [ ] Создать `app/services/channels/activity_calculator.rb`
- [ ] Реализовать расчет activity score (0.0-1.0):
  ```ruby
  def self.calculate_activity_score(channel)
    post_frequency = calculate_post_frequency(channel)
    recency_score = calculate_recency_score(channel)
    engagement_score = calculate_engagement_score(channel)
    relevance_score = calculate_content_relevance(channel)

    activity_score = (
      post_frequency * 0.3 +
      recency_score * 0.25 +
      engagement_score * 0.25 +
      relevance_score * 0.2
    ).round(2)
  end
  ```
- [ ] Реализовать автоматическое обновление activity score
- [ ] Добавить AI-powered content relevance
- [ ] Создать batch processing для обновления
- [ ] Написать activity scoring тесты

#### 3.2 Activity-Aware Assignment
- [ ] Расширить assignment service с учетом activity
- [ ] Реализовать activity weight системы
- [ ] Создать алгоритмы для оптимального распределения активных каналов
- [ ] Тестировать activity-aware load balancing
- [ ] Оптимизировать performance под высокие нагрузки

#### 3.3 Admin Dashboard
- [ ] Создать `app/controllers/admin/follower_users_controller.rb`
- [ ] Создать Admin views для управления пулом:
  - Pool overview dashboard
  - Individual user management
  - Health monitoring interface
  - Manual rebalancing controls
- [ ] Реализовать AJAX обновления для real-time данных
- [ ] Добавить charts и графики
- [ ] Создать admin routing и navigation
- [ ] Написать feature тесты для admin interface

#### 3.4 Automated Maintenance
- [ ] Создать `app/services/follower_users/maintenance_service.rb`
- [ ] Реализовать ежедневные задачи:
  - Reset daily counters
  - Update health metrics
  - Check authorization expiry
- [ ] Создать еженедельные задачи:
  - Session rotation
  - Cleanup inactive channels
  - Performance reporting
- [ ] Создать месячные задачи:
  - Security audit
  - Compliance checking
  - Capacity planning
- [ ] Написать maintenance тесты

#### 3.5 Security Enhancements
- [ ] Создать `app/services/follower_users/security_monitor.rb`
- [ ] Реализовать security checks:
  - Suspicious activity patterns
  - Session anomaly detection
  - Device fingerprint verification
- [ ] Создать automated security scanning
- [ ] Добавить security incident reporting
- [ ] Написать security тесты

#### 3.6 Performance Optimization
- [ ] Оптимизировать запросы к базе данных
- [ ] Добавить кеширование для частых операций
- [ ] Реализовать batch operations
- [ ] Оптимизировать background job performance
- [ ] Добавить performance monitoring
- [ ] Провести load testing
- [ ] Создать performance бенчмарки

#### 3.7 Final Testing and Documentation
- [ ] Провести полное end-to-end тестирование
- [ ] Создать load тесты для 10000+ каналов
- [ ] Тестировать отказоустойчивость системы
- [ ] Написать пользовательскую документацию
- [ ] Создать operational runbooks
- [ ] Подготовить демо для стейкхолдеров

---

## 🧪 Тестирование Strategy

### Unit Tests
```ruby
# app/test/models/follower_user_test.rb
class FollowerUserTest < ActiveSupport::TestCase
  test "can_join_channel? returns false when daily limit reached" do
    user = create(:follower_user, daily_joins_count: 50, daily_joins_limit: 50)
    assert_not user.can_join_channel?
  end

  test "workload_score calculation" do
    user = create(:follower_user, channels_count: 200, max_channels: 400)
    assert_equal 0.5, user.calculate_workload_score
  end
end
```

### Integration Tests
```ruby
# test/integration/channel_join_test.rb
class ChannelJoinTest < ActionDispatch::IntegrationTest
  test "full channel join workflow" do
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
  end
end
```

### System Tests
```ruby
# test/system/multi_user_pool_test.rb
class MultiUserPoolTest < ApplicationSystemTestCase
  test "load balancing distributes channels evenly" do
    users = create_list(:follower_user, 3, :authorized)
    channels = create_list(:channel, 15)

    # Assign all channels
    channels.each { |channel| Channels::ChannelAssignmentService.assign_channel(channel) }

    # Verify distribution
    user_channels = users.map { |u| u.channels.count }
    assert user_channels.max - user_channels.min < 2
  end
end
```

---

## 📊 Success Metrics

### Technical Metrics
- **Channel join success rate**: > 95%
- **System uptime**: > 99.9%
- **API response time**: < 2 seconds
- **Background job success rate**: > 98%
- **Test coverage**: > 90%

### Business Metrics
- **Time-to-monitor new channels**: < 5 минут
- **Admin intervention reduction**: 80%
- **Channel coverage**: 200% increase
- **System reliability**: < 1% downtime

### Performance Metrics
- **Supports**: 50 follower users
- **Monitors**: 20000 channels
- **Throughput**: 1500+ joins/day
- **Response time**: < 1 секунда for assignment

---

## ⚠️ Risks and Mitigations

### High Risk Items
1. **Telegram API Changes**
   - **Mitigation**: Use stable libraries, monitor for breaking changes
   - **Plan B**: Multiple library fallback options

2. **Account Blocking**
   - **Mitigation**: Conservative rate limits, user pool distribution
   - **Plan B**: Manual intervention procedures

3. **Session Management Complexity**
   - **Mitigation**: Automated rotation, comprehensive logging
   - **Plan B**: Manual session recovery procedures

### Medium Risk Items
1. **Load Balancing Algorithm Complexity**
   - **Mitigation**: Simple initial algorithms, gradual enhancement
   - **Plan B**: Manual override capabilities

2. **Activity Score Accuracy**
   - **Mitigation**: Multiple data sources, AI validation
   - **Plan B**: Manual adjustment capabilities

---

## 📅 Dependencies

### External Dependencies
- **Telegram App API**: api_id, api_hash
- **Follower User Accounts**: Multiple phone numbers
- **MTProto Library**: telegram-rb or equivalent

### Internal Dependencies
- **Rails 8.0+**: Web framework
- **Solid Queue**: Background job processing
- **PostgreSQL**: Database with encryption support
- **Redis**: Caching and session storage

### Gem Dependencies
```ruby
# Gemfile additions
gem 'telegram-rb'  # или другая MTProto библиотека
gem 'aws-sdk-sns' # для уведомлений
gem 'rollout'   # для аналитики
gem 'gruff'     # для code quality
```

---

## 🚀 Rollout Plan

### Week 1-2: Foundation
- [ ] Database migrations
- [ ] Basic FollowerUser functionality
- [ ] Initial testing

### Week 3-5: Multi-User Pool
- [ ] Pool management services
- [ ] Load balancing
- [ ] Multi-user testing

### Week 6-8: Advanced Features
- [ ] Activity scoring
- [ ] Admin dashboard
- [ ] Performance optimization
- [ ] Full system testing

### Post-Launch
- [ ] Monitor system health
- [ ] Optimize based on usage patterns
- [ ] Scale up user pool as needed

---

## 📝 Documentation Deliverables

1. **Technical Documentation**
   - API documentation
   - Architecture diagrams
   - Deployment guides

2. **User Documentation**
   - Admin manual
   - Troubleshooting guide
   - FAQ

3. **Operational Documentation**
   - Runbooks
   - Monitoring procedures
   - Emergency procedures

---

## 📈 Timeline Summary

| Phase | Duration | Key Deliverables | Success Criteria |
|-------|----------|------------------|------------------|
| **Phase 1** | 2 недели | Basic FollowerUser system | Single user working |
| **Phase 2** | 3 недели | Multi-user pool management | Load balancing working |
| **Phase 3** | 3 недели | Advanced features | Full functionality |

**Total Timeline**: 8 недель

---

**Next Step**: Обсуждение плана с командой, уточнение приоритетов и получение обратной связи по предложенному подходу.