# Спецификация 054: Channel Activity System

## Мета информация

- **Номер:** 054
- **Название:** Channel Activity System
- **Автор:**
- **Создана:** 2025-01-15
- **Статус:** draft
- **Связанные спецификации:**

## 1. Обзор и цель

### 1.1. Краткое описание
Спецификация описывает систему мониторинга и анализа активности каналов для оптимизации распределения нагрузки между FollowerUser аккаунтами. Включает Activity Score расчет, метрики вовлеченности, rebalancing на основе активности и очистку неактивных каналов.

### 1.2. Цель
Создать умную систему распределения нагрузки на основе реальной активности каналов для повышения эффективности использования аккаунтов.

### 1.3. Затрагиваемые компоненты
- Channel модель
- FollowerUser система
- Assignment логика
- Monitoring dashboard

## 2. Требования

### 2.1. Функциональные требования
- Расчет Activity Score для каналов
- Автоматическая ребалансировка
- Мониторинг активности
- Очистка неактивных каналов

### 2.2. Нефункциональные требования
- Высокая производительность расчетов
- Минимальная нагрузка на систему
- Точность метрик

### 2.3. Ограничения и допущения
- Ограничение по API запросам
- Погрешность в расчетах

## 3. Пользовательские сценарии

### 3.1. Основные сценарии
- Расчет активности каналов
- Ребалансировка нагрузки
- Мониторинг системы

### 3.2. Альтернативные сценарии
- Ручное управление балансировкой
- Коррекция Activity Score

### 3.3. Пользовательский интерфейс
- Admin dashboard
- Графики активности
- Управление порогами

## 4. Техническая реализация

### 4.1. Архитектурные изменения
- Новые сервисы для расчетов
- Изменение Assignment логики
- Background задачи

### 4.2. Модели данных
- Activity score поля
- Новые таблицы для метрик

### 4.3. API эндпоинты
- Эндпоинты для управления активностью
- Статистические API

### 4.4. Интеграции
- Внешние сервисы аналитики
- Системы мониторинга

## 5. Тестирование

### 5.1. Требования к тестированию
- Unit тесты для расчетов
- Integration тесты
- Performance тесты

### 5.2. Тестовые данные
- Тестовые каналы
- Исторические данные

### 5.3. Критерии приемки
- Точность расчетов > 90%
- Производительность < 5 минут

## 6. Риски и зависимости

### 6.1. Технические риски
- Неправильные расчеты активности
- Проблемы с производительностью

### 6.2. Бизнес риски
- Неэффективное распределение
- Потеря данных

### 6.3. Зависимости
- Базовая Channel модель
- FollowerUser система

## 7. Внедрение

### 7.1. Этапы внедрения
- Пилот на малой группе
- Постепенное расширение
- Мониторинг результатов

### 7.2. Требования к миграции
- Backfill данных активности
- Расчет начальных score

### 7.3. Откат изменений
- Сохранение старой логики
- Возможность быстрого отката

## Обзор

Спецификация описывает систему мониторинга и анализа активности каналов для оптимизации распределения нагрузки между FollowerUser аккаунтами. Включает Activity Score расчет, метрики вовлеченности, rebalancing на основе активности и очистку неактивных каналов.

## Проблема

Каналы имеют разную активность:
- Некоторые очень активные (30+ постов в день)
- Другие почти неактивные (1 пост в неделю)
- Неравномерная нагрузка на аккаунты
- Неэффективное использование ресурсов

## Решение

Activity Score система для умного распределения:
- Расчет активности каналов (0.0-1.0)
- Load balancing на основе активности
- Автоматическая ребалансировка
- Cleanup неактивных каналов

## Activity Score Метрика

### Компоненты Activity Score
```yaml
activity_score_components:
  post_frequency:        # Частота постов (30%)
    weight: 0.3
    calculation: "posts_per_day / 30.0"
    max_value: 1.0

  recency_score:          # Актуальность (25%)
    weight: 0.25
    calculation: |
      hours_ago = time_since_last_post
      case hours_ago
      when 0..6      then 1.0    # Last 6 hours
      when 6..24     then 0.8    # Last day
      when 24..72    then 0.5    # Last 3 days
      when 72..168   then 0.2    # Last week
      else                0.0    # Older than week
      end

  engagement_rate:       # Вовлеченность (25%)
    weight: 0.25
    calculation: "avg_views_per_post / expected_views"
    normalization: "min(value, 1.0)"

  content_relevance:     # Релевантность для NoFluff (20%)
    weight: 0.2
    calculation: "ai_relevance_score"
    source: "LLM analysis"
```

### Activity Score Calculator
```ruby
class Channels::ActivityCalculator
  RECALCULATION_INTERVAL = 6.hours
  MIN_POSTS_FOR_RELIABLE_SCORE = 3

  def self.calculate_activity_score(channel)
    return 0.0 unless has_enough_data?(channel)

    components = {
      post_frequency: calculate_post_frequency(channel),
      recency_score: calculate_recency_score(channel),
      engagement_score: calculate_engagement_score(channel),
      relevance_score: calculate_content_relevance(channel)
    }

    activity_score = weighted_score(components)

    # Update channel with new score
    channel.update!(
      activity_score: activity_score,
      last_activity_calculation: Time.current,
      activity_components: components
    )

    log_activity_calculation(channel, components, activity_score)
    activity_score
  end

  def self.batch_update_activity_scores
    Channel.find_each do |channel|
      calculate_activity_score(channel)
    end
  end

  private

  def self.calculate_post_frequency(channel)
    # Posts per day in last week
    posts_count = channel.posts.where('created_at > ?', 7.days.ago).count
    posts_per_day = posts_count / 7.0

    # Normalize to 0-1 scale (30 posts per day = 1.0)
    [posts_per_day / 30.0, 1.0].min
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

  def self.calculate_engagement_score(channel)
    recent_posts = channel.posts.where('created_at > ?', 7.days.ago)
    return 0.5 if recent_posts.empty?

    total_views = recent_posts.sum(:views_count)
    total_reactions = recent_posts.sum(:reactions_count)
    avg_posts = recent_posts.count

    # Calculate engagement metrics
    avg_views_per_post = total_views.to_f / avg_posts
    avg_reactions_per_post = total_reactions.to_f / avg_posts

    # Normalize based on channel size expectations
    expected_views = calculate_expected_views(channel)
    expected_reactions = expected_views * 0.05  # 5% reaction rate

    views_score = [avg_views_per_post / expected_views, 1.0].min
    reactions_score = [avg_reactions_per_post / expected_reactions, 1.0].min

    (views_score * 0.7 + reactions_score * 0.3).round(2)
  end

  def self.calculate_content_relevance(channel)
    # AI-powered content relevance analysis
    recent_posts = channel.posts.where('created_at > ?', 7.days.ago).limit(10)
    return 0.5 if recent_posts.empty?

    relevance_scores = recent_posts.map do |post|
      ContentRelevanceService.analyze_relevance(post.content)
    end

    relevance_scores.sum / relevance_scores.length
  end

  def self.weighted_score(components)
    (components[:post_frequency] * 0.3 +
     components[:recency_score] * 0.25 +
     components[:engagement_score] * 0.25 +
     components[:relevance_score] * 0.2).round(2)
  end

  def self.has_enough_data?(channel)
    channel.posts.count >= MIN_POSTS_FOR_RELIABLE_SCORE
  end
end
```

## Load Balancing на основе Activity

### Activity-Aware Assignment
```ruby
class Channels::ActivityAwareAssignmentService
  ACTIVITY_WEIGHTS = {
    very_high: 3.0,   # 0.8-1.0 activity
    high: 2.0,        # 0.6-0.8 activity
    medium: 1.0,      # 0.3-0.6 activity
    low: 0.5,         # 0.1-0.3 activity
    very_low: 0.2     # 0.0-0.1 activity
  }.freeze

  def self.assign_channel_with_activity_awareness(channel)
    activity_category = categorize_activity(channel.activity_score)
    activity_weight = ACTIVITY_WEIGHTS[activity_category]

    # Find user with capacity for this activity level
    best_user = find_user_for_activity(channel, activity_weight)

    if best_user
      Channels::ChannelAssignmentService.assign_to_user(best_user, channel)
    else
      handle_no_suitable_user(channel, activity_category)
    end
  end

  private

  def self.find_user_for_activity(channel, activity_weight)
    available_users = FollowerUser.authorized
      .where('channels_count < max_channels_for_activity(activity_weight)')
      .where('consecutive_errors < 3')
      .order(:workload_score)

    # Prioritize users with similar activity channels
    users_with_similar_activity = available_users.joins(:channels)
      .where('channels.activity_score BETWEEN ? AND ?',
        channel.activity_score - 0.2, channel.activity_score + 0.2)

    users_with_similar_activity.any? ? users_with_similar_activity.first : available_users.first
  end

  def self.max_channels_for_activity(activity_weight)
    base_capacity = 400
    (base_capacity / activity_weight).to_i
  end

  def self.categorize_activity(score)
    case score
    when 0.8..1.0 then :very_high
    when 0.6..0.8 then :high
    when 0.3..0.6 then :medium
    when 0.1..0.3 then :low
    else :very_low
    end
  end
end
```

### Activity-Based Rebalancing
```ruby
class Channels::ActivityRebalancer
  REBALANCE_TRIGGERS = {
    activity_imbalance: 0.4,         # 40% разница в активности
    user_overload: 0.8,              # 80% max channels
    inactivity_threshold: 0.1,       # Activity score < 0.1
    rebalance_interval: 12.hours     # Каждые 12 часов
  }.freeze

  def self.check_rebalance_needed?
    return true if activity_imbalance_detected?
    return true if user_overload_detected?
    return true if many_inactive_channels?
    return true if last_rebalance_more_than?(REBALANCE_TRIGGERS[:rebalance_interval])

    false
  end

  def self.rebalance_based_on_activity
    return unless check_rebalance_needed?

    ActiveRecord::Base.transaction do
      # Step 1: Identify rebalancing opportunities
      rebalance_ops = find_rebalancing_opportunities

      # Step 2: Execute rebalancing operations
      rebalance_ops.each do |operation|
        execute_rebalance_operation(operation)
      end

      # Step 3: Update metrics
      update_activity_metrics

      # Step 4: Log results
      log_rebalance_results(rebalance_ops)
    end
  end

  private

  def self.find_rebalancing_opportunities
    opportunities = []

    # Find users with high-activity concentration
    overloaded_users = find_users_with_activity_imbalance
    overloaded_users.each do |user|
      channels_to_move = select_channels_for_rebalancing(user)
      opportunities.concat(channels_to_move.map { |ch| { type: :move_channel, from: user, channel: ch } })
    end

    # Find inactive channels to clean up
    inactive_channels = find_inactive_channels
    inactive_channels.each do |channel|
      opportunities << { type: :cleanup_inactive, channel: channel }
    end

    opportunities
  end

  def self.find_users_with_activity_imbalance
    FollowerUser.authorized.joins(:channels)
      .group('follower_users.id')
      .having('AVG(channels.activity_score) > ?', 0.7)
      .having('COUNT(channels.id) > ?', follower_users.max_channels * 0.8)
  end

  def self.select_channels_for_rebalancing(user)
    # Prefer to move lower-activity channels first
    user.channels.order(:activity_score).limit(user.channels_count * 0.2)
  end

  def self.find_inactive_channels
    Channel.where('activity_score < ? AND last_activity_at < ?',
                  REBALANCE_TRIGGERS[:inactivity_threshold],
                  30.days.ago)
  end

  def self.execute_rebalance_operation(operation)
    case operation[:type]
    when :move_channel
      move_channel_to_better_user(operation[:channel])
    when :cleanup_inactive
      cleanup_inactive_channel(operation[:channel])
    end
  end

  def self.move_channel_to_better_user(channel)
    new_user = Channels::ActivityAwareAssignmentService.find_user_for_activity(
      channel, Channels::ActivityAwareAssignmentService::ACTIVITY_WEIGHTS[
        Channels::ActivityAwareAssignmentService.categorize_activity(channel.activity_score)
      ]
    )

    if new_user
      # Remove from old user
      old_user = channel.follower_user
      old_user.decrement!(:channels_count)

      # Assign to new user
      Channels::ChannelAssignmentService.assign_to_user(new_user, channel)

      log_channel_moved(channel, old_user, new_user)
    end
  end

  def self.cleanup_inactive_channel(channel)
    # Unassign from follower user
    if channel.follower_user
      channel.follower_user.decrement!(:channels_count)
    end

    # Mark as inactive
    channel.update!(
      assignment_status: :inactive,
      follower_user: nil,
      user_access_status: :not_joined
    )

    log_channel_cleanup(channel)
  end
end
```

## Content Relevance Analysis

### AI-Powered Relevance Scoring
```ruby
class ContentRelevanceService
  RELEVANCE_CATEGORIES = [
    :technology, :business, :science, :programming,
    :ai_ml, :startups, :productivity, :innovation
  ].freeze

  def self.analyze_relevance(content)
    return 0.5 if content.blank?

    # Extract key topics from content
    topics = extract_topics(content)

    # Calculate relevance scores for each category
    relevance_scores = RELEVANCE_CATEGORIES.map do |category|
      [category, calculate_category_relevance(topics, category)]
    end.to_h

    # Return the maximum relevance score
    relevance_scores.values.max.round(2)
  end

  private

  def self.extract_topics(content)
    # Simple keyword extraction (could be enhanced with NLP)
    keywords = content.downcase.scan(/\b\w+\b/)

    # Filter common words and extract meaningful terms
    meaningful_keywords = keywords.reject { |word| stop_words.include?(word) }

    # Count word frequency
    keyword_counts = meaningful_keywords.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }

    # Return top keywords with their frequencies
    keyword_counts.sort_by { |_, count| -count }.first(10)
  end

  def self.calculate_category_relevance(topics, category)
    category_keywords = CATEGORY_KEYWORDS[category] || []

    return 0.0 if category_keywords.empty?

    # Calculate overlap between topics and category keywords
    overlap_count = topics.keys.count { |topic| category_keywords.include?(topic) }

    # Weight by frequency
    weighted_overlap = topics.sum do |topic, frequency|
      category_keywords.include?(topic) ? frequency : 0
    end

    # Normalize to 0-1 scale
    [weighted_overlap.to_f / category_keywords.length, 1.0].min
  end

  CATEGORY_KEYWORDS = {
    technology: %w[tech software development programming code app],
    business: %w[company startup entrepreneurship market revenue],
    science: %w[research study experiment data analysis],
    programming: %w[ruby javascript python coding developer],
    ai_ml: %w[artificial intelligence machine learning neural network],
    startups: %w[founder funding venture accelerator],
    productivity: %w[tool efficiency workflow management],
    innovation: %w[innovation breakthrough creative disruptive]
  }.freeze

  STOP_WORDS = %w[the a an and or but in on at to for of with by].freeze
end
```

## Activity Monitoring Dashboard

### Metrics Tracking
```ruby
class Channels::ActivityMonitor
  def self.generate_activity_report
    {
      summary: calculate_activity_summary,
      distribution: calculate_activity_distribution,
      trends: calculate_activity_trends,
      recommendations: generate_recommendations,
      top_channels: find_most_active_channels,
      inactive_channels: find_least_active_channels
    }
  end

  def self.calculate_activity_summary
    channels = Channel.all

    {
      total_channels: channels.count,
      avg_activity_score: channels.average(:activity_score)&.round(2),
      very_high_activity: channels.where('activity_score >= 0.8').count,
      high_activity: channels.where('activity_score >= 0.6 AND activity_score < 0.8').count,
      medium_activity: channels.where('activity_score >= 0.3 AND activity_score < 0.6').count,
      low_activity: channels.where('activity_score >= 0.1 AND activity_score < 0.3').count,
      very_low_activity: channels.where('activity_score < 0.1').count,
      inactive_channels: channels.where('last_activity_at < ?', 30.days.ago).count
    }
  end

  def self.calculate_activity_distribution
    channels = Channel.includes(:follower_user).all

    user_activity = channels.group_by(&:follower_user).map do |user, user_channels|
      {
        user: user&.phone_number || 'Unassigned',
        channels_count: user_channels.count,
        avg_activity_score: user_channels.map(&:activity_score).sum / user_channels.count,
        total_activity_score: user_channels.sum(&:activity_score)
      }
    end

    user_activity.sort_by { |u| -u[:total_activity_score] }
  end

  def self.generate_recommendations
    recommendations = []

    # Check for inactive channels
    inactive_count = Channel.where('activity_score < 0.1').count
    if inactive_count > 0
      recommendations << "Consider cleaning up #{inactive_count} inactive channels"
    end

    # Check for activity imbalance
    user_activity = calculate_activity_distribution
    if user_activity.any? { |u| u[:avg_activity_score] > 0.8 }
      recommendations << "Some users have high-activity concentration, consider rebalancing"
    end

    # Check for unassigned channels
    unassigned_count = Channel.where(follower_user: nil).count
    if unassigned_count > 0
      recommendations << "#{unassigned_count} channels need user assignment"
    end

    recommendations
  end
end
```

## Admin Interface

### Activity Dashboard
- Activity score distribution chart
- Top active channels list
- Inactive channels cleanup
- Rebalancing recommendations
- Activity trends over time

### Channel Management
- Manual activity score adjustment
- Channel category assignment
- Activity threshold configuration
- Bulk operations on channels

### Rebalancing Controls
- Manual rebalancing trigger
- Activity imbalance alerts
- Cleanup operations
- Performance metrics

## Критерии успешности

### Accuracy
- [ ] Activity score calculation accuracy > 90%
- [ ] Content relevance scoring working
- [ ] Activity predictions matching actual behavior
- [ ] Rebalancing recommendations effective

### Performance
- [ ] Batch calculation of 1000+ channels < 5 минут
- [ ] Real-time activity updates
- [ ] Rebalancing operations < 10 минут
- [ ] Dashboard response time < 2 секунды

### Automation
- [ ] Automatic activity score updates
- [ ] Trigger-based rebalancing
- [ ] Inactive channel cleanup
- [ ] Activity-aware channel assignment

## Риски и митигация

### 1. Inaccurate Activity Scoring
- **Риск**: Неправильный расчет активности
- **Митигация**: Multiple data sources, AI validation, manual overrides

### 2. Over-Rebalancing
- **Риск**: Слишком частая ребалансировка
- **Митигация**: Threshold tuning, rate limiting, manual confirmation

### 3. False Activity Detection
- **Риск**: Обнаружение ложной активности
- **Митигация**: Data validation, pattern recognition, human review

### 4. Content Relevance Bias
- **Риск**: Предвзятость в анализе контента
- **Митигация**: Diverse training data, regular model updates, feedback loops

---

## Статус: draft

Эта спецификация описывает систему мониторинга активности каналов и должна быть реализована после базовой Channel модели и FollowerUser pool management.

**Связанные документы**:
- [046 User-based Channel Access](./046_Bot_Channel_Join_Process_Specification_Updated.md)
- [052 FollowerUser Pool Management](./052_FollowerUser_Pool_Management_Specification.md)
- [053 FollowerUser Lifecycle](./053_FollowerUser_Lifecycle_Specification.md)