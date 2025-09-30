# Примеры реализации ключевых компонентов

Этот документ содержит готовые примеры кода для реализации архитектурных изменений, предложенных в архитектурном ревью.

---

## 1. Модель AISession

```ruby
# app/models/ai_session.rb
class AISession < ApplicationRecord
  belongs_to :user
  has_many :ai_messages, dependent: :destroy

  # Интеграция с ruby_llm для автоматического сохранения истории
  acts_as_chat

  enum session_type: {
    classification: 0,
    summarization: 1,
    personalization: 2,
    digest_generation: 3
  }

  enum status: {
    active: 0,
    archived: 1
  }

  # Контекст сессии (JSONB поле)
  store_accessor :context,
    :user_preferences,
    :recent_feedback,
    :feedback_examples,
    :classification_history

  validates :user, presence: true
  validates :session_type, presence: true

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :archived, -> { where(status: :archived) }
  scope :by_type, ->(type) { where(session_type: type) }
  scope :recently_active, -> { where("last_activity_at > ?", 7.days.ago) }
  scope :needs_cleanup, -> { where("messages_count > ?", 100) }

  # Контекстное окно - сколько сообщений держать в активной памяти
  def active_context_window
    50
  end

  # Получить последние N сообщений для контекста
  def recent_messages(limit = 10)
    ai_messages.order(created_at: :desc).limit(limit).reverse
  end

  # Получить важные сообщения из истории (помеченные как important)
  def important_messages(limit = 5)
    ai_messages
      .where("metadata->>'importance' = 'high'")
      .order(created_at: :desc)
      .limit(limit)
  end

  # Добавить пример из фидбека в контекст
  def add_feedback_example(post, feedback)
    examples = context["feedback_examples"] || []
    examples << {
      post_text: post.text[0..300], # Первые 300 символов
      post_topics: post.topics,
      user_liked: feedback.like?,
      importance_score: post.importance_score,
      timestamp: feedback.created_at.iso8601
    }

    # Храним последние 20 примеров
    context["feedback_examples"] = examples.last(20)
    self.last_activity_at = Time.current
    save
  end

  # Архивировать старые сообщения
  def archive_old_messages(older_than: 30.days.ago)
    ai_messages.where("created_at < ?", older_than).destroy_all
    update(messages_count: ai_messages.count)
  end

  # Сжатие истории для long-running сессий
  def compact_history
    return if messages_count < 100

    # Оставить только важные + последние N сообщений
    messages_to_keep = ai_messages.order(created_at: :desc)
                        .limit(50)
                        .pluck(:id)

    important_ids = ai_messages
                     .where("metadata->>'keep' = 'true'")
                     .pluck(:id)

    ai_messages.where.not(id: messages_to_keep + important_ids).destroy_all
    update(messages_count: ai_messages.count)
  end

  # Получить chat instance с управляемым контекстом
  def chat_with_managed_context
    recent = recent_messages(20)
    important = important_messages(5)

    # Создать временный chat с ограниченной историей
    messages = (important + recent).uniq.sort_by(&:created_at)

    RubyLLM.chat(
      system: build_system_prompt,
      history: messages.map(&:to_message_hash)
    )
  end

  private

  def build_system_prompt
    case session_type.to_sym
    when :classification
      classification_system_prompt
    when :summarization
      "Ты — эксперт по созданию кратких и информативных саммари."
    when :personalization
      "Ты — система персонализации, анализирующая предпочтения пользователя."
    when :digest_generation
      "Ты — помощник по созданию персонализированных дайджестов."
    end
  end

  def classification_system_prompt
    <<~PROMPT
      Ты — система классификации контента для персонального Telegram бота.

      Твоя задача — оценивать важность постов от 0 до 100 и определять:
      - Является ли пост рекламой или шелухой
      - Какие темы затрагивает пост
      - Насколько пост соответствует интересам конкретного пользователя

      Используй историю взаимодействий и фидбек пользователя для персонализации оценок.
    PROMPT
  end
end

# Миграция
class CreateAISessions < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_sessions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.integer :session_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.jsonb :context, default: {}
      t.datetime :last_activity_at
      t.integer :messages_count, default: 0

      t.timestamps
    end

    add_index :ai_sessions, [:user_id, :session_type]
    add_index :ai_sessions, :status
    add_index :ai_sessions, :last_activity_at
    add_index :ai_sessions, :context, using: :gin
  end
end
```

---

## 2. Обновленная модель User

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :subscriptions, dependent: :destroy
  has_many :channels, through: :subscriptions
  has_many :digests, dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_one :user_preference, dependent: :destroy
  has_many :ai_sessions, dependent: :destroy  # 🆕

  # Настройки
  enum delivery_frequency: {
    realtime: 0,
    three_times_daily: 1,
    twice_daily: 2,
    daily: 3,
    every_two_days: 4,
    weekly: 5,
    on_demand: 6
  }

  enum content_format: {
    original_posts: 0,
    short_summaries: 1,
    unified_digest: 2,
    combo: 3,
    headlines_only: 4
  }

  enum filter_strictness: {
    maximum: 0,
    high: 1,
    medium: 2,
    low: 3,
    adaptive: 4
  }

  validates :telegram_id, presence: true, uniqueness: true

  # 🆕 Получить или создать активную сессию определенного типа
  def ai_session_for(type)
    ai_sessions.active.find_or_create_by!(session_type: type) do |session|
      session.context = build_initial_context
      session.last_activity_at = Time.current
    end
  end

  # 🆕 Построить начальный контекст для новой сессии
  def build_initial_context
    {
      user_preferences: {
        delivery_frequency: delivery_frequency,
        content_format: content_format,
        filter_strictness: filter_strictness,
        timezone: timezone || 'UTC'
      },
      feedback_history: recent_feedback_summary,
      subscription_priorities: subscriptions.pluck(:channel_id, :priority).to_h,
      created_at: Time.current.iso8601
    }
  end

  # 🆕 Краткая сводка последнего фидбека
  def recent_feedback_summary(limit: 20)
    feedbacks.includes(:post).order(created_at: :desc).limit(limit).map do |f|
      {
        liked: f.like?,
        post_importance: f.post.importance_score,
        topics: f.post.topics || [],
        created_at: f.created_at.iso8601
      }
    end
  end

  # 🆕 Архивировать неактивные сессии
  def archive_inactive_sessions
    ai_sessions.active
      .where("last_activity_at < ?", 90.days.ago)
      .update_all(status: :archived)
  end

  # Обновить timestamp для инвалидации кеша
  after_update :touch
end
```

---

## 3. Structured Output Schema

```ruby
# app/schemas/base_schema.rb
module Schemas
  class BaseSchema < RubyLLM::Schema
    # Базовый класс для всех схем
  end
end

# app/schemas/post_classification_schema.rb
module Schemas
  class PostClassificationSchema < BaseSchema
    # Оценка важности от 0 до 100
    number :importance_score,
      description: "Оценка важности поста от 0 (совершенно неважный) до 100 (критически важный)"

    # Является ли пост рекламой
    boolean :is_ad,
      description: "true если пост является рекламой, иначе false"

    # Является ли пост шелухой (низкокачественный контент)
    boolean :is_fluff,
      description: "true если пост является шелухой (мемы, спам, бесполезный контент)"

    # Краткое объяснение оценки
    string :reasoning,
      description: "Краткое (1-2 предложения) объяснение почему дана такая оценка"

    # Темы поста
    array :topics,
      description: "Список тем, которые затрагивает пост" do
      string
    end

    # Проверка на дубликат
    object :duplicate_check,
      description: "Информация о возможном дублировании" do
      boolean :is_likely_duplicate,
        description: "Вероятность того, что это дубликат"

      number :similarity_score,
        description: "Оценка схожести с другими постами от 0 до 100"
    end

    # Уровень уверенности в оценке
    number :confidence,
      description: "Уровень уверенности в классификации от 0 до 100"
  end
end
```

---

## 4. AI Tools (Function Calling)

```ruby
# app/tools/base_tool.rb
module Tools
  class BaseTool < RubyLLM::Tool
    # Базовый класс для всех инструментов
  end
end

# app/tools/classify_post_tool.rb
module Tools
  class ClassifyPostTool < BaseTool
    description "Классифицирует пост из Telegram канала по важности и другим характеристикам"

    param :importance_score,
      type: :integer,
      description: "Оценка важности от 0 до 100"

    param :is_ad,
      type: :boolean,
      description: "Является ли пост рекламой"

    param :is_fluff,
      type: :boolean,
      description: "Является ли контент шелухой"

    param :topics,
      type: :array,
      description: "Список тем поста"

    param :reasoning,
      type: :string,
      description: "Объяснение классификации"

    param :confidence,
      type: :integer,
      description: "Уровень уверенности 0-100"

    def execute(importance_score:, is_ad:, is_fluff:, topics:, reasoning:, confidence: 80)
      # Валидация параметров
      raise ArgumentError, "importance_score должен быть от 0 до 100" unless (0..100).include?(importance_score)
      raise ArgumentError, "confidence должен быть от 0 до 100" unless (0..100).include?(confidence)

      # Возвращаем структурированные данные
      {
        importance_score: importance_score,
        is_ad: is_ad,
        is_fluff: is_fluff,
        topics: Array(topics),
        reasoning: reasoning,
        confidence: confidence,
        classified_at: Time.current.iso8601
      }
    end
  end
end

# app/tools/detect_duplicate_tool.rb
module Tools
  class DetectDuplicateTool < BaseTool
    description "Определяет, является ли пост дубликатом уже существующего"

    param :is_duplicate,
      type: :boolean,
      description: "Является ли пост дубликатом"

    param :similarity_score,
      type: :integer,
      description: "Оценка схожести от 0 до 100"

    param :original_post_reference,
      type: :string,
      description: "Ссылка на оригинальный пост если это дубликат"

    def execute(is_duplicate:, similarity_score:, original_post_reference: nil)
      {
        is_duplicate: is_duplicate,
        similarity_score: similarity_score,
        original_post_reference: original_post_reference,
        checked_at: Time.current.iso8601
      }
    end
  end
end
```

---

## 5. AI Session Manager Service

```ruby
# app/services/ai/session_manager.rb
module AI
  class SessionManager
    attr_reader :user, :session

    def initialize(user, session_type)
      @user = user
      @session = find_or_create_session(session_type)
    end

    # Выполнить операцию с AI в контексте сессии
    def with_context(&block)
      chat = build_chat_with_context
      result = yield chat, @session

      # Обновить метрики сессии
      update_session_metrics
      cleanup_if_needed

      result
    end

    # Выполнить операцию с structured output
    def with_schema(schema_class, &block)
      with_context do |chat, session|
        chat_with_schema = chat.with_schema(schema_class)
        yield chat_with_schema, session
      end
    end

    # Выполнить операцию с tools
    def with_tools(tools_array, &block)
      with_context do |chat, session|
        chat_with_tools = RubyLLM.chat(
          tools: tools_array,
          system: chat.system_message
        )
        yield chat_with_tools, session
      end
    end

    private

    def find_or_create_session(type)
      @user.ai_session_for(type)
    end

    def build_chat_with_context
      context_builder = AI::ContextBuilder.new(@session, @user)

      # Использовать managed context для оптимизации токенов
      @session.chat_instance.tap do |chat|
        chat.system_message = context_builder.system_prompt
        # Ограничить историю релевантными сообщениями
        chat.history = context_builder.relevant_history
      end
    end

    def update_session_metrics
      @session.touch(:last_activity_at)
      @session.increment!(:messages_count)
    end

    def cleanup_if_needed
      # Архивировать старые сообщения если сессия слишком большая
      if @session.messages_count > 100
        Rails.logger.info "Compacting AI session #{@session.id} (#{@session.messages_count} messages)"
        @session.compact_history
      end
    end
  end
end

# Использование
session_manager = AI::SessionManager.new(user, :classification)

# С Structured Output
result = session_manager.with_schema(Schemas::PostClassificationSchema) do |chat, session|
  chat.ask("Классифицируй этот пост: #{post.text}")
end

# С Tools
result = session_manager.with_tools([Tools::ClassifyPostTool]) do |chat, session|
  chat.ask("Проанализируй этот пост: #{post.text}")
end
```

---

## 6. Context Builder Service

```ruby
# app/services/ai/context_builder.rb
module AI
  class ContextBuilder
    MAX_HISTORY_MESSAGES = 20
    MAX_FEW_SHOT_EXAMPLES = 10

    attr_reader :session, :user

    def initialize(session, user)
      @session = session
      @user = user
    end

    def system_prompt
      case @session.session_type.to_sym
      when :classification
        classification_system_prompt
      when :summarization
        summarization_system_prompt
      when :personalization
        personalization_system_prompt
      when :digest_generation
        digest_generation_system_prompt
      end
    end

    def relevant_history
      # Комбинировать разные типы релевантных сообщений
      messages = [
        important_examples,
        recent_interactions,
        few_shot_from_feedback
      ].flatten.uniq(&:id).sort_by(&:created_at)

      # Ограничить общее количество
      messages.last(MAX_HISTORY_MESSAGES)
    end

    private

    def classification_system_prompt
      <<~PROMPT
        Ты — система классификации контента для персонального Telegram бота "Без шелухи".

        ## Информация о пользователе
        - Уровень строгости фильтрации: #{@user.filter_strictness}
        - Предпочитаемый формат контента: #{@user.content_format}
        - Количество подписок: #{@user.subscriptions.count}
        - Часовой пояс: #{@user.timezone || 'UTC'}

        #{feedback_context if @user.feedbacks.any?}

        ## Твоя задача
        Оценить важность поста от 0 до 100, определить:
        - Является ли он рекламой или шелухой
        - Какие темы затрагивает
        - Насколько соответствует интересам данного пользователя

        ## Критерии оценки
        - **90-100**: Критически важная информация, прорывы, важные новости
        - **70-89**: Очень интересный и полезный контент
        - **50-69**: Умеренно интересный контент
        - **30-49**: Малоинтересный контент
        - **0-29**: Шелуха, реклама, спам

        Используй примеры из истории фидбека, чтобы понять предпочтения пользователя.
      PROMPT
    end

    def summarization_system_prompt
      <<~PROMPT
        Ты — эксперт по созданию кратких и информативных саммари.

        Твоя задача — создавать краткие (2-3 предложения) саммари постов,
        сохраняя самую важную информацию и основную идею.

        Формат: #{@user.content_format}
      PROMPT
    end

    def personalization_system_prompt
      <<~PROMPT
        Ты — система персонализации, анализирующая предпочтения пользователя.

        Анализируй фидбек (лайки/дизлайки) и определяй паттерны:
        - Какие темы интересуют пользователя
        - Какой стиль контента предпочитает
        - Какую глубину и детальность ожидает

        Используй эти знания для улучшения классификации в будущем.
      PROMPT
    end

    def digest_generation_system_prompt
      <<~PROMPT
        Ты — помощник по созданию персонализированных дайджестов.

        Создавай дайджесты в формате "#{@user.content_format}":
        - Группируй похожие посты
        - Выделяй самое важное
        - Сохраняй структуру и читаемость
      PROMPT
    end

    def feedback_context
      return "" unless @user.feedbacks.any?

      examples = @user.recent_feedback_summary(limit: 10)
      patterns = analyze_feedback_patterns

      <<~CONTEXT

        ## Последние примеры фидбека пользователя
        #{format_feedback_examples(examples)}

        ## Выявленные паттерны предпочтений
        #{patterns}
      CONTEXT
    end

    def format_feedback_examples(examples)
      examples.map do |ex|
        sentiment = ex[:liked] ? "👍 Понравился" : "👎 Не понравился"
        topics = ex[:topics].any? ? ex[:topics].join(', ') : "без тем"
        "- #{sentiment} | Важность: #{ex[:post_importance]}/100 | Темы: #{topics}"
      end.join("\n")
    end

    def analyze_feedback_patterns
      # Анализ предпочтений по темам
      liked_topics = @user.feedbacks.liked
        .joins(:post)
        .where.not("posts.topics": [])
        .pluck('posts.topics')
        .flatten
        .tally
        .sort_by { |_, count| -count }
        .first(5)

      disliked_topics = @user.feedbacks.disliked
        .joins(:post)
        .where.not("posts.topics": [])
        .pluck('posts.topics')
        .flatten
        .tally
        .sort_by { |_, count| -count }
        .first(3)

      patterns = []

      if liked_topics.any?
        top_likes = liked_topics.map { |t, c| "#{t} (#{c})" }.join(', ')
        patterns << "- Интересующие темы: #{top_likes}"
      end

      if disliked_topics.any?
        top_dislikes = disliked_topics.map { |t, c| "#{t} (#{c})" }.join(', ')
        patterns << "- Неинтересующие темы: #{top_dislikes}"
      end

      # Анализ предпочитаемых оценок
      avg_liked_score = @user.feedbacks.liked
        .joins(:post)
        .average('posts.importance_score')
        .to_f.round

      if avg_liked_score > 0
        patterns << "- Средняя оценка понравившихся постов: #{avg_liked_score}/100"
      end

      patterns.join("\n")
    end

    def important_examples
      @session.important_messages(5)
    end

    def recent_interactions
      @session.recent_messages(MAX_HISTORY_MESSAGES - 10)
    end

    def few_shot_from_feedback
      # Ограничить количество few-shot примеров
      builder = Personalization::FewShotBuilder.new(@user)
      builder.build_examples.first(MAX_FEW_SHOT_EXAMPLES)
    end
  end
end
```

---

## 7. AI Classifier Service (обновленный)

```ruby
# app/services/content/ai_classifier.rb
module Content
  class AIClassifier
    attr_reader :user, :session_manager

    def initialize(user)
      @user = user
      @session_manager = AI::SessionManager.new(user, :classification)
    end

    def classify(post)
      # Использовать кеширование
      cache_key = "classification/#{post.id}/#{user.id}"
      dependencies = [user, post]

      Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        perform_classification(post)
      end
    end

    def classify_with_context(post)
      result = @session_manager.with_schema(Schemas::PostClassificationSchema) do |chat, session|
        classify_request(chat, post)
      end

      save_classification(post, result)
      result
    end

    private

    def perform_classification(post)
      start_time = Time.current

      result = @session_manager.with_schema(Schemas::PostClassificationSchema) do |chat, session|
        # Построить контекст с few-shot примерами
        context = build_classification_context(post)

        response = chat.ask(
          "#{context}\n\nТеперь классифицируй этот пост:\n\n#{post.text}"
        )

        response
      end

      # Логировать метрики
      log_classification_metrics(post, result, Time.current - start_time)

      result
    end

    def build_classification_context(post)
      # Добавить few-shot примеры из фидбека
      few_shot = Personalization::FewShotBuilder.new(@user)
      examples = few_shot.build_examples

      return "" if examples.empty?

      <<~CONTEXT
        Вот несколько примеров того, как пользователь оценивал похожие посты:

        #{format_few_shot_examples(examples)}

        Используй эти примеры для понимания предпочтений пользователя.
      CONTEXT
    end

    def format_few_shot_examples(examples)
      examples.map.with_index do |(user_msg, assistant_msg), i|
        <<~EXAMPLE
          Пример #{i + 1}:
          #{user_msg[:content]}

          Оценка: #{JSON.parse(assistant_msg[:content])['importance_score']}/100
          Реакция пользователя: #{JSON.parse(assistant_msg[:content])['user_liked'] ? '👍' : '👎'}
        EXAMPLE
      end.join("\n")
    end

    def save_classification(post, result)
      post.update!(
        classification_data: {
          importance_score: result.importance_score,
          is_ad: result.is_ad,
          is_fluff: result.is_fluff,
          duplicate_check: result.duplicate_check,
          confidence: result.confidence
        },
        topics: result.topics,
        classification_reasoning: result.reasoning,
        classified_by_session_id: @session_manager.session.id
      )

      # Создать персональную классификацию
      PostClassification.create!(
        post: post,
        user: @user,
        ai_session: @session_manager.session,
        importance_score: result.importance_score,
        is_relevant: result.importance_score >= relevance_threshold,
        reasoning: result.reasoning,
        confidence: result.confidence
      )
    end

    def relevance_threshold
      Personalization::ThresholdAdjuster.new(@user).adjusted_threshold
    end

    def log_classification_metrics(post, result, duration)
      Rails.logger.info({
        event: 'ai_classification',
        user_id: @user.id,
        post_id: post.id,
        importance_score: result.importance_score,
        is_ad: result.is_ad,
        confidence: result.confidence,
        duration_seconds: duration.round(2),
        session_id: @session_manager.session.id
      }.to_json)
    end
  end
end
```

---

## 8. Персонализация через Feedback

```ruby
# app/models/feedback.rb
class Feedback < ApplicationRecord
  belongs_to :user
  belongs_to :post

  enum sentiment: { dislike: -1, neutral: 0, like: 1 }

  validates :user, presence: true
  validates :post, presence: true
  validates :sentiment, presence: true

  scope :liked, -> { where(sentiment: :like) }
  scope :disliked, -> { where(sentiment: :dislike) }
  scope :recent, -> { where('created_at > ?', 30.days.ago) }

  # После создания фидбека - обновить AI-сессию персонализации
  after_create :update_personalization_session

  private

  def update_personalization_session
    session = user.ai_session_for(:personalization)
    session.add_feedback_example(post, self)

    # Асинхронно обновить модель персонализации
    PersonalizationUpdateJob.perform_later(user.id, id)
  end
end

# app/jobs/personalization_update_job.rb
class PersonalizationUpdateJob < ApplicationJob
  queue_as :default

  def perform(user_id, feedback_id)
    user = User.find(user_id)
    feedback = Feedback.find(feedback_id)

    session_manager = AI::SessionManager.new(user, :personalization)

    result = session_manager.with_context do |chat, session|
      analyze_feedback(chat, user, feedback)
    end

    # Обновить UserPreference на основе анализа
    update_user_preference(user, feedback, result)
  end

  private

  def analyze_feedback(chat, user, feedback)
    chat.ask(
      <<~PROMPT
        Пользователь дал фидбек на пост:

        Пост: "#{feedback.post.text[0..300]}"
        Темы: #{feedback.post.topics.join(', ')}
        AI-оценка важности: #{feedback.post.importance_score}/100
        Реакция пользователя: #{feedback.like? ? 'Понравился 👍' : 'Не понравился 👎'}

        Проанализируй:
        1. Что это говорит о предпочтениях пользователя?
        2. Какие темы нужно учитывать сильнее/слабее?
        3. Нужно ли скорректировать порог важности?

        Дай краткий анализ (2-3 предложения).
      PROMPT
    )
  end

  def update_user_preference(user, feedback, analysis_result)
    preference = user.user_preference || user.create_user_preference!

    # Обновить веса тем
    feedback.post.topics.each do |topic|
      preference.adjust_topic_weight(topic, feedback)
    end
  end
end

# app/services/personalization/few_shot_builder.rb
module Personalization
  class FewShotBuilder
    def initialize(user)
      @user = user
    end

    def build_examples
      # Получить сбалансированную выборку фидбека
      liked = @user.feedbacks.liked.includes(:post).order(created_at: :desc).limit(5)
      disliked = @user.feedbacks.disliked.includes(:post).order(created_at: :desc).limit(5)

      examples = []

      # Добавить примеры понравившегося контента
      liked.each do |feedback|
        examples << build_example(feedback, boost: 10)
      end

      # Добавить примеры неинтересного контента
      disliked.each do |feedback|
        examples << build_example(feedback, boost: -20)
      end

      examples
    end

    private

    def build_example(feedback, boost:)
      adjusted_score = [feedback.post.importance_score + boost, 0, 100].sort[1]

      [
        {
          role: 'user',
          content: "Классифицируй этот пост:\n\n#{feedback.post.text[0..300]}"
        },
        {
          role: 'assistant',
          content: {
            importance_score: adjusted_score,
            is_ad: feedback.post.classification_data['is_ad'],
            is_fluff: feedback.post.classification_data['is_fluff'],
            topics: feedback.post.topics,
            reasoning: "Пользователь #{feedback.like? ? 'одобрил' : 'отклонил'} похожий контент",
            user_liked: feedback.like?,
            confidence: 85
          }.to_json
        }
      ]
    end
  end
end
```

---

## 9. Streaming Support

```ruby
# app/services/digest/builder.rb (с поддержкой streaming)
module Digest
  class Builder
    def initialize(user)
      @user = user
      @session_manager = AI::SessionManager.new(user, :digest_generation)
    end

    def build_digest_with_streaming(posts, &progress_callback)
      accumulated_text = ""

      result = @session_manager.with_context do |chat, session|
        prompt = build_digest_prompt(posts)

        # Использовать streaming для лучшего UX
        chat.ask(prompt) do |chunk|
          accumulated_text += chunk.content

          # Вызвать callback для обновления UI
          progress_callback.call(accumulated_text) if progress_callback
        end
      end

      result
    end

    private

    def build_digest_prompt(posts)
      <<~PROMPT
        Создай дайджест из #{posts.count} постов в формате #{@user.content_format}:

        #{posts.map.with_index { |p, i| "#{i+1}. #{p.text[0..200]}..." }.join("\n\n")}

        Требования:
        - Группируй похожие посты
        - Выдели самое важное
        - Формат: #{format_description}
      PROMPT
    end

    def format_description
      case @user.content_format.to_sym
      when :original_posts then "оригинальные посты с минимальными правками"
      when :short_summaries then "краткие саммари каждого поста (2-3 предложения)"
      when :unified_digest then "единый дайджест всех постов"
      when :combo then "топ-3 поста полностью + краткие саммари остальных"
      when :headlines_only then "только заголовки и ссылки"
      end
    end
  end
end

# Использование в Telegram Bot
def send_digest_with_progress(user, posts)
  message_id = telegram.send_message(
    user.telegram_id,
    "Генерирую дайджест из #{posts.count} постов..."
  )

  builder = Digest::Builder.new(user)

  update_counter = 0
  digest_text = builder.build_digest_with_streaming(posts) do |partial_text|
    update_counter += 1

    # Обновлять сообщение каждые 10 чанков
    if update_counter % 10 == 0
      telegram.edit_message(user.telegram_id, message_id, partial_text)
    end
  end

  # Финальное обновление
  telegram.edit_message(user.telegram_id, message_id, digest_text)
end
```

---

## 10. Batch Classification

```ruby
# app/services/content/batch_classifier.rb
module Content
  class BatchClassifier
    BATCH_SIZE = 10

    def initialize(user)
      @user = user
      @session_manager = AI::SessionManager.new(user, :classification)
    end

    def classify_batch(posts)
      posts.each_slice(BATCH_SIZE) do |batch|
        classify_batch_chunk(batch)
      end
    end

    private

    def classify_batch_chunk(posts)
      result = @session_manager.with_context do |chat, session|
        prompt = build_batch_prompt(posts)

        # Получить классификации для всех постов сразу
        chat.ask(prompt)
      end

      # Парсить результаты и сохранить
      parse_and_save_results(posts, result)
    end

    def build_batch_prompt(posts)
      posts_text = posts.map.with_index do |post, i|
        "ID#{i}: #{post.text[0..200]}"
      end.join("\n\n")

      <<~PROMPT
        Классифицируй следующие #{posts.count} постов.
        Для каждого поста верни JSON с полями: id, importance_score, is_ad, is_fluff, topics.

        Посты:
        #{posts_text}

        Верни массив классификаций в JSON формате.
      PROMPT
    end

    def parse_and_save_results(posts, result)
      # Парсинг зависит от формата ответа
      # Это упрощенный пример
      classifications = JSON.parse(result.content)

      classifications.each_with_index do |classification, i|
        save_classification(posts[i], classification)
      end
    end

    def save_classification(post, classification)
      post.update!(
        classification_data: {
          importance_score: classification['importance_score'],
          is_ad: classification['is_ad'],
          is_fluff: classification['is_fluff']
        },
        topics: classification['topics']
      )
    end
  end
end
```

---

## Заключение

Эти примеры демонстрируют:

1. **AISession с acts_as_chat** - автоматическое сохранение истории
2. **Structured Output** - надежный парсинг ответов AI
3. **Tools (Function Calling)** - более точная классификация
4. **Context Management** - оптимизация использования токенов
5. **Few-Shot Learning** - персонализация через фидбек
6. **Streaming** - улучшение UX
7. **Batch Processing** - оптимизация производительности

Все компоненты спроектированы для совместной работы и обеспечивают:
- Персонализацию для каждого пользователя
- Оптимальное использование AI токенов
- Высокую точность классификации
- Отличный UX
- Масштабируемость
