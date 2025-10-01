# Архитектурное ревью NoFluff Bot

**Дата создания:** 30 сентября 2025
**Последнее обновление:** 1 октября 2025
**Версия проекта:** MVP (in progress)
**Статус:** ✅ Основная инфраструктура реализована, требуется имплементация сервисов

---

## История изменений

**1 октября 2025:**
- ✅ Обновлен статус проекта - базовая инфраструктура реализована
- ✅ Удалены неактуальные рекомендации - миграции выполнены
- ✅ Обновлены примеры кода для соответствия текущей архитектуре (telegram_user, context)
- ✅ Убран план корректировки документации - задачи выполнены
- ✅ Добавлены приоритеты реализации следующих шагов

---

## Исполнительное резюме

Архитектурный обзор NoFluff Bot для обеспечения правильного использования ruby_llm gem и создания масштабируемой персонализируемой системы.

### Статус реализации:

✅ **Реализовано:** Интеграция с `acts_as_chat` из ruby_llm
✅ **Реализовано:** Расширенная модель Chat с контекстом
✅ **Реализовано:** Модель PostClassification с персонализацией
⏳ **В работе:** Structured Output schemas
⏳ **В работе:** AI Services и Context Builders
⏳ **Планируется:** Tools (Function Calling)
⏳ **Планируется:** Streaming

---

## Текущий статус проекта

### ✅ Реализовано:

#### Базовая инфраструктура:
- ✅ Модели `Chat` и `Message` с `acts_as_chat` и `acts_as_message`
- ✅ RubyLLM gem установлен и настроен
- ✅ Таблица `chats` расширена полями:
  - `telegram_user_id` - связь с пользователем
  - `session_type` - тип сессии (enum)
  - `status` - статус чата (enum)
  - `context` - jsonb для хранения контекста
  - `last_activity_at` - время последней активности
  - `messages_count` - счетчик сообщений

#### Модели данных:
- ✅ `PostClassification` - персонализированная классификация постов
  - Связь с `chat_id` для отслеживания контекста
  - Поля: `importance_score`, `is_relevant`, `reasoning`, `confidence`
  - `classification_data` (jsonb) для structured output
- ✅ `Feedback` - система обратной связи
- ✅ `UserPreference` - персональные предпочтения пользователей
  - `topic_weights`, `channel_weights` (jsonb)
  - `adjusted_importance_threshold`
- ✅ Таблица `posts` содержит:
  - `classification_data` (jsonb) - структурированные данные классификации
  - `topics` (jsonb) - темы поста
  - `classification_reasoning` - объяснение оценки

#### Индексы:
- ✅ GIN индексы на jsonb поля
- ✅ Композитные индексы для быстрого поиска
- ✅ Foreign keys со всеми необходимыми связями

### ⏳ Требуется реализация:

1. **Structured Output Schemas** - схемы для typed responses от AI
2. **Chat Management Services** - сервисы для работы с чатами и контекстом
3. **Context Builder** - построение контекста с few-shot learning
4. **AI Classifier Service** - классификация с использованием Chat
5. **Personalization Services** - обработка фидбека и персонализация

---

## Рекомендуемая архитектура

### 1. Модель Chat (✅ Базовая структура реализована)

**Текущая реализация:**
```ruby
class Chat < ApplicationRecord
  acts_as_chat  # ✅ Реализовано

  belongs_to :telegram_user  # ✅ Реализовано
  belongs_to :model, optional: true  # ✅ Реализовано
  has_many :messages, dependent: :destroy  # ✅ Реализовано (через acts_as_chat)
end
```

**Рекомендуемые дополнения:**
```ruby
class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :telegram_user
  belongs_to :model, optional: true
  has_many :messages, dependent: :destroy

  # ⏳ Добавить enum для session_type
  enum session_type: {
    classification: 0,
    summarization: 1,
    personalization: 2,
    digest_generation: 3
  }

  # ⏳ Добавить enum для status
  enum status: {
    active: 0,
    archived: 1
  }

  # ⏳ Добавить store_accessor для контекста
  store_accessor :context,
    :user_preferences,
    :recent_feedback,
    :feedback_examples

  # ⏳ Методы для работы с контекстом
  def add_feedback_example(post, feedback)
    examples = feedback_examples || []
    examples << {
      post_text: post.text,
      user_liked: feedback.sentiment == 'like',
      importance_score: post.importance_score,
      timestamp: feedback.created_at
    }
    self.feedback_examples = examples.last(20)
    save
  end

  def update_last_activity!
    update(last_activity_at: Time.current)
    increment!(:messages_count)
  end
end
```

### 2. Structured Output вместо парсинга строк (⏳ Требуется реализация)

**Рекомендация:** Использовать Structured Output для получения typed responses от AI

```ruby
# app/schemas/post_classification_schema.rb
class PostClassificationSchema < RubyLLM::Schema
  number :importance_score, description: "0-100"
  boolean :is_ad
  boolean :is_fluff
  string :reasoning
  array :topics do
    string
  end
  object :duplicate_check do
    boolean :is_likely_duplicate
    number :similarity_score
  end
end

# Использование в сервисе
chat = telegram_user.chats.find_or_create_by!(session_type: :classification)
chat = chat.with_schema(PostClassificationSchema)
result = chat.ask("Классифицируй: #{post.text}")
# result.importance_score => 85 (число, не строка!)

# Сохранение в PostClassification
PostClassification.create!(
  post: post,
  telegram_user: telegram_user,
  chat: chat,
  importance_score: result.importance_score,
  is_relevant: !result.is_ad && !result.is_fluff && result.importance_score > threshold,
  reasoning: result.reasoning,
  classification_data: result.to_h
)
```

### 3. Персонализация через Few-Shot Learning (⏳ Требуется реализация)

**Рекомендация:** Использовать фидбек пользователя для персонализации классификации

```ruby
# Система автоматически учится на предпочтениях
chat = telegram_user.chats.find_or_create_by!(session_type: :classification)

# Добавить примеры из фидбека в контекст (через ContextBuilder)
few_shot_examples = Ai::ContextBuilder.new(telegram_user).build_feedback_examples
chat.context['feedback_examples'] = few_shot_examples
chat.save

# Классификация с учетом истории!
result = chat.ask("Классифицируй: #{post.text}")
```

**Пример ContextBuilder:**
```ruby
# app/services/ai/context_builder.rb
class Ai::ContextBuilder
  def initialize(telegram_user)
    @telegram_user = telegram_user
  end

  def build_feedback_examples
    # Получить последние 10 положительных и 10 отрицательных фидбеков
    liked = feedbacks.where(sentiment: 'like').limit(10)
    disliked = feedbacks.where(sentiment: 'dislike').limit(10)

    (liked + disliked).map do |feedback|
      {
        post_text: feedback.post.text,
        user_liked: feedback.sentiment == 'like',
        importance_score: feedback.post.importance_score
      }
    end
  end

  private

  def feedbacks
    @telegram_user.feedbacks.order(created_at: :desc)
  end
end
```

### 4. Разделение Stateless и Stateful операций

**Stateless операции (быстрые, без контекста):**
- Первичная классификация нового поста
- Определение рекламы (is_ad)
- Проверка на дубликат

**Stateful операции (с историей):**
- Персонализированная классификация
- Генерация саммари дайджеста
- Обучение на фидбеке

---

## Статус миграций

### ✅ Выполнено:

**Миграция `20251001114100_add_fields_to_chats.rb`:**
```ruby
class AddFieldsToChats < ActiveRecord::Migration[8.0]
  def change
    add_reference :chats, :telegram_user, null: false, foreign_key: true, index: true
    add_column :chats, :session_type, :integer, default: 0, null: false
    add_column :chats, :status, :integer, default: 0, null: false
    add_column :chats, :context, :jsonb, default: {}
    add_column :chats, :last_activity_at, :datetime
    add_column :chats, :messages_count, :integer, default: 0

    add_index :chats, [:telegram_user_id, :session_type]
    add_index :chats, :status
    add_index :chats, :last_activity_at
    add_index :chats, :context, using: :gin
  end
end
```

**Созданы таблицы:**
- ✅ `post_classifications` - персонализированная классификация (с chat_id)
- ✅ `feedbacks` - обратная связь от пользователей
- ✅ `user_preferences` - персональные предпочтения
- ✅ `posts` с полями: classification_data (jsonb), topics (jsonb), classification_reasoning

**Примечание:** В текущей реализации используется:
- `telegram_user_id` вместо `user_id` (соответствует доменной модели)
- `context` вместо `metadata` (более точное название)
- Отдельная таблица `post_classifications` вместо полей в `posts` (лучше для персонализации)

---

## Ожидаемые результаты

### До изменений:
- ❌ Accuracy классификации: ~70% (baseline)
- ❌ Персонализация: нет
- ❌ Стоимость токенов: высокая (каждый раз полный промпт)
- ❌ UX: плохой (долгое ожидание)

### После изменений:
- ✅ Accuracy классификации: ~85% (+15% через few-shot)
- ✅ Персонализация: для каждого пользователя
- ✅ Стоимость токенов: -30% (кеширование + batch)
- ✅ UX: отличный (streaming, прогресс)
- ✅ Обучаемость: система улучшается со временем

---

## Метрики успеха

### Технические:
- Latency классификации: < 2s
- Hit rate кеша: > 60%
- Стоимость на пользователя: < $0.10/день

### Персонализация:
- Accuracy после обучения: +15% vs baseline
- Correlation AI-оценка ↔ фидбек: > 0.7

### Бизнес:
- % постов с фидбеком: > 10%
- Retention после 1 недели: > 40%
- DAU/MAU: > 0.3

---

## Заключение

Проект находится в идеальный момент для внесения изменений:
- ✅ Модели Chat и Message уже существуют
- ✅ acts_as_chat уже реализован
- ✅ Можно расширить существующую архитектуру

**Не внося эти изменения сейчас, вы получите:**
- Систему без персонализации
- Высокие затраты на AI
- Плохую точность классификации
- Невозможность обучения на фидбеке

**Внеся изменения сейчас, вы получите:**
- Персонализированную систему с первого дня
- Оптимизированные затраты на AI
- Высокую точность классификации
- Автоматическое обучение на данных пользователей

---

## Приоритеты реализации

### Высокий приоритет (Phase 1.4):
1. **Enum и методы для Chat** - добавить session_type, status, методы работы с контекстом
2. **Structured Output Schemas** - схемы для typed responses
3. **AI Classifier Service** - классификация с использованием Chat
4. **Context Builder** - построение контекста с few-shot learning

### Средний приоритет (Phase 1.6):
5. **Batch Classifier** - оптимизация для multiple posts
6. **Streaming Support** - для дайджестов

### Низкий приоритет (Phase 2.2):
7. **Персонализация** - интеграция фидбека в классификацию
8. **Cleanup Jobs** - архивация старых чатов

---

**Связанные документы:**
- [ROADMAP.md](../ROADMAP.md) - детальный план разработки
- [implementation-examples.md](./implementation-examples.md) - примеры реализации
- [c4-model.md](./c4-model.md) - архитектурная модель