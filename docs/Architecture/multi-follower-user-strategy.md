# Multi-Follower User Strategy - Архитектура масштабирования

## 🎯 Проблема

Один follower user имеет ограничения:
- **50 вступлений/день** (консервативно)
- **500 каналов максимум** (жесткий лимит Telegram)
- **Rate limits** при активной работе
- **Single point of failure** - блокировка остановит всю систему

Для мониторинга сотен каналов нужна распределенная система.

---

## 📊 Расчет необходимого количества аккаунтов

### Scenario 1: Консервативный подход
```yaml
target_channels: 1000
channels_per_account: 400 (с запасом до 500)
accounts_needed: 3
daily_joins_capacity: 3 × 50 = 150
daily_joins_required: 10-20 (новые каналы)
coverage: "Полное покрытие с запасом"
```

### Scenario 2: Агрессивный подход
```yaml
target_channels: 5000
channels_per_account: 450
accounts_needed: 12
daily_joins_capacity: 12 × 80 = 960
daily_joins_required: 50-100
coverage: "Масштабирование до 5000 каналов"
```

### Scenario 3: Enterprise подход
```yaml
target_channels: 20000
channels_per_account: 400
accounts_needed: 50
daily_joins_capacity: 50 × 120 = 6000
daily_joins_required: 200-500
coverage: "Корпоративный уровень"
```

---

## 🏗️ Архитектура Multi-Follower System

### 1. Структура данных

```ruby
# app/models/follower_user.rb
class FollowerUser < ApplicationRecord
  enum auth_status: { pending: 0, authorized: 1, restricted: 2, banned: 3 }
  enum workload_level: { light: 0, medium: 1, heavy: 2, overloaded: 3 }

  # Защищенные данные
  encrypts :session_string
  encrypts :phone_number
  encrypts :api_credentials

  # Rate limiting
  field :daily_joins_limit, default: 50
  field :daily_joins_count, default: 0
  field :last_reset_date, :date

  # Workload management
  field :assigned_channels_count, default: 0
  field :max_channels, default: 400
  field :workload_score, default: 0.0

  # Health metrics
  field :last_successful_join, :timestamp
  field :consecutive_errors, default: 0
  field :health_score, default: 100.0

  # Priority settings
  field :priority, default: 0  # 0=normal, 1=high, 2=critical
  field :specialization, :string  # "private", "public", "large", "test"

  validates :max_channels, numericality: { less_than_or_equal_to: 500 }
  validates :daily_joins_limit, numericality: { less_than_or_equal_to: 150 }

  def can_join_channel?
    return false unless authorized?
    return false if daily_joins_count >= daily_joins_limit
    return false if channels_count >= max_channels
    return false if consecutive_errors >= 5
    true
  end

  def calculate_workload_score
    active_channels_ratio = channels_count.to_f / max_channels
    daily_usage_ratio = daily_joins_count.to_f / daily_joins_limit
    error_penalty = consecutive_errors * 10

    self.workload_score = (active_channels_ratio * 0.5 + daily_usage_ratio * 0.3 + error_penalty * 0.2)
    save!
  end

  def health_status
    return :critical if health_score < 30 || consecutive_errors >= 5
    return :warning if health_score < 70 || consecutive_errors >= 3
    return :healthy
  end
end
```

### 2. Pool Management System

```ruby
# app/services/follower_users/pool_manager.rb
class FollowerUsers::PoolManager
  def self.assign_channel_to_user(channel)
    best_user = find_best_available_user(channel)
    return nil unless best_user

    assign_channel(best_user, channel)
  end

  def self.find_best_available_user(channel)
    available_users = FollowerUser.authorized.joins(:channels)
      .where('channels_count < max_channels')
      .where('daily_joins_count < daily_joins_limit')
      .where('consecutive_errors < 3')

    # Специализация под тип канала
    specialized = available_users.where(specialization: channel_type(channel))
    available_users = specialized if specialized.any?

    # Сортировка по workload score (чем ниже, тем лучше)
    available_users.order(:workload_score, :last_successful_join).first
  end

  def self.rebalance_workload
    users = FollowerUser.authorized.includes(:channels)

    users.each do |user|
      user.calculate_workload_score
      user.update!(workload_level: determine_workload_level(user.workload_score))
    end

    # Ребалансировка перегруженных аккаунтов
    overloaded = users.where(workload_level: :overloaded)
    redistribute_channels(overloaded) if overloaded.any?
  end

  def self.health_check_all
    FollowerUser.authorized.find_each do |user|
      check_user_health(user)
    end

    generate_health_report
  end

  private

  def self.channel_type(channel)
    case
    when channel.private? then 'private'
    when channel.subscribers_count > 10000 then 'large'
    when channel.testing? then 'test'
    else 'public'
    end
  end

  def self.determine_workload_level(score)
    case score
    when 0.0..0.3 then :light
    when 0.3..0.7 then :medium
    when 0.7..0.9 then :heavy
    else :overloaded
    end
  end
end
```

### 3. Channel Assignment Strategy

```ruby
# app/services/channels/channel_assignment_service.rb
class Channels::ChannelAssignmentService
  ASSIGNMENT_STRATEGIES = {
    round_robin: :assign_round_robin,
    least_loaded: :assign_least_loaded,
    specialized: :assign_specialized,
    priority_based: :assign_priority_based
  }.freeze

  def self.assign_channel(channel, strategy = :least_loaded)
    assignment_method = ASSIGNMENT_STRATEGIES[strategy]
    send(assignment_method, channel)
  end

  def self.assign_least_loaded(channel)
    # Находим аккаунт с наименьшей нагрузкой
    best_user = FollowerUser.authorized
      .where('channels_count < max_channels')
      .where('daily_joins_count < daily_joins_limit')
      .order(:workload_score)
      .first

    return error_result("No available follower users") unless best_user

    assign_to_user(best_user, channel)
  end

  def self.assign_specialized(channel)
    # Специализация под тип канала
    specialization = case channel.type
                   when 'private' then 'private'
                   when 'large_public' then 'large'
                   else 'public'
                   end

    specialized_users = FollowerUser.authorized
      .where(specialization: specialization)
      .where('channels_count < max_channels')
      .order(:workload_score)

    user = specialized_users.first || assign_least_loaded(channel)
    assign_to_user(user, channel) if user
  end

  def self.assign_priority_based(channel)
    # Приоритет для высокоприоритетных каналов
    if channel.priority == 'high'
      high_priority_users = FollowerUser.authorized
        .where(priority: [1, 2])  # high или critical
        .where('channels_count < max_channels * 0.8')  # резерв для важных
        .order(:workload_score)

      user = high_priority_users.first
      return assign_to_user(user, channel) if user
    end

    assign_least_loaded(channel)
  end

  private

  def self.assign_to_user(user, channel)
    ActiveRecord::Base.transaction do
      channel.update!(
        follower_user: user,
        assigned_at: Time.current,
        assignment_status: :assigned
      )

      user.increment!(:channels_count)
      user.calculate_workload_score

      # Запуск задачи вступления в канал
      Channels::ChannelJoinJob.perform_later(channel.id, user.id)
    end

    success_result("Channel assigned to #{user.phone_number}")
  end
end
```

### 4. Load Balancing System

```ruby
# app/services/follower_users/load_balancer.rb
class FollowerUsers::LoadBalancer
  REBALANCE_TRIGGERS = {
    workload_imbalance: 0.3,      # 30% разница в нагрузке
    failed_user_threshold: 3,     # 3 неудачных пользователя
    time_based_rebalance: 6.hours # Каждые 6 часов
  }.freeze

  def self.check_rebalance_needed?
    return true if workload_imbalance?
    return true if failed_users_count >= REBALANCE_TRIGGERS[:failed_user_threshold]
    return true if last_rebalance_more_than?(REBALANCE_TRIGGERS[:time_based_rebalance])

    false
  end

  def self.rebalance_workload
    return unless check_rebalance_needed?

    ActiveRecord::Base.transaction do
      # 1. Находим перегруженные и недогруженные аккаунты
      overloaded = find_overloaded_users
      underloaded = find_underloaded_users

      # 2. Выбираем каналы для переноса
      channels_to_move = select_channels_for_rebalance(overloaded)

      # 3. Перераспределяем каналы
      redistribute_channels(channels_to_move, underloaded)

      # 4. Обновляем метрики
      update_workload_metrics

      # 5. Логируем ребалансировку
      log_rebalance_operation(overloaded, underloaded, channels_to_move)
    end
  end

  private

  def self.workload_imbalance?
    users = FollowerUser.authorized
    return false if users.count < 2

    workloads = users.pluck(:workload_score)
    max_workload = workloads.max
    min_workload = workloads.min

    (max_workload - min_workload) > REBALANCE_TRIGGERS[:workload_imbalance]
  end

  def self.find_overloaded_users
    FollowerUser.authorized
      .where('workload_score > ?', 0.8)
      .order(workload_score: :desc)
  end

  def self.find_underloaded_users
    FollowerUser.authorized
      .where('workload_score < ?', 0.5)
      .where('channels_count < max_channels * 0.7')
      .order(workload_score: :asc)
  end

  def self.select_channels_for_rebalance(overloaded_users)
    # Выбираем каналы с низкой активностью для переноса
    channels = []
    overloaded_users.each do |user|
      user_channels = user.channels
        .where('last_activity_at < ?', 1.week.ago)
        .where(priority: 'normal')
        .limit(user.channels_count * 0.2)  # 20% каналов

      channels.concat(user_channels)
    end

    channels.shuffle
  end
end
```

---

## 📋 Database Schema Updates

### Migration для FollowerUser
```ruby
class CreateFollowerUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :follower_users do |t|
      # Basic info
      t.string :phone_number, null: false, index: { unique: true }
      t.string :username
      t.string :first_name
      t.string :last_name

      # Authentication
      t.enum :auth_status, default: :pending, null: false, index: true
      t.text :session_string_encrypted
      t.text :api_credentials_encrypted
      t.timestamp :last_authorized_at

      # Rate limiting
      t.integer :daily_joins_limit, default: 50, null: false
      t.integer :daily_joins_count, default: 0, null: false
      t.date :last_reset_date, default: -> { 'CURRENT_DATE' }

      # Channel capacity
      t.integer :max_channels, default: 400, null: false
      t.integer :channels_count, default: 0, null: false

      # Workload management
      t.decimal :workload_score, precision: 5, scale: 2, default: 0.0, index: true
      t.enum :workload_level, default: :light, null: false, index: true
      t.integer :priority, default: 0, null: false, index: true
      t.string :specialization

      # Health metrics
      t.decimal :health_score, precision: 5, scale: 2, default: 100.0
      t.integer :consecutive_errors, default: 0, null: false
      t.timestamp :last_successful_join
      t.timestamp :last_activity_at

      # Device info
      t.jsonb :device_info, default: {}
      t.string :device_fingerprint

      t.timestamps
    end

    add_index :follower_users, [:auth_status, :workload_level]
    add_index :follower_users, [:priority, :health_score]
    add_index :follower_users, :specialization
  end
end
```

### Update для Channel model
```ruby
class AddFollowerUserToChannels < ActiveRecord::Migration[8.0]
  def change
    add_reference :channels, :follower_user, null: true, foreign_key: true
    add_column :channels, :assigned_at, :timestamp
    add_column :channels, :assignment_status, :integer, default: 0
    add_column :channels, :last_activity_at, :timestamp
    add_column :channels, :activity_score, :decimal, precision: 5, scale: 2, default: 0.0

    add_index :channels, :assignment_status
    add_index :channels, [:follower_user_id, :assignment_status]
    add_index :channels, :last_activity_at
  end
end
```

---

## 🔄 Assignment Algorithms

### 1. Round Robin Assignment
```ruby
class RoundRobinAssigner
  def self.assign_next_channel(channel)
    @last_used_index ||= 0

    available_users = FollowerUser.authorized
      .where('channels_count < max_channels')
      .order(:id)

    return nil if available_users.empty?

    user = available_users[@last_used_index % available_users.count]
    @last_used_index += 1

    assign_channel_to_user(user, channel)
  end
end
```

### 2. Weighted Assignment (на основе производительности)
```ruby
class WeightedAssigner
  def self.assign_channel(channel)
    users = FollowerUser.authorized
      .where('channels_count < max_channels')
      .includes(:channels)

    # Вес на основе health score и success rate
    weights = users.map do |user|
      success_rate = calculate_success_rate(user)
      weight = user.health_score * success_rate
      [user, weight]
    end

    selected_user = weighted_random_select(weights)
    assign_channel_to_user(selected_user, channel)
  end

  private

  def self.calculate_success_rate(user)
    recent_joins = user.channel_joins.where('created_at > ?', 1.week.ago)
    return 1.0 if recent_joins.empty?

    successful = recent_joins.where(status: :success).count
    successful.to_f / recent_joins.count
  end
end
```

---

## 📊 Monitoring и Health Check

### Pool Health Dashboard
```ruby
# app/services/follower_users/pool_health_monitor.rb
class FollowerUsers::PoolHealthMonitor
  METRICS = [
    :total_users,
    :authorized_users,
    :healthy_users,
    :overloaded_users,
    :total_channels,
    :avg_workload_score,
    :pool_efficiency,
    :error_rate
  ].freeze

  def self.generate_health_report
    {
      summary: calculate_pool_summary,
      users: detailed_user_status,
      alerts: generate_alerts,
      recommendations: generate_recommendations,
      performance_metrics: calculate_performance_metrics
    }
  end

  private

  def self.calculate_pool_summary
    users = FollowerUser.all

    {
      total_accounts: users.count,
      authorized_accounts: users.authorized.count,
      healthy_accounts: users.where('health_score > 70').count,
      overloaded_accounts: users.where(workload_level: :overloaded).count,
      total_channels_assigned: users.sum(:channels_count),
      daily_capacity: users.sum(:daily_joins_limit),
      daily_usage: users.sum(:daily_joins_count),
      pool_efficiency: calculate_efficiency(users)
    }
  end

  def self.calculate_efficiency(users)
    return 0 if users.empty?

    total_capacity = users.sum { |u| u.max_channels }
    total_used = users.sum(:channels_count)

    (total_used.to_f / total_capacity * 100).round(2)
  end
end
```

---

## 🚨 Failover и Recovery

### Auto-failover System
```ruby
# app/services/follower_users/failover_manager.rb
class FollowerUsers::FailoverManager
  def self.handle_user_failure(follower_user, error)
    # 1. Маркируем пользователя как проблемный
    follower_user.increment!(:consecutive_errors)
    follower_user.update!(last_activity_at: Time.current)

    # 2. Если превышен порог - отзываем каналы
    if follower_user.consecutive_errors >= 5
      mark_user_unavailable(follower_user)
      reassign_user_channels(follower_user)
    end

    # 3. Алертим администраторов
    alert_user_failure(follower_user, error)
  end

  def self.reassign_user_channels(failed_user)
    channels = failed_user.channels.includes(:subscriptions)

    channels.find_each do |channel|
      # Назначаем каналу нового пользователя
      new_user = FollowerUsers::PoolManager.find_best_available_user(channel)

      if new_user
        reassign_channel(channel, failed_user, new_user)
      else
        # Нет доступных пользователей - ставим в очередь
        channel.update!(assignment_status: :pending_reassignment)
      end
    end
  end

  def self.attempt_user_recovery(follower_user)
    # Пытаемся восстановить через 24 часа
    return unless follower_user.last_activity_at < 24.hours.ago

    begin
      # Тестовая операция
      client = TelegramUserClient.new(follower_user)
      test_result = client.test_connection

      if test_result.success?
        follower_user.update!(
          auth_status: :authorized,
          consecutive_errors: 0,
          health_score: 100.0
        )

        notify_user_recovery(follower_user)
      end
    rescue => error
      follower_user.increment!(:consecutive_errors)
      Bugsnag.notify(error, metadata: { follower_user: follower_user.id })
    end
  end
end
```

---

## 💡 Рекомендации по имплементации

### Phase 1: Single User Foundation (Текущий план)
- Создать базовую модель FollowerUser
- Реализовать basic ChannelAccessService
- Тестирование с одним аккаунтом

### Phase 2: Multi-User Pool (Следующий этап)
- Расширить FollowerUser модель для multiple users
- Реализовать PoolManager
- Добавить Load Balancing

### Phase 3: Advanced Features (Масштабирование)
- Health Monitoring Dashboard
- Auto-failover System
- Specialization пользователей
- Performance Analytics

### Phase 4: Enterprise Features
- Dynamic pool scaling
- Advanced rebalancing algorithms
- Multi-region distribution
- Full automation

---

**🎯 Вывод**: Multi-follower user архитектура необходима для масштабирования до сотен и тысяч каналов. Начинать можно с одного пользователя, но сразу проектировать систему под multiple users - правильный подход.