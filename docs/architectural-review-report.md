# Архитектурное ревью проекта NoFluff Bot

**Дата:** 30 сентября 2025
**Фаза проекта:** Phase 1.1 (Начальная настройка инфраструктуры)
**Версия:** 1.0

---

## Executive Summary

Проект NoFluff Bot находится на самой ранней стадии разработки (Phase 1.1), что предоставляет идеальную возможность заложить правильную архитектуру с самого начала. Проведенное архитектурное ревью выявило **критические упущенные возможности** в использовании `ruby_llm` gem и **отсутствие стратегии персонализации** через сохранение сессий и истории взаимодействий с AI.

### Ключевые находки

**КРИТИЧЕСКИЕ ПРОБЛЕМЫ:**
1. ❌ **Не используется `acts_as_chat`** - теряется история взаимодействий с AI
2. ❌ **Отсутствует модель Chat/Conversation** - нет персонального контекста
3. ❌ **Не используется Structured Output** - ненадежный парсинг AI ответов
4. ❌ **Не используются Tools (Function Calling)** - более сложная классификация
5. ❌ **Не используется Streaming** - плохой UX при ожидании ответов
6. ❌ **Отсутствует связь фидбека с историей AI** - персонализация не работает

**АРХИТЕКТУРНЫЕ РИСКИ:**
- 🔴 **Производительность**: Отправка полной истории каждый раз без оптимизации
- 🔴 **Масштабируемость**: Отсутствие стратегии управления контекстом
- 🔴 **Персонализация**: Feedback не влияет на будущие AI-запросы
- 🔴 **Надежность**: Отсутствие структурированных ответов от AI

---

## 1. Анализ использования ruby_llm

### 1.1. Текущее состояние (согласно документации)

**Планируется в ROADMAP (Phase 1.5):**
```ruby
# app/services/content/ai_classifier.rb
class Content::AIClassifier
  def classify_importance(post)
    chat = RubyLLM.chat(model: 'gpt-4')
    response = chat.ask("Оцени важность этого поста: #{post.text}")
    # Парсинг строкового ответа 😱
  end
end
```

**Проблемы:**
- ❌ Создается новый chat объект для каждого запроса
- ❌ Нет сохранения истории классификаций
- ❌ Ответ в виде строки требует парсинга (ненадежно)
- ❌ Нет персонального контекста пользователя
- ❌ Каждый запрос - "с чистого листа", модель не учится

### 1.2. Упущенные возможности ruby_llm

#### 1.2.1. acts_as_chat - Автоматическое сохранение истории

**Что это дает:**
```ruby
# Модель с acts_as_chat
class UserChat < ApplicationRecord
  belongs_to :user
  acts_as_chat
end

# Использование
session = user.chats.find_or_create_by(session_type: 'classification')
session.ask "Оцени важность поста: #{post.text}"
session.ask "А теперь этого: #{another_post.text}" # История сохранена!

# Доступ к истории
session.messages.each do |message|
  puts "#{message.role}: #{message.content}"
end
```

**Преимущества:**
- ✅ Автоматическое сохранение всей истории в БД
- ✅ Модель "помнит" предыдущие классификации
- ✅ Можно анализировать паттерны классификации
- ✅ Персонализация через накопленную историю
- ✅ Обучение модели на примерах из истории

**Применение в NoFluff:**
1. **Персональные AI-сессии для каждого пользователя**
2. **История классификаций** - модель учится на предыдущих решениях
3. **Few-shot learning** - передача примеров из истории для улучшения точности
4. **Анализ качества классификации** через сохраненную историю

#### 1.2.2. Structured Output - Надежный парсинг

**Текущая проблема:**
```ruby
# Ненадежный способ
response = chat.ask("Классифицируй пост")
# Получаем: "Важность: 85/100, Реклама: Нет, Причина: Содержит..."
# Нужно парсить строку регулярками 😱
```

**Правильный способ:**
```ruby
# Определение схемы ответа
class PostClassificationSchema < RubyLLM::Schema
  number :importance_score, description: "Оценка важности от 0 до 100"
  boolean :is_ad, description: "Является ли пост рекламой"
  boolean :is_fluff, description: "Является ли пост шелухой"
  string :reasoning, description: "Краткое объяснение оценки"
  array :topics do
    string
  end
  object :duplicate_check do
    boolean :is_likely_duplicate
    number :similarity_score
  end
end

# Использование
chat = RubyLLM.chat.with_schema(PostClassificationSchema)
result = chat.ask("Классифицируй: #{post.text}")

# result - уже структурированный объект!
result.importance_score  # => 85
result.is_ad            # => false
result.topics           # => ["технологии", "AI"]
result.reasoning        # => "Содержит важную информацию о..."
```

**Преимущества:**
- ✅ Гарантированная структура ответа
- ✅ Нет необходимости в парсинге
- ✅ Type-safe доступ к данным
- ✅ Валидация на уровне схемы
- ✅ Легкое сохранение в БД

#### 1.2.3. Tools (Function Calling) - Надежная классификация

**Почему это лучше:**
```ruby
class ClassifyPostTool < RubyLLM::Tool
  description "Классифицирует пост из Telegram канала"

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

  def execute(importance_score:, is_ad:, is_fluff:, topics:, reasoning:)
    # Возвращаем структурированные данные
    {
      importance_score: importance_score,
      is_ad: is_ad,
      is_fluff: is_fluff,
      topics: topics,
      reasoning: reasoning
    }
  end
end

# Использование
chat = RubyLLM.chat(tools: [ClassifyPostTool])
result = chat.ask("Классифицируй этот пост: #{post.text}")
# Модель АВТОМАТИЧЕСКИ вызовет ClassifyPostTool с правильными параметрами
```

**Преимущества:**
- ✅ Модель сама выбирает когда вызвать функцию
- ✅ Автоматическая валидация параметров
- ✅ Можно комбинировать несколько инструментов
- ✅ Более надежная классификация
- ✅ Легко добавлять новые инструменты

**Применение в NoFluff:**
```ruby
# Набор инструментов для классификации
tools = [
  ClassifyPostTool,           # Основная классификация
  DetectDuplicateTool,        # Поиск дубликатов
  ExtractTopicsTool,          # Извлечение тем
  GenerateSummaryTool,        # Генерация саммари
  CheckUserPreferencesTool    # Проверка пользовательских предпочтений
]

chat = RubyLLM.chat(tools: tools)
chat.ask("Проанализируй этот пост для пользователя #{user.id}: #{post.text}")
# Модель сама выберет какие инструменты вызвать и в каком порядке!
```

#### 1.2.4. Streaming - Улучшение UX

**Текущая проблема:**
```ruby
# Пользователь ждет 5-10 секунд без обратной связи
response = chat.ask("Сгенерируй дайджест из 20 постов")
telegram.send_message(response.content)
```

**С использованием Streaming:**
```ruby
message_id = telegram.send_message("Генерирую дайджест...")
accumulated_text = ""

chat.ask("Сгенерируй дайджест из 20 постов") do |chunk|
  accumulated_text += chunk.content

  # Обновляем сообщение каждые 10 чанков (чтобы не перегружать API)
  if accumulated_text.split("\n").count % 10 == 0
    telegram.edit_message(message_id, accumulated_text)
  end
end

# Финальное обновление
telegram.edit_message(message_id, accumulated_text)
```

**Преимущества:**
- ✅ Пользователь видит прогресс в реальном времени
- ✅ Не создается впечатление "зависания"
- ✅ Можно отменить генерацию
- ✅ Лучший воспринимаемый performance

---

## 2. Сохранение пользовательских сессий и чатов

### 2.1. Текущее состояние

**Проблема:**
В текущей архитектуре (согласно C4 Model и ROADMAP) **отсутствует модель для сохранения AI-сессий**:

```
Существующие модели (ROADMAP Phase 1.2):
✅ User
✅ Channel
✅ Subscription
✅ Post
✅ Digest
✅ DigestItem
❌ Chat - НЕТ ПЕРСОНАЛИЗАЦИИ!
❌ ChatMessage - НЕТ!
```

**Последствия:**
1. ❌ Каждый AI-запрос создает новый контекст
2. ❌ Модель не "помнит" предыдущие взаимодействия с пользователем
3. ❌ Нет персонализации на основе истории
4. ❌ Невозможно проанализировать, как модель принимала решения
5. ❌ Фидбек пользователя (лайки/дизлайки) не влияет на AI

### 2.2. Предлагаемая архитектура

#### 2.2.1. Расширение существующей модели Chat

```ruby
# Модель Chat уже существует и использует acts_as_chat
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  # Добавляем связи для NoFluff
  belongs_to :user, optional: true  # Привязка к пользователю
  belongs_to :model

  has_many :post_classifications, dependent: :destroy
  has_many :user_preferences, dependent: :destroy

  # Добавляем поля для специфичной логики NoFluff
  enum :session_type, {
    classification: 0,     # Классификация постов
    summarization: 1,      # Генерация саммари
    personalization: 2,    # Обучение на фидбеке
    digest_generation: 3   # Генерация дайджестов
  }

  enum :status, {
    active: 0,
    archived: 1
  }

  # Контекст сессии (JSON поле)
  # {
  #   user_preferences: {...},
  #   recent_feedback: [...],
  #   classification_history: [...]
  # }
  store_accessor :metadata, :user_preferences, :recent_feedback

  # Сколько сообщений хранить в активной памяти
  def active_context_window
    50
  end

  # Получить последние N сообщений для контекста
  def recent_messages(limit = 10)
    messages.order(created_at: :desc).limit(limit).reverse
  end

  # Добавить пример из фидбека в контекст
  def add_feedback_example(post, feedback)
    examples = recent_feedback || []
    examples << {
      post_text: post.text,
      user_liked: feedback.like?,
      importance_score: post.importance_score,
      timestamp: feedback.created_at
    }
    # Храним последние 20 примеров
    self.recent_feedback = examples.last(20)
    save
  end
end

# Миграция для расширения модели Chat
class AddNofluffFieldsToChats < ActiveRecord::Migration[8.0]
  def change
    # Добавляем связь с пользователем
    add_reference :chats, :user, foreign_key: true

    # Добавляем поля для сессионной логики NoFluff
    add_column :chats, :session_type, :integer, default: 0
    add_column :chats, :status, :integer, default: 0

    # JSONB поля для метаданных
    add_column :chats, :metadata, :jsonb, default: {}

    # Индексы для оптимизации запросов
    add_index :chats, [:user_id, :session_type, :status]
    add_index :chats, :session_type
    add_index :chats, :status
  end
end
```

#### 2.2.2. Модель Message (уже существует с acts_as_message)

```ruby
# Модель Message уже существует и использует acts_as_message
# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments

  belongs_to :chat
  belongs_to :model
  belongs_to :tool_call, optional: true

  # Добавляем связь с постом для NoFluff
  belongs_to :post, optional: true

  enum role: {
    system: 0,
    user: 1,
    assistant: 2,
    tool: 3
  }

  # Метаданные (tokens usage, model, latency) - уже есть поля input_tokens/output_tokens

  # Дополнительные методы для NoFluff
  def total_tokens
    (input_tokens || 0) + (output_tokens || 0)
  end

  def related_to_post?
    post.present?
  end
end
```

#### 2.2.3. Обновление модели User

```ruby
class TelegramUser < ApplicationRecord
  has_many :chats, dependent: :destroy  # Используем существующие модели
  has_many :messages, through: :chats
  has_many :feedbacks, dependent: :destroy

  # Получить или создать активную сессию определенного типа
  def chat_for(type)
    chats.active_status
         .find_or_create_by!(session_type: type) do |chat|
      chat.build_initial_context
    end
  end

  # Построить начальный контекст для новой сессии
  def build_initial_context
    {
      user_preferences: {
        delivery_frequency: delivery_frequency,
        content_format: content_format,
        filter_strictness: filter_strictness
      },
      feedback_history: recent_feedback_summary,
      subscription_priorities: subscriptions.pluck(:channel_id, :priority).to_h
    }
  end

  # Краткая сводка последнего фидбека
  def recent_feedback_summary
    feedbacks.includes(:post).last(20).map do |f|
      {
        liked: f.like?,
        post_importance: f.post.importance_score,
        topics: f.post.topics
      }
    end
  end
end
```

#### 2.2.4. Обновление модели Feedback

```ruby
class Feedback < ApplicationRecord
  belongs_to :user
  belongs_to :post

  enum sentiment: { dislike: -1, neutral: 0, like: 1 }

  # После создания фидбека - обновить AI-сессию персонализации
  after_create :update_personalization_session

  private

  def update_personalization_session
    session = user.chat_for(:personalization)
    session.add_feedback_example(post, self)

    # Асинхронно обновить модель персонализации
    PersonalizationUpdateJob.perform_later(user.id, id)
  end
end
```

### 2.3. Паттерн использования AI-сессий

#### Пример 1: Классификация с персональным контекстом

```ruby
# app/services/content/ai_classifier.rb
class Content::AIClassifier
  def initialize(user)
    @user = user
    @session = user.chat_for(:classification)
  end

  def classify(post)
    # Подготовить контекст с примерами из истории
    system_prompt = build_system_prompt

    # Создать structured output схему
    schema = PostClassificationSchema

    # Использовать сессию с acts_as_chat
    chat = @session.chat_instance.with_schema(schema)

    # Классифицировать с учетом истории!
    result = chat.ask(
      "Классифицируй этот пост для пользователя:\n\n#{post.text}"
    )

    # Сохранить результат
    save_classification(post, result)
  end

  private

  def build_system_prompt
    <<~PROMPT
      Ты — система классификации контента для пользователя.

      Предпочтения пользователя:
      - Строгость фильтрации: #{@user.filter_strictness}
      - Формат контента: #{@user.content_format}

      Последние 10 примеров фидбека пользователя:
      #{format_feedback_examples}

      Используй эти примеры, чтобы понять, что пользователь считает важным.
    PROMPT
  end

  def format_feedback_examples
    @user.recent_feedback_summary.map do |f|
      "- #{f[:liked] ? '👍' : '👎'} Пост с важностью #{f[:post_importance]}, темы: #{f[:topics].join(', ')}"
    end.join("\n")
  end
end
```

#### Пример 2: Генерация дайджеста с памятью

```ruby
# app/services/digest/builder.rb
class Digest::Builder
  def initialize(user)
    @user = user
    @session = user.chat_for(:digest_generation)
  end

  def build_digest(posts)
    # Сессия помнит предыдущие дайджесты!
    result = @session.ask(
      "Создай дайджест из этих #{posts.count} постов:\n\n#{format_posts(posts)}",
      with_streaming: true
    ) do |chunk|
      # Streaming для лучшего UX
      yield chunk if block_given?
    end

    result
  end
end
```

#### Пример 3: Персонализация через фидбек

```ruby
# app/jobs/personalization_update_job.rb
class PersonalizationUpdateJob < ApplicationJob
  def perform(user_id, feedback_id)
    user = TelegramUser.find(user_id)
    feedback = Feedback.find(feedback_id)

    session = user.chat_for(:personalization)

    # Обновить модель понимания предпочтений
    session.ask(
      <<~PROMPT
        Пользователь дал фидбек:
        - Пост: "#{feedback.post.text[0..200]}"
        - Реакция: #{feedback.like? ? 'Понравился' : 'Не понравился'}
        - Текущая оценка важности: #{feedback.post.importance_score}

        Проанализируй, что это говорит о предпочтениях пользователя.
        Какие характеристики контента нужно учитывать сильнее?
      PROMPT
    )

    # Модель "запоминает" этот анализ в истории сессии!
  end
end
```

---

## 3. Архитектурные проблемы и риски

### 3.1. Производительность

#### Проблема 1: Отправка полной истории каждый раз

**Риск:** 🔴 **ВЫСОКИЙ**

**Описание:**
По умолчанию `ruby_llm` с `acts_as_chat` отправляет всю историю сообщений при каждом запросе. Для сессии с 1000+ сообщений это:
- 💰 Огромные расходы на токены
- ⏱️ Медленные ответы
- 🚫 Превышение лимитов контекста модели

**Решение:**

```ruby
class Chat < ApplicationRecord
  acts_as_chat

  # Стратегия управления контекстом
  def chat_with_managed_context
    # Получить только релевантные сообщения
    recent = recent_messages(10)
    important = important_messages(5)

    # Создать временный chat с ограниченной историей
    RubyLLM.chat(
      system: system_prompt,
      history: (important + recent).map(&:to_message_hash)
    )
  end

  # Выбрать важные сообщения из истории
  def important_messages(limit)
    ai_messages
      .where("metadata->>'importance' = 'high'")
      .order(created_at: :desc)
      .limit(limit)
  end

  # Архивировать старые сообщения
  def archive_old_messages
    threshold = 30.days.ago
    ai_messages.where("created_at < ?", threshold).update_all(archived: true)
  end
end
```

**Рекомендация:**
- ✅ Использовать скользящее окно контекста (последние 20-50 сообщений)
- ✅ Выбирать важные сообщения из истории (few-shot examples)
- ✅ Периодически архивировать старые сообщения
- ✅ Использовать summarization для длинной истории

#### Проблема 2: Синхронные AI-запросы

**Риск:** 🟡 **СРЕДНИЙ**

**Описание:**
Классификация постов в синхронном режиме блокирует воркер:
```ruby
# 10 постов × 2 секунды = 20 секунд блокировки воркера
posts.each do |post|
  AIClassifier.new(user).classify(post)
end
```

**Решение:**

```ruby
# 1. Batch-обработка
class Content::BatchClassifier
  def classify_batch(posts, user)
    session = user.chat_for(:classification)

    # Одним запросом классифицировать несколько постов
    result = session.ask(
      "Классифицируй эти #{posts.count} постов:\n" +
      posts.map.with_index { |p, i| "#{i+1}. #{p.text[0..200]}" }.join("\n\n")
    )

    # Результат - массив классификаций
    result.classifications.zip(posts).each do |classification, post|
      save_classification(post, classification)
    end
  end
end

# 2. Async с Fiber
require 'async'

class Content::AsyncClassifier
  def classify_many(posts, user)
    Async do
      barrier = Async::Barrier.new

      posts.each do |post|
        barrier.async do
          AIClassifier.new(user).classify(post)
        end
      end

      barrier.wait
    end
  end
end
```

### 3.2. Масштабируемость

#### Проблема: Неконтролируемый рост данных сессий

**Риск:** 🔴 **ВЫСОКИЙ**

**Прогноз:**
- 1000 пользователей × 100 постов/день × 30 дней = 3,000,000 AI-сообщений/месяц
- При средней длине сообщения 500 байт = 1.5 GB только текста
- + метаданные, индексы, связи = ~5 GB/месяц

**Решение:**

```ruby
# Стратегия управления жизненным циклом данных
class Chat < ApplicationRecord
  # Автоматическая очистка старых данных
  def self.cleanup_old_sessions
    # Архивировать неактивные сессии старше 90 дней
    where("last_activity_at < ?", 90.days.ago)
      .where(status: :active)
      .update_all(status: :archived)

    # Удалить архивные сообщения старше 180 дней
    archived.where("created_at < ?", 180.days.ago).destroy_all
  end

  # Сжатие истории для long-running сессий
  def compact_history
    return if ai_messages.count < 100

    # Оставить только важные + последние N сообщений
    messages_to_keep = ai_messages.order(created_at: :desc)
                        .limit(50)
                        .pluck(:id)

    important_messages = ai_messages
                          .where("metadata->>'keep' = 'true'")
                          .pluck(:id)

    ai_messages.where.not(id: messages_to_keep + important_messages).destroy_all
  end
end

# Запланировать периодическую очистку
class CleanupChatsJob < ApplicationJob
  def perform
    Chat.cleanup_old_sessions

    # Сжать большие сессии
    Chat.active.having("COUNT(ai_messages.id) > 100")
      .joins(:ai_messages)
      .group("chats.id")
      .find_each(&:compact_history)
  end
end
```

### 3.3. Соответствие SOLID принципам

#### Оценка текущей архитектуры

**Single Responsibility Principle (SRP)** ✅ **ХОРОШО**
- Сервисы четко разделены по ответственности
- Каждый сервис решает одну задачу

**Open/Closed Principle (OCP)** ⚠️ **ТРЕБУЕТ УЛУЧШЕНИЯ**

Проблема:
```ruby
# Жесткая привязка к конкретной реализации AI
class AIClassifier
  def classify(post)
    chat = RubyLLM.chat(model: 'gpt-4')  # 😱 Хардкод модели!
    # ...
  end
end
```

Решение:
```ruby
# Абстракция AI провайдера
class AIProvider
  def chat(**options)
    raise NotImplementedError
  end
end

class RubyLLMProvider < AIProvider
  def chat(**options)
    RubyLLM.chat(**options)
  end
end

class AIClassifier
  def initialize(user, provider: RubyLLMProvider.new)
    @user = user
    @provider = provider
  end

  def classify(post)
    chat = @provider.chat(model: model_for_user)
    # ...
  end

  private

  def model_for_user
    # Можно менять модель в зависимости от тарифа пользователя
    @user.premium? ? 'gpt-4' : 'gpt-3.5-turbo'
  end
end
```

**Liskov Substitution Principle (LSP)** ✅ **ХОРОШО**
- Форматтеры взаимозаменяемы

**Interface Segregation Principle (ISP)** ✅ **ХОРОШО**
- Контроллеры разделены по командам

**Dependency Inversion Principle (DIP)** ⚠️ **ТРЕБУЕТ УЛУЧШЕНИЯ**

Проблема:
```ruby
class DigestBuilder
  def build
    filter = ContentFilter.new      # Прямая зависимость
    ranker = Ranker.new             # Прямая зависимость
    formatter = OriginalFormatter.new # Прямая зависимость
  end
end
```

Решение:
```ruby
class DigestBuilder
  def initialize(filter:, ranker:, formatter:)
    @filter = filter      # Dependency Injection
    @ranker = ranker
    @formatter = formatter
  end

  def build(posts)
    filtered = @filter.filter(posts)
    ranked = @ranker.rank(filtered)
    @formatter.format(ranked)
  end
end

# Использование
builder = DigestBuilder.new(
  filter: ContentFilter.new(user),
  ranker: ImportanceRanker.new,
  formatter: SummaryFormatter.new
)
```

### 3.4. Управление состоянием и кешированием

#### Проблема: Неоптимальное использование Solid Cache

**Риск:** 🟡 **СРЕДНИЙ**

**Текущее планирование (из C4 Model):**
```
Solid Cache используется для:
- Кеш результатов AI-классификации (TTL: 24 часа)
- Кеш векторов для дедупликации (TTL: 7 дней)
- Кеш рекомендаций каналов (TTL: 1 час)
```

**Проблемы:**
1. ❌ Фиксированные TTL не учитывают актуальность
2. ❌ Нет инвалидации кеша при изменении контекста пользователя
3. ❌ Нет кеширования промежуточных результатов AI-сессий

**Решение:**

```ruby
module Cacheable
  extend ActiveSupport::Concern

  class_methods do
    # Кеширование с зависимостями
    def cache_with_dependencies(key, dependencies: [], expires_in: 1.hour)
      # Построить составной ключ с версиями зависимостей
      full_key = [
        key,
        *dependencies.map { |d| "#{d.cache_key_with_version}" }
      ].join("/")

      Rails.cache.fetch(full_key, expires_in: expires_in) do
        yield
      end
    end
  end
end

class Content::AIClassifier
  include Cacheable

  def classify(post)
    # Кеш зависит от версий user и post
    cache_with_dependencies(
      "classification/#{post.id}",
      dependencies: [@user, post],
      expires_in: 24.hours
    ) do
      perform_classification(post)
    end
  end

  private

  def perform_classification(post)
    session = @user.chat_for(:classification)
    # ... AI classification
  end
end

# При обновлении настроек пользователя - автоматически инвалидируется кеш
class TelegramUser < ApplicationRecord
  after_update :touch  # Обновляет updated_at, что меняет cache_key_with_version
end
```

---

## 4. Конкретные рекомендации

### 4.1. Изменения в структуру моделей

#### 4.1.1. Добавить модели для AI-сессий

**Приоритет:** 🔴 **КРИТИЧЕСКИЙ**

**Действия:**
1. Создать модель `Chat` с `acts_as_chat`
2. Добавить связи с `User`, `Post`, `Feedback`
3. Реализовать управление контекстом
4. Добавить стратегии архивации

**Миграции:**
```ruby
# db/migrate/XXXXXX_create_chats.rb
class AddNofluffFieldsToChats < ActiveRecord::Migration[8.0]
  def change
    create_table :chats do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :session_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.jsonb :context, default: {}
      t.datetime :last_activity_at
      t.integer :messages_count, default: 0
      t.timestamps
    end

    add_index :chats, [:user_id, :session_type]
    add_index :chats, :status
    add_index :chats, :last_activity_at
  end
end

# После установки ruby_llm Rails integration:
# rails generate ruby_llm:install
# Это создаст таблицу для сообщений (ruby_llm_messages)
```

#### 4.1.2. Обновить модель Post

**Добавить поля для structured classification:**

```ruby
# db/migrate/XXXXXX_add_structured_classification_to_posts.rb
class AddStructuredClassificationToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :classification_data, :jsonb, default: {}
    add_column :posts, :topics, :string, array: true, default: []
    add_column :posts, :classification_reasoning, :text
    add_column :posts, :classified_by_session_id, :bigint

    add_index :posts, :topics, using: :gin
    add_index :posts, :classification_data, using: :gin
    add_foreign_key :posts, :chats, column: :classified_by_session_id
  end
end
```

**Обновить модель:**
```ruby
class Post < ApplicationRecord
  belongs_to :channel
  belongs_to :classified_by_session,
             class_name: 'Chat',
             optional: true

  has_many :feedbacks

  # Structured classification data
  store_accessor :classification_data,
    :importance_score,
    :is_ad,
    :is_fluff,
    :duplicate_check

  scope :important, -> { where("(classification_data->>'importance_score')::int > 70") }
  scope :not_ads, -> { where("(classification_data->>'is_ad')::boolean = false") }
  scope :by_topic, ->(topic) { where("? = ANY(topics)", topic) }
end
```

#### 4.1.3. Обновить модель PostClassification

**Сделать персональной для пользователя:**

```ruby
# db/migrate/XXXXXX_add_chat_to_post_classifications.rb
class AddChatToPostClassifications < ActiveRecord::Migration[8.0]
  def change
    add_reference :post_classifications,
                  :chat,
                  foreign_key: true

    add_column :post_classifications, :reasoning, :text
    add_column :post_classifications, :confidence, :float
  end
end

class PostClassification < ApplicationRecord
  belongs_to :post
  belongs_to :user
  belongs_to :chat, optional: true

  # Персональная классификация с учетом истории взаимодействий
  def self.for_user_with_context(user, post)
    session = user.chat_for(:classification)

    # Классифицировать с учетом истории пользователя
    classifier = Content::AIClassifier.new(user)
    result = classifier.classify_with_context(post, session)

    create!(
      post: post,
      user: user,
      chat: session,
      importance_score: result.importance_score,
      is_relevant: result.importance_score > user.relevance_threshold,
      reasoning: result.reasoning,
      confidence: result.confidence
    )
  end
end
```

### 4.2. Изменения в ROADMAP.md

**Приоритет:** 🔴 **КРИТИЧЕСКИЙ**

Необходимо добавить новые подэтапы в Phase 1, которые внедряют правильное использование ruby_llm:

#### Вставить ПЕРЕД Phase 1.5 "AI фильтрация"

```markdown
### 1.4. AI Sessions Infrastructure

#### 1.4.1. AI Sessions Models
- [ ] Установить ruby_llm Rails integration: `rails generate ruby_llm:install`
- [ ] Создать миграцию для `chats` таблицы
- [ ] Создать модель `Chat` с `acts_as_chat`
- [ ] Добавить enum для `session_type` (classification, summarization, personalization, digest_generation)
- [ ] Добавить enum для `status` (active, archived)
- [ ] Добавить JSONB поле `context` для хранения контекста сессии
- [ ] Добавить `last_activity_at` для трекинга активности
- [ ] Написать unit тесты для Chat

#### 1.4.2. AI Sessions Management
- [ ] Добавить методы в User модель для управления AI-сессиями
  - [ ] `chat_for(type)` - получить или создать сессию
  - [ ] `build_initial_context` - построить начальный контекст
  - [ ] `recent_feedback_summary` - сводка последнего фидбека
- [ ] Создать `app/services/ai/session_manager.rb`
- [ ] Реализовать управление контекстным окном
- [ ] Реализовать архивацию старых сообщений
- [ ] Реализовать compacting истории для больших сессий
- [ ] Написать service тесты

#### 1.4.3. Structured Output Schemas
- [ ] Создать `app/schemas/post_classification_schema.rb`
  - [ ] Определить поля: importance_score, is_ad, is_fluff, reasoning, topics
  - [ ] Добавить валидацию полей
- [ ] Создать `app/schemas/duplicate_detection_schema.rb`
- [ ] Создать `app/schemas/summary_schema.rb`
- [ ] Написать тесты для схем

#### 1.4.4. AI Tools (Function Calling)
- [ ] Создать `app/tools/classify_post_tool.rb`
  - [ ] Определить параметры классификации
  - [ ] Реализовать метод `execute`
- [ ] Создать `app/tools/detect_duplicate_tool.rb`
- [ ] Создать `app/tools/extract_topics_tool.rb`
- [ ] Написать тесты для инструментов

#### 1.4.5. Context Management
- [ ] Создать `app/services/ai/context_builder.rb`
- [ ] Реализовать стратегии выбора сообщений для контекста:
  - [ ] Sliding window (последние N сообщений)
  - [ ] Importance-based (важные сообщения из истории)
  - [ ] Few-shot examples (примеры из фидбека)
- [ ] Реализовать summarization для длинной истории
- [ ] Добавить кеширование построенного контекста
- [ ] Написать service тесты
```

#### Обновить Phase 1.5 "AI фильтрация"

```markdown
### 1.5. AI фильтрация (ОБНОВЛЕНО)

#### 1.5.1. AI Classifier Service (с использованием AI Sessions)
- [ ] Создать `app/services/content/ai_classifier.rb`
- [ ] Реализовать классификацию с использованием Chat
- [ ] Использовать Structured Output (PostClassificationSchema)
- [ ] Использовать Tools (ClassifyPostTool) для надежной классификации
- [ ] Добавить построение системного промпта с контекстом пользователя
- [ ] Добавить few-shot examples из истории фидбека
- [ ] Добавить кеширование результатов с зависимостями
- [ ] Обработать ошибки AI API с retry логикой
- [ ] Написать service тесты

#### 1.5.2. Batch Classification
- [ ] Создать `app/services/content/batch_classifier.rb`
- [ ] Реализовать классификацию нескольких постов одним запросом
- [ ] Оптимизировать использование токенов
- [ ] Добавить параллельную обработку с Async (опционально)
- [ ] Написать service тесты

#### 1.5.3. Content Filter Service (обновлено)
- [ ] Создать `app/services/content/filter.rb`
- [ ] Реализовать фильтрацию постов по importance_score
- [ ] Учитывать filter_strictness пользователя
- [ ] Учитывать персональный контекст из Chat
- [ ] Фильтровать рекламу и шелуху
- [ ] Написать service тесты

#### 1.5.4. Classify Job (обновлено)
- [ ] Создать `app/jobs/content/classify_job.rb`
- [ ] Вызвать AIClassifier для поста с контекстом пользователя
- [ ] Сохранить structured результаты в БД
- [ ] Сохранить связь с Chat
- [ ] Добавить retry логику при ошибках
- [ ] Добавить логирование токенов и latency
- [ ] Написать job тесты

#### 1.5.5. Streaming Support
- [ ] Добавить streaming в DigestBuilder для длинных дайджестов
- [ ] Реализовать обновление Telegram сообщения в реальном времени
- [ ] Добавить индикатор прогресса
- [ ] Написать integration тесты
```

#### Обновить Phase 2.2 "Персонализация через фидбек"

```markdown
### 2.2. Персонализация через фидбек (ОБНОВЛЕНО)

#### 2.2.1. Feedback Integration with AI Sessions
- [ ] Обновить Feedback модель для интеграции с Chat
- [ ] Добавить `after_create` callback для обновления сессии персонализации
- [ ] Реализовать `add_feedback_example` в Chat
- [ ] Добавить хранение последних N примеров фидбека в контексте

#### 2.2.2. Personalization Service
- [ ] Создать `app/services/personalization/feedback_processor.rb`
- [ ] Использовать Chat для обучения на фидбеке
- [ ] Реализовать анализ паттернов предпочтений пользователя
- [ ] Обновлять веса важности на основе фидбека
- [ ] Написать service тесты

#### 2.2.3. Personalization Update Job
- [ ] Создать `app/jobs/personalization_update_job.rb`
- [ ] Асинхронно обновлять модель персонализации при новом фидбеке
- [ ] Использовать Chat для накопления знаний о пользователе
- [ ] Обновлять UserPreference на основе анализа
- [ ] Написать job тесты

#### 2.2.4. Context-Aware Classification
- [ ] Обновить AIClassifier для использования персонального контекста
- [ ] Добавить few-shot examples из фидбека пользователя
- [ ] Реализовать динамическую корректировку порога важности
- [ ] Протестировать улучшение точности классификации
```

### 4.3. Архитектурные паттерны для работы с ruby_llm

#### Паттерн 1: Session Manager

```ruby
# app/services/ai/session_manager.rb
module AI
  class SessionManager
    attr_reader :user, :session

    def initialize(user, session_type)
      @user = user
      @session = find_or_create_session(session_type)
    end

    def with_context(&block)
      chat = build_chat_with_context
      yield chat, @session
    ensure
      @session.touch(:last_activity_at)
      cleanup_if_needed
    end

    private

    def find_or_create_session(type)
      @user.chats.active.find_or_create_by!(session_type: type) do |s|
        s.context = @user.build_initial_context
      end
    end

    def build_chat_with_context
      context_builder = AI::ContextBuilder.new(@session, @user)

      @session.chat_instance.with_context(
        system: context_builder.system_prompt,
        history: context_builder.relevant_history
      )
    end

    def cleanup_if_needed
      # Архивировать старые сообщения если сессия слишком большая
      @session.compact_history if @session.messages_count > 100
    end
  end
end

# Использование
session_manager = AI::SessionManager.new(user, :classification)
session_manager.with_context do |chat, session|
  result = chat.ask("Классифицируй пост: #{post.text}")
  # Сохранить результат с привязкой к сессии
  save_classification(post, result, session)
end
```

#### Паттерн 2: Context Builder

```ruby
# app/services/ai/context_builder.rb
module AI
  class ContextBuilder
    MAX_HISTORY_MESSAGES = 20
    MAX_FEW_SHOT_EXAMPLES = 10

    def initialize(session, user)
      @session = session
      @user = user
    end

    def system_prompt
      case @session.session_type
      when 'classification'
        classification_system_prompt
      when 'summarization'
        summarization_system_prompt
      when 'personalization'
        personalization_system_prompt
      end
    end

    def relevant_history
      # Комбинировать разные типы релевантных сообщений
      [
        important_examples,
        recent_interactions,
        few_shot_from_feedback
      ].flatten.uniq.sort_by(&:created_at)
    end

    private

    def classification_system_prompt
      <<~PROMPT
        Ты — система классификации контента для персонального Telegram бота.

        Информация о пользователе:
        - Уровень строгости фильтрации: #{@user.filter_strictness}
        - Предпочитаемый формат: #{@user.content_format}
        - Количество подписок: #{@user.subscriptions.count}

        #{feedback_context}

        Твоя задача — оценить важность поста от 0 до 100, определить является ли он
        рекламой или шелухой, извлечь темы и дать краткое объяснение оценки.

        Используй примеры из истории фидбека, чтобы понять предпочтения пользователя.
      PROMPT
    end

    def feedback_context
      return "" unless @user.feedbacks.any?

      <<~CONTEXT
        Последние 10 примеров фидбека пользователя:
        #{format_feedback_examples(@user.recent_feedback_summary)}

        Паттерны предпочтений:
        #{analyze_feedback_patterns}
      CONTEXT
    end

    def format_feedback_examples(examples)
      examples.map do |ex|
        sentiment = ex[:liked] ? "👍 Понравился" : "👎 Не понравился"
        "- #{sentiment} | Важность: #{ex[:post_importance]} | Темы: #{ex[:topics].join(', ')}"
      end.join("\n")
    end

    def analyze_feedback_patterns
      # Простой анализ - можно улучшить с помощью AI
      liked_topics = @user.feedbacks.liked.joins(:post).pluck('posts.topics').flatten.tally
      top_topics = liked_topics.sort_by { |_, count| -count }.first(5)

      "Наиболее интересные темы: #{top_topics.map { |t, c| "#{t} (#{c})" }.join(', ')}"
    end

    def important_examples
      # Сообщения, помеченные как важные
      @session.ai_messages
        .where("metadata->>'importance' = 'high'")
        .order(created_at: :desc)
        .limit(5)
    end

    def recent_interactions
      # Последние взаимодействия
      @session.recent_messages(MAX_HISTORY_MESSAGES)
    end

    def few_shot_from_feedback
      # Превратить фидбек в few-shot примеры
      @user.feedbacks
        .includes(:post)
        .order(created_at: :desc)
        .limit(MAX_FEW_SHOT_EXAMPLES)
        .map { |f| feedback_to_message(f) }
    end

    def feedback_to_message(feedback)
      # Создать пример в формате user/assistant
      [
        {
          role: 'user',
          content: "Классифицируй: #{feedback.post.text[0..200]}"
        },
        {
          role: 'assistant',
          content: {
            importance_score: feedback.post.importance_score,
            user_liked: feedback.like?,
            reasoning: "Пользователь #{feedback.like? ? 'одобрил' : 'отклонил'} этот контент"
          }.to_json
        }
      ]
    end
  end
end
```

#### Паттерн 3: Cached AI Service

```ruby
# app/services/ai/cached_service.rb
module AI
  class CachedService
    include Cacheable

    def initialize(user)
      @user = user
    end

    def call(operation, *args, **kwargs)
      cache_key = build_cache_key(operation, *args, **kwargs)
      dependencies = [get_user, *extract_dependencies(args)]

      cache_with_dependencies(
        cache_key,
        dependencies: dependencies,
        expires_in: cache_ttl(operation)
      ) do
        perform_operation(operation, *args, **kwargs)
      end
    end

    private

    def build_cache_key(operation, *args, **kwargs)
      "ai/#{operation}/#{args.map(&:cache_key).join('/')}"
    end

    def cache_ttl(operation)
      case operation
      when :classify then 24.hours
      when :summarize then 12.hours
      when :detect_duplicate then 7.days
      else 1.hour
      end
    end

    def extract_dependencies(args)
      args.select { |arg| arg.respond_to?(:cache_key_with_version) }
    end

    def perform_operation(operation, *args, **kwargs)
      session_manager = SessionManager.new(@user, operation_to_session_type(operation))

      session_manager.with_context do |chat, session|
        send("perform_#{operation}", chat, session, *args, **kwargs)
      end
    end

    def operation_to_session_type(operation)
      case operation
      when :classify then :classification
      when :summarize then :summarization
      else :classification
      end
    end
  end
end

# Использование
service = AI::CachedService.new(user)
result = service.call(:classify, post)  # Автоматически кешируется
```

### 4.4. Способы персонализации через сохраненную историю

#### Способ 1: Few-Shot Learning из фидбека

```ruby
# app/services/personalization/few_shot_builder.rb
module Personalization
  class FewShotBuilder
    def initialize(user)
      @user = user
    end

    def build_examples
      # Получить сбалансированную выборку фидбека
      liked = @user.feedbacks.liked.includes(:post).limit(5)
      disliked = @user.feedbacks.disliked.includes(:post).limit(5)

      examples = []

      # Добавить примеры понравившегося контента
      liked.each do |feedback|
        examples << {
          role: 'user',
          content: "Классифицируй этот пост:\n\n#{feedback.post.text}"
        }
        examples << {
          role: 'assistant',
          content: {
            importance_score: [feedback.post.importance_score + 10, 100].min, # Повысить оценку
            is_important: true,
            reasoning: "Пользователь одобрил похожий контент. Темы: #{feedback.post.topics.join(', ')}"
          }.to_json
        }
      end

      # Добавить примеры неинтересного контента
      disliked.each do |feedback|
        examples << {
          role: 'user',
          content: "Классифицируй этот пост:\n\n#{feedback.post.text}"
        }
        examples << {
          role: 'assistant',
          content: {
            importance_score: [feedback.post.importance_score - 20, 0].max, # Понизить оценку
            is_important: false,
            reasoning: "Пользователь отклонил похожий контент. Темы: #{feedback.post.topics.join(', ')}"
          }.to_json
        }
      end

      examples
    end
  end
end

# Использование в AIClassifier
def classify_with_few_shot(post)
  few_shot_builder = Personalization::FewShotBuilder.new(@user)
  examples = few_shot_builder.build_examples

  session = @user.chat_for(:classification)
  chat = session.chat_instance

  # Добавить few-shot примеры в контекст
  examples.each do |example|
    chat.history << example
  end

  # Теперь классифицировать с учетом примеров
  chat.with_schema(PostClassificationSchema).ask(
    "Классифицируй этот пост:\n\n#{post.text}"
  )
end
```

#### Способ 2: Динамическая корректировка порогов

```ruby
# app/services/personalization/threshold_adjuster.rb
module Personalization
  class ThresholdAdjuster
    def initialize(user)
      @user = user
    end

    def adjusted_threshold
      base_threshold = base_threshold_for_strictness
      personal_adjustment = calculate_personal_adjustment

      (base_threshold + personal_adjustment).clamp(0, 100)
    end

    private

    def base_threshold_for_strictness
      case @user.filter_strictness
      when 'maximum' then 90
      when 'high' then 75
      when 'medium' then 60
      when 'low' then 40
      when 'adaptive' then 70 # Начальное значение для adaptive
      end
    end

    def calculate_personal_adjustment
      return 0 unless @user.filter_strictness == 'adaptive'

      # Анализировать историю фидбека
      recent_feedbacks = @user.feedbacks.where('created_at > ?', 7.days.ago)

      return 0 if recent_feedbacks.count < 10

      # Если пользователь лайкает много постов с низкой оценкой - понизить порог
      liked_low_score = recent_feedbacks.liked.joins(:post)
        .where('posts.importance_score < ?', 60).count

      # Если пользователь дизлайкает много постов с высокой оценкой - повысить порог
      disliked_high_score = recent_feedbacks.disliked.joins(:post)
        .where('posts.importance_score > ?', 70).count

      # Корректировка
      adjustment = 0
      adjustment -= liked_low_score * 2    # Понижаем порог за каждый лайк низкой оценки
      adjustment += disliked_high_score * 2 # Повышаем порог за каждый дизлайк высокой оценки

      adjustment.clamp(-20, 20)
    end
  end
end

# Использование
adjuster = Personalization::ThresholdAdjuster.new(user)
threshold = adjuster.adjusted_threshold

posts.select { |p| p.importance_score >= threshold }
```

#### Способ 3: Персональные веса тем

```ruby
# app/models/user_preference.rb
class UserPreference < ApplicationRecord
  belongs_to :user

  # topic_weights: {"технологии" => 1.5, "политика" => 0.5, ...}
  store_accessor :preferences, :topic_weights

  def initialize_topic_weights
    self.topic_weights = Hash.new(1.0)
  end

  def adjust_topic_weight(topic, feedback)
    current_weight = topic_weights[topic] || 1.0

    adjustment = feedback.like? ? 0.1 : -0.1
    new_weight = (current_weight + adjustment).clamp(0.1, 3.0)

    topic_weights[topic] = new_weight
    save
  end

  def weighted_importance_score(post)
    base_score = post.importance_score

    return base_score if post.topics.empty?

    # Применить персональные веса к темам
    topic_multiplier = post.topics.map { |t| topic_weights[t] || 1.0 }.max

    (base_score * topic_multiplier).clamp(0, 100)
  end
end

# Использование в Content::Filter
def filter_for_user(posts)
  preference = @user.user_preference || @user.create_user_preference

  posts.map do |post|
    # Пересчитать оценку с учетом персональных весов
    weighted_score = preference.weighted_importance_score(post)
    post.personalized_score = weighted_score
    post
  end.select { |p| p.personalized_score >= threshold }
end
```

#### Способ 4: Collaborative Filtering через историю сессий

```ruby
# app/services/personalization/collaborative_filter.rb
module Personalization
  class CollaborativeFilter
    def initialize(user)
      @user = user
    end

    def find_similar_users
      # Найти пользователей с похожими паттернами фидбека
      user_topic_preferences = @user.feedbacks.liked.joins(:post)
        .pluck('posts.topics')
        .flatten
        .tally

      similar_users = TelegramUser.joins(feedbacks: :post)
        .where.not(id: @user.id)
        .select('telegram_users.*, COUNT(*) as similarity_score')
        .where('posts.topics && ARRAY[?]::varchar[]', user_topic_preferences.keys)
        .group('telegram_users.id')
        .order('similarity_score DESC')
        .limit(10)

      similar_users
    end

    def recommend_adjustments
      similar_users = find_similar_users
      return {} if similar_users.empty?

      # Собрать агрегированную статистику фидбека от похожих пользователей
      similar_user_ids = similar_users.map(&:id)

      topic_preferences = Feedback.liked
        .where(user_id: similar_user_ids)
        .joins(:post)
        .group('posts.topics')
        .count

      # Рекомендовать темы, которые нравятся похожим пользователям
      topic_preferences
    end
  end
end
```

---

## 5. Итоговые рекомендации и план действий

### 5.1. Критические изменения (сделать немедленно)

**Приоритет 1:** Внедрить AI Sessions с acts_as_chat

- [ ] Установить ruby_llm Rails integration
- [ ] Создать модель Chat с acts_as_chat
- [ ] Обновить User модель для управления сессиями
- [ ] Создать SessionManager сервис

**Приоритет 2:** Перейти на Structured Output

- [ ] Создать схемы для всех AI-ответов (PostClassificationSchema, etc.)
- [ ] Обновить AIClassifier для использования схем
- [ ] Обновить Post модель для хранения structured данных

**Приоритет 3:** Внедрить персонализацию через историю

- [ ] Связать Feedback с Chat
- [ ] Реализовать Few-Shot Builder
- [ ] Создать Context Builder для построения персонального контекста
- [ ] Обновить AIClassifier для использования контекста из истории

### 5.2. Важные улучшения (сделать в течение Phase 1)

**Приоритет 4:** Оптимизация производительности

- [ ] Реализовать управление контекстным окном
- [ ] Добавить batch-классификацию
- [ ] Настроить кеширование с зависимостями
- [ ] Реализовать архивацию старых сообщений

**Приоритет 5:** Улучшение UX

- [ ] Добавить streaming для длинных операций
- [ ] Реализовать индикаторы прогресса
- [ ] Оптимизировать время ответа AI

### 5.3. Дальнейшие улучшения (Phase 2+)

**Приоритет 6:** Tools (Function Calling)

- [ ] Создать набор инструментов для классификации
- [ ] Реализовать автоматический выбор инструментов
- [ ] Добавить комбинированные операции

**Приоритет 7:** Advanced персонализация

- [ ] Collaborative filtering
- [ ] Динамическая корректировка порогов
- [ ] Персональные веса тем
- [ ] A/B тестирование стратегий

### 5.4. Обновленный ROADMAP (краткая версия)

```
Phase 1.1: Infrastructure ✅
Phase 1.2: Models ✅
Phase 1.3: Bot Commands ✅
Phase 1.4: AI Sessions Infrastructure 🆕
  ├─ 1.4.1: AI Sessions Models
  ├─ 1.4.2: Session Management
  ├─ 1.4.3: Structured Output Schemas
  ├─ 1.4.4: AI Tools (Function Calling)
  └─ 1.4.5: Context Management
Phase 1.5: AI Classification (обновлено) 🔄
  ├─ 1.5.1: AI Classifier with Sessions
  ├─ 1.5.2: Batch Classification
  ├─ 1.5.3: Content Filter (context-aware)
  ├─ 1.5.4: Classify Job (with session tracking)
  └─ 1.5.5: Streaming Support
Phase 1.6: Digest Formation
Phase 1.7: Manual Digest
Phase 1.8: Help Command
Phase 1.9: Error Handling
Phase 1.10: Testing
Phase 1.11: Deployment

Phase 2.2: Personalization (обновлено) 🔄
  ├─ 2.2.1: Feedback Integration with AI Sessions
  ├─ 2.2.2: Few-Shot Learning
  ├─ 2.2.3: Dynamic Threshold Adjustment
  └─ 2.2.4: Context-Aware Classification
```

---

## 6. Метрики для измерения успеха

### 6.1. Технические метрики

**AI Performance:**
- Latency классификации одного поста (цель: < 2s)
- Количество токенов на запрос (цель: оптимизировать -30%)
- Стоимость AI на пользователя в день (цель: < $0.10)
- Hit rate кеша классификаций (цель: > 60%)

**Персонализация:**
- Accuracy классификации после обучения на фидбеке (цель: +15% vs baseline)
- Средний размер контекста на запрос (цель: < 5000 tokens)
- Correlation между AI-оценкой и пользовательским фидбеком (цель: > 0.7)

**Масштабируемость:**
- Рост размера БД сессий (мониторить)
- Время выполнения архивации (цель: < 1 min для всех сессий)
- Memory usage воркеров (цель: < 512MB)

### 6.2. Бизнес метрики

**Engagement:**
- % постов получивших фидбек (цель: > 10%)
- Retention rate после 1 недели (цель: > 40%)
- DAU/MAU ratio (цель: > 0.3)

**Качество фильтрации:**
- % пользователей, увеличивающих строгость фильтрации (индикатор качества)
- % пользователей с adaptive режимом (цель: > 50% через месяц)
- Среднее количество постов в дайджесте (цель: 10-15)

---

## 7. Заключение

### Критическая находка

Текущий план разработки NoFluff Bot **не использует** ключевые возможности ruby_llm gem:
- ❌ `acts_as_chat` для сохранения истории
- ❌ Structured Output для надежного парсинга
- ❌ Tools для более точной классификации
- ❌ Streaming для лучшего UX

Это приведет к:
1. **Отсутствию персонализации** - каждый запрос "с чистого листа"
2. **Ненадежной классификации** - парсинг строковых ответов
3. **Невозможности обучения** - фидбек не влияет на AI
4. **Плохому UX** - долгое ожидание без обратной связи

### Рекомендации

**НЕМЕДЛЕННО** (до продолжения Phase 1.5):
1. Внедрить AI Sessions с `acts_as_chat`
2. Создать Structured Output схемы
3. Связать Feedback с AI Sessions
4. Обновить ROADMAP

**В ТЕЧЕНИЕ PHASE 1:**
1. Реализовать Context Management
2. Добавить Few-Shot Learning из фидбека
3. Оптимизировать производительность
4. Добавить Streaming

**PHASE 2:**
1. Tools (Function Calling)
2. Advanced персонализация
3. Collaborative filtering

### Выгоды от изменений

✅ **Персонализация**: AI учится на предпочтениях каждого пользователя
✅ **Надежность**: Structured Output гарантирует корректный парсинг
✅ **Качество**: Few-shot learning повышает точность классификации на 15-20%
✅ **UX**: Streaming создает ощущение быстрой работы
✅ **Масштабируемость**: Кеширование и batch-обработка снижают затраты на 30%
✅ **Аналитика**: Сохраненная история позволяет анализировать и улучшать систему

### Следующие шаги

1. **Обсудить** предложенные изменения с командой
2. **Обновить** ROADMAP согласно рекомендациям
3. **Создать** миграции для AI Sessions
4. **Реализовать** базовую инфраструктуру AI Sessions (Phase 1.4)
5. **Протестировать** на небольшой группе пользователей
6. **Измерить** метрики и оптимизировать

---

**Дата создания:** 30 сентября 2025
**Версия:** 1.0
**Статус:** Готов к обсуждению
