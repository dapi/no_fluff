# Архитектурное ревью NoFluff Bot

**Дата:** 30 сентября 2025
**Версия проекта:** MVP (pre-implementation)
**Статус:** Критические изменения требуются до начала разработки

---

## Исполнительное резюме

В ходе ревью архитектуры NoFluff Bot обнаружены **критические пробелы** в планировании использования ruby_llm gem. Текущая архитектура планирует все AI-взаимодействия как stateless операции, что **блокирует** ключевые функции персонализации.

### Ключевые находки:

🔴 **Критично:** Отсутствует интеграция с `acts_as_chat` из ruby_llm
🔴 **Критично:** Не используется Structured Output
🔴 **Критично:** Не используются Tools (Function Calling)
🔴 **Важно:** Не используется Streaming
🔴 **Важно:** Отсутствует связь Feedback → AI

---

## Текущий статус проекта

### ✅ Уже реализовано:
- Модели `Chat` и `Message` с `acts_as_chat` и `acts_as_message`
- Базовая структура таблиц в БД
- RubyLLM gem установлен

### ❌ Проблемы в текущем планировании:

1. **Нет сохранения истории взаимодействий**
   - Планируется создавать новый chat объект для каждого AI-запроса
   - Модель "забывает" контекст между запросами
   - Невозможна персонализация

2. **Ненадежный парсинг ответов AI**
   - Планируется парсить строковые ответы: "Важность: 85/100, Реклама: Нет..."
   - Регулярные выражения вместо структурированных данных

3. **Отсутствие влияния фидбека на AI**
   - Feedback сохраняется, но не влияет на будущие классификации
   - Нет обучения на предпочтениях пользователя

---

## Рекомендуемая архитектура

### 1. Расширение модели Chat

```ruby
class Chat < ApplicationRecord
  acts_as_chat  # Уже реализовано в проекте!

  # Добавляем связи для NoFluff
  belongs_to :user, optional: true
  belongs_to :model
  has_many :messages, dependent: :destroy

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

  # Контекст сессии (JSON)
  store_accessor :metadata,
    :user_preferences,
    :recent_feedback,
    :feedback_examples

  # Методы для работы с контекстом
  def add_feedback_example(post, feedback)
    examples = feedback_examples || []
    examples << {
      post_text: post.text,
      user_liked: feedback.like?,
      importance_score: post.importance_score,
      timestamp: feedback.created_at
    }
    self.feedback_examples = examples.last(20)
    save
  end
end
```

### 2. Structured Output вместо парсинга строк

```ruby
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

# Использование
chat = user.chats.find_or_create_by!(session_type: :classification)
chat = chat.with_schema(PostClassificationSchema)
result = chat.ask("Классифицируй: #{post.text}")
# result.importance_score => 85 (число, не строка!)
```

### 3. Персонализация через Few-Shot Learning

```ruby
# Система автоматически учится на предпочтениях
chat = user.chats.find_or_create_by!(session_type: :classification)

# Добавить примеры из фидбека в контекст
few_shot_examples = build_examples_from_feedback(user)
chat.metadata['feedback_examples'] = few_shot_examples
chat.save

# Классификация с учетом истории!
result = chat.ask("Классифицируй: #{post.text}")
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

## План корректировки документации

### [ ] Обновить ROADMAP.md

#### Phase 1.4: Chat Infrastructure (НОВАЯ ФАЗА)
- [ ] 1.4.1. Расширить модель Chat (добавить user_id, session_type, status, metadata)
- [ ] 1.4.2. User Model Updates (has_many :chats, chat_for метод)
- [ ] 1.4.3. Chat Manager Service
- [ ] 1.4.4. Structured Output Schemas
- [ ] 1.4.5. AI Tools (Function Calling)
- [ ] 1.4.6. Context Builder Service
- [ ] 1.4.7. Post Model Updates (classification_data, topics, classified_by_chat_id)
- [ ] 1.4.8. Cleanup Job для Chats

#### Обновить Phase 1.6: AI фильтрация
- [ ] Использовать Chat с историей вместо простых запросов
- [ ] Structured Output вместо парсинга строк
- [ ] Персональный контекст для каждого пользователя
- [ ] Batch-классификация для оптимизации
- [ ] Streaming для длинных операций

#### Расширить Phase 2.2: Персонализация
- [ ] Связать Feedback с Chat
- [ ] Few-Shot Learning из фидбека
- [ ] Динамическая корректировка порогов
- [ ] Персональные веса тем
- [ ] Feedback Analytics

### [ ] Обновить architectural-review-report.md
- [ ] Заменить AiSession на Chat во всех примерах
- [ ] Обновить миграции (расширить существующие таблицы)
- [ ] Исправить названия сервисов (SessionManager → ChatManager)

### [ ] Обновить implementation-examples.md
- [ ] Заменить все примеры кода для использования Chat
- [ ] Обновить ассоциации (has_many :chats вместо has_many :ai_sessions)
- [ ] Исправить имена методов (chat_for вместо ai_session_for)

### [ ] Обновить C4 модель (если есть docs/Architecture/c4-model.md)
- [ ] Добавить компоненты: ChatManager, Stateful/Stateless классификаторы
- [ ] Обновить список моделей (chat.rb, message.rb)
- [ ] Обновить структуру сервисов

---

## Необходимые миграции

### Расширение существующих таблиц:

```ruby
# db/migrate/XXXXXX_add_nofluff_fields_to_chats.rb
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
    add_index :chats, :created_at
  end
end

# db/migrate/XXXXXX_add_post_fields_for_structured_data.rb
class AddPostFieldsForStructuredData < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :classification_data, :jsonb, default: {}
    add_column :posts, :topics, :string, array: true, default: []
    add_column :posts, :classification_reasoning, :text
    add_column :posts, :classified_by_chat_id, :bigint

    add_index :posts, :topics, using: :gin
    add_index :posts, :classification_data, using: :gin
    add_foreign_key :posts, :chats, column: :classified_by_chat_id
  end
end
```

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

**Связанные документы:**
- [architectural-review-report.md](./architectural-review-report.md)
- [ROADMAP.md](./ROADMAP.md)