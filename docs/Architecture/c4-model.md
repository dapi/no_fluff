# Архитектура системы "Без шелухи" (AI-дайджестер)

Архитектура описана с использованием C4 Model (Context, Container, Component, Code).

## 🚨 ВАЖНОЕ ОБНОВЛЕНИЕ АРХИТЕКТУРЫ

**Проблема**: Telegram Bot API НЕ позволяет ботам самостоятельно вступать в каналы
**Решение**: Переход на User-based подход через Telegram App API (MTProto) с использованием TDLib-ruby

**Новая архитектура**: [C4 Model v2.0 (User-based)](./c4-model-updated.md)
**План миграции**: [User-based Access Migration](./user-based-access-migration.md)
**MTProto библиотека**: [TDLib-ruby Implementation](./tdlib-ruby-implementation.md)

### Ключевые изменения v2.0:
- 🔄 **Двойной API подход**: Bot API + MTProto через TDLib-ruby
- 👤 **Follower User Account**: Специальный аккаунт для мониторинга на TDLib
- 🔐 **Усиленная безопасность**: Управление сессиями TDLib и rate limiting
- 📊 **Расширенные возможности**: Доступ к приватным каналам через User API
- 🛡️ **Стабильность**: Использование официальной TDLib от Telegram

---

## Level 1: System Context Diagram

Диаграмма показывает систему в контексте взаимодействия с пользователями и внешними системами.

```mermaid
C4Context
    title System Context diagram для Без Шелухи

    Person(user, "Пользователь Telegram", "Хочет получать важный контент из каналов без шелухи")

    System(bez_sheluhi, "Без Шелухи System", "AI-дайджестер фильтрует контент из Telegram каналов, обнаруживает дубликаты, формирует персонализированные дайджесты")

    System_Ext(telegram, "Telegram Bot API", "API для взаимодействия с Telegram")
    System_Ext(telegram_channels, "Telegram Channels", "Публичные Telegram каналы, за которыми следит бот")
    System_Ext(ai_service, "AI/LLM Service", "Сервис для классификации важности, генерации саммари, определения дубликатов")

    Rel(user, nofluff, "Управляет настройками, получает дайджесты", "Telegram")
    Rel(nofluff, telegram, "Отправляет/получает сообщения", "HTTPS/Webhook")
    Rel(nofluff, telegram_channels, "Мониторит новые посты", "Telegram API")
    Rel(nofluff, ai_service, "Классифицирует контент, генерирует саммари", "HTTPS/API")
```

### Внешние системы:

1. **Telegram Bot API** - основной интерфейс взаимодействия с пользователями
2. **Telegram Channels** - источники контента для мониторинга
3. **AI/LLM Service** - OpenAI/Anthropic/локальная модель для:
   - Классификации важности контента
   - Генерации саммари
   - Определения дубликатов
   - Тематической фильтрации

---

## Level 2: Container Diagram

Диаграмма показывает основные контейнеры системы и их взаимодействие.

```mermaid
C4Container
    title Container diagram для NoFluff Bot

    Person(user, "Пользователь", "Пользователь Telegram")

    System_Ext(telegram, "Telegram Bot API")
    System_Ext(ai, "AI/LLM Service")

    Container(rails_app, "Rails API Application", "Ruby on Rails 8", "Обрабатывает команды пользователей, управляет бизнес-логикой")
    Container(bot_workers, "Background Workers", "Solid Queue", "Асинхронная обработка: мониторинг каналов, формирование дайджестов, AI-анализ")

    ContainerDb(postgres, "Database", "PostgreSQL", "Хранит пользователей, каналы, посты, настройки, статистику")
    ContainerDb(cache, "Cache", "Solid Cache", "Кеширует результаты AI, дедупликацию, частые запросы")
    ContainerQueue(queue, "Job Queue", "Solid Queue", "Очередь фоновых задач")

    Rel(user, telegram, "Отправляет команды", "Telegram")
    Rel(telegram, rails_app, "Webhook / Long Polling", "HTTPS")
    Rel(rails_app, postgres, "Читает/пишет данные", "SQL")
    Rel(rails_app, cache, "Кеширует данные", "Redis Protocol")
    Rel(rails_app, queue, "Ставит задачи в очередь", "SQL")
    Rel(bot_workers, queue, "Забирает задачи", "SQL")
    Rel(bot_workers, postgres, "Обновляет данные", "SQL")
    Rel(bot_workers, telegram, "Мониторит каналы, отправляет дайджесты", "HTTPS")
    Rel(bot_workers, ai, "Анализирует контент", "HTTPS")
    Rel(bot_workers, cache, "Использует кеш", "Redis Protocol")
```

### Контейнеры:

1. **Rails API Application**
   - Обработка Telegram webhook/polling
   - Bot Controllers для команд пользователя
   - API для управления настройками
   - Бизнес-логика

2. **Background Workers** (Solid Queue)
   - Channel Bot Join Workers - вступление бота в каналы
   - Content Processor Workers - AI-анализ контента
   - Digest Builder Workers - формирование дайджестов
   - Delivery Workers - отправка дайджестов по расписанию

3. **PostgreSQL Database**
   - Пользователи и их настройки
   - Каналы и подписки
   - Посты и их метаданные
   - Дайджесты и история доставки
   - Статистика и аналитика

4. **Solid Cache**
   - Кеш результатов AI-классификации
   - Кеш векторов для дедупликации
   - Кеш рекомендаций каналов

5. **Solid Queue**
   - Управление фоновыми задачами
   - Ретраи при ошибках
   - Приоритизация задач

---

## Level 3: Component Diagram

Детальная структура компонентов внутри Rails Application.

```mermaid
C4Component
    title Component diagram для Rails Application

    Container_Ext(telegram, "Telegram API")
    Container_Ext(workers, "Background Workers")
    ContainerDb_Ext(db, "PostgreSQL")
    ContainerDb_Ext(cache, "Cache")

    Component(webhook_controller, "Telegram Webhook Controller", "Telegram::Bot::UpdatesController", "Принимает обновления от Telegram и обрабатывает команды")

    Component(bot_concerns, "Bot Command Concerns", "Rails Concerns", "Группы команд: SubscriptionCommands, SettingsCommands, DigestCommands")

    Component(user_service, "User Service", "Service Object", "Управление пользователями и онбордингом")
    Component(channel_service, "Channel Management Service", "Service Object", "Управление подписками на каналы")
    Component(settings_service, "Settings Service", "Service Object", "Управление настройками частоты, формата, фильтрации")

    Component(content_filter, "Content Filter Service", "Service Object", "Определяет важность контента на основе AI")
    Component(deduplication, "Deduplication Service", "Service Object", "Находит и удаляет дубликаты постов")
    Component(digest_builder, "Digest Builder Service", "Service Object", "Формирует дайджесты в разных форматах")

    Component(recommendation, "Recommendation Service", "Service Object", "Рекомендует каналы на основе социального графа")
    Component(analytics, "Analytics Service", "Service Object", "Собирает статистику и метрики")
    Component(personalization, "Personalization Service", "Service Object", "Обучается на лайках/дизлайках пользователя")

    Component(models, "Active Record Models", "Models", "TelegramUser, Channel, Post, Subscription, Digest, Feedback")

    Rel(telegram, webhook_controller, "Webhook updates", "HTTPS")
    Rel(webhook_controller, bot_concerns, "Использует concern'и для команд")

    Rel(bot_concerns, user_service, "Использует")
    Rel(bot_concerns, channel_service, "Использует")
    Rel(bot_concerns, settings_service, "Использует")
    Rel(bot_concerns, analytics, "Использует")

    Rel(user_service, models, "Использует")
    Rel(channel_service, models, "Использует")
    Rel(settings_service, models, "Использует")

    Rel(workers, content_filter, "Вызывает для анализа")
    Rel(workers, deduplication, "Вызывает для дедупликации")
    Rel(workers, digest_builder, "Вызывает для формирования")
    Rel(workers, recommendation, "Вызывает для рекомендаций")

    Rel(content_filter, models, "Сохраняет результаты")
    Rel(content_filter, cache, "Кеширует классификации")
    Rel(deduplication, cache, "Кеширует векторы")
    Rel(personalization, models, "Обновляет веса")

    Rel(models, db, "ActiveRecord", "SQL")
```

### Компоненты по слоям:

#### 1. Bot Interface Layer

**Telegram Webhook Controller**
- Основной контроллер, наследуется от Telegram::Bot::UpdatesController
- Принимает обновления от Telegram (webhook или polling)
- Обрабатывает базовые команды (/start, /help, /add)
- Использует built-in маршрутизацию telegram-bot-rb gem

**Bot Command Concerns**
- `SubscriptionCommands` - управление подписками (/list, callback'и для удаления/приоритета)
- `SettingsCommands` - настройки фильтрации и доставки (планируется)
- `DigestCommands` - запрос и управление дайджестами (планируется)
- `FeedbackCommands` - лайки/дизлайки контента (планируется)
- `StatsCommands` - статистика использования (планируется)
- `DiscoverCommands` - рекомендации каналов (планируется)

**Паттерн организации кода**
- Основной контроллер включает необходимые concerns
- Каждый concern содержит группу связанных команд
- Callback query обработчики находятся в соответствующих concerns

#### 2. User Management Layer

**User Service**
- Создание и управление пользователями
- Онбординг flow
- Управление состоянием пользователя

**Channel Management Service**
- Добавление/удаление каналов
- Валидация каналов
- Управление подписками
- Приоритизация каналов

**Settings Service**
- Управление частотой доставки
- Выбор формата контента
- Настройка строгости фильтрации
- Тематические фильтры

#### 3. Content Processing Layer

**Content Filter Service**
- Классификация важности контента
- Фильтрация рекламы
- Тематическая фильтрация
- Интеграция с AI/LLM
- Применение персональных весов

**Deduplication Service**
- Генерация эмбеддингов постов
- Косинусное сходство для поиска дубликатов
- Кластеризация похожих постов
- Выбор лучшего варианта из дубликатов

**Content Processor Service**
- Парсинг постов из каналов
- Извлечение метаданных
- Нормализация контента

#### 4. Delivery Layer

**Digest Builder Service**
- Форматирование по выбранному формату:
  - Оригинальные посты
  - Краткие саммари (AI)
  - Единый дайджест
  - Комбо-формат (топ-3 + саммари)
  - Только заголовки
- Группировка по темам
- Ранжирование по важности

**Delivery Scheduler Service**
- Планирование отправки дайджестов
- Учет часового пояса пользователя
- Batch-отправка для масштабирования

#### 5. Analytics & Recommendations Layer

**Analytics Service**
- Сбор метрик использования
- Статистика по каналам
- Статистика фильтрации
- A/B тестирование

**Recommendation Service**
- Построение социального графа каналов
- Коллаборативная фильтрация
- Рекомендации похожих каналов

**Personalization Service**
- Обучение на фидбеке пользователя (like/dislike)
- Корректировка весов важности
- Адаптивная фильтрация

---

## Level 4: Code Level (Детали реализации)

### Структура папок Rails приложения:

```
app/
├── controllers/
│   ├── telegram_webhook_controller.rb
│   ├── application_controller.rb
│   └── concerns/
│       └── telegram/
│           ├── subscription_commands.rb
│           ├── settings_commands.rb
│           ├── digest_commands.rb
│           ├── feedback_commands.rb
│           ├── stats_commands.rb
│           └── discover_commands.rb
├── services/
│   ├── user/
│   │   ├── creator.rb
│   │   ├── onboarder.rb
│   │   └── state_manager.rb
│   ├── channels/
│   │   ├── manager.rb
│   │   ├── validator.rb
│   │   └── prioritizer.rb
│   ├── settings/
│   │   ├── frequency_manager.rb
│   │   ├── format_manager.rb
│   │   └── filter_manager.rb
│   ├── content/
│   │   ├── processor.rb
│   │   ├── filter.rb
│   │   ├── deduplicator.rb
│   │   └── ai_classifier.rb
│   ├── digest/
│   │   ├── builder.rb
│   │   ├── formatter.rb
│   │   ├── ranker.rb
│   │   └── scheduler.rb
│   ├── analytics/
│   │   ├── collector.rb
│   │   ├── reporter.rb
│   │   └── metrics_calculator.rb
│   ├── recommendation/
│   │   ├── channel_recommender.rb
│   │   └── social_graph_builder.rb
│   └── personalization/
│       ├── feedback_processor.rb
│       ├── weight_adjuster.rb
│       └── adaptive_filter.rb
├── jobs/
│   ├── channels/
│   │   └── bot_join_job.rb
│   ├── content/
│   │   ├── process_post_job.rb
│   │   ├── classify_job.rb
│   │   └── deduplicate_batch_job.rb
│   ├── digest/
│   │   ├── build_job.rb
│   │   └── deliver_job.rb
│   └── analytics/
│       └── collect_metrics_job.rb
├── models/
│   ├── telegram_user.rb
│   ├── channel.rb
│   ├── subscription.rb
│   ├── post.rb
│   ├── post_classification.rb
│   ├── digest.rb
│   ├── digest_item.rb
│   ├── feedback.rb
│   ├── user_preference.rb
│   └── channel_recommendation.rb
└── lib/
    ├── telegram_client/
    │   ├── api_wrapper.rb
    │   └── channel_fetcher.rb
    └── ai/
        ├── classifier.rb
        ├── summarizer.rb
        └── embedding_generator.rb
```

### Ключевые модели данных:

#### TelegramUser
```ruby
class TelegramUser < ApplicationRecord
  has_many :subscriptions, dependent: :destroy
  has_many :channels, through: :subscriptions
  has_many :digests, dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_one :user_preference, dependent: :destroy
  has_many :chats, dependent: :destroy

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

  # Валидации
  validates :username, uniqueness: { allow_blank: true }
  validates :language_code, presence: true
end
```

#### Channel
```ruby
class Channel < ApplicationRecord
  has_many :subscriptions
  has_many :telegram_users, through: :subscriptions
  has_many :posts

  validates :telegram_id, presence: true, uniqueness: true
  validates :username, presence: true

  enum bot_join_status: {
    not_joined: 0,
    joining: 1,
    joined: 2,
    join_failed: 3
  }

  def bot_can_monitor?
    active? && joined?
  end
end
```

#### Subscription
```ruby
class Subscription < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :channel

  # Приоритет канала для пользователя
  validates :priority, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 10 }
end
```

#### Post
```ruby
class Post < ApplicationRecord
  belongs_to :channel
  has_many :post_classifications
  has_many :digest_items
  has_many :feedbacks

  # Метаданные
  # telegram_message_id, text, media_urls, published_at

  # Классификация
  # is_important, importance_score, is_ad, is_duplicate_of

  scope :important, -> { where(is_important: true) }
  scope :not_ads, -> { where(is_ad: false) }
  scope :unique, -> { where(is_duplicate_of: nil) }
end
```

#### PostClassification
```ruby
class PostClassification < ApplicationRecord
  belongs_to :post
  belongs_to :telegram_user

  # Персональная классификация для пользователя
  # importance_score, is_relevant, classification_reason
end
```

#### Digest
```ruby
class Digest < ApplicationRecord
  belongs_to :telegram_user
  has_many :digest_items
  has_many :posts, through: :digest_items

  enum status: { pending: 0, sent: 1, failed: 2 }

  # scheduled_for, sent_at, posts_analyzed_count, posts_included_count
end
```

#### Feedback
```ruby
class Feedback < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :post

  enum sentiment: { dislike: -1, neutral: 0, like: 1 }
end
```

---

## Ключевые процессы и workflows

### 1. Вступление бота в канал (Bot Channel Join Workflow)

```mermaid
sequenceDiagram
    participant User
    participant ChannelService
    participant BotJoinJob
    participant TelegramAPI
    participant DB

    User->>ChannelService: Добавить канал
    ChannelService->>DB: Сохранить канал (bot_join_status: not_joined)
    ChannelService->>BotJoinJob: perform_later(channel.id)
    BotJoinJob->>DB: Обновить статус на joining
    BotJoinJob->>TelegramAPI: Попытка вступить в канал
    alt Успешное вступление
        TelegramAPI->>BotJoinJob: Успех
        BotJoinJob->>DB: Обновить статус на joined
        BotJoinJob->>User: Уведомление об успехе
    else Ошибка вступления
        TelegramAPI->>BotJoinJob: Ошибка
        BotJoinJob->>DB: Обновить статус на join_failed + bot_join_error
        BotJoinJob->>User: Уведомление об ошибке
    end
```

### 2. Обработка постов через Webhook (Webhook Post Processing Workflow)

```mermaid
sequenceDiagram
    participant TelegramChannel
    participant WebhookController
    participant Channel
    participant ContentProcessor
    participant AIClassifier
    participant Deduplicator
    participant DB

    TelegramChannel->>WebhookController: Новый пост
    WebhookController->>Channel: Найти канал по username/ID
    alt Бот вступил в канал (bot_join_status: joined)
        Channel->>ContentProcessor: Process new post
        ContentProcessor->>AIClassifier: Classify importance
        AIClassifier->>ContentProcessor: Importance score
        ContentProcessor->>Deduplicator: Check duplicates
        Deduplicator->>ContentProcessor: Duplicate status
        ContentProcessor->>DB: Save post + metadata
    else Бот не вступил в канал
        WebhookController->>TelegramChannel: Игнорировать пост
    end
```

### 3. Формирование и доставка дайджеста (Digest Building Workflow)

```mermaid
sequenceDiagram
    participant Scheduler
    participant DigestJob
    participant DigestBuilder
    participant ContentFilter
    participant Ranker
    participant Formatter
    participant Telegram
    participant DB

    Scheduler->>DigestJob: Время доставки для User
    DigestJob->>DB: Получить настройки User
    DigestJob->>ContentFilter: Отфильтровать посты
    ContentFilter->>DB: Получить посты + classifications
    ContentFilter->>DigestBuilder: Важные посты
    DigestBuilder->>Ranker: Ранжировать
    Ranker->>DigestBuilder: Упорядоченные посты
    DigestBuilder->>Formatter: Форматировать (summaries/original/etc)
    Formatter->>DigestBuilder: Готовый дайджест
    DigestBuilder->>DB: Сохранить Digest
    DigestBuilder->>Telegram: Отправить пользователю
    Telegram->>DigestBuilder: Статус доставки
    DigestBuilder->>DB: Обновить статус
```

### 4. Обработка фидбека (Feedback Processing Workflow)

```mermaid
sequenceDiagram
    participant User
    participant Telegram
    participant FeedbackController
    participant FeedbackProcessor
    participant WeightAdjuster
    participant DB

    User->>Telegram: 👍 Like или 👎 Dislike
    Telegram->>FeedbackController: Callback query
    FeedbackController->>DB: Сохранить Feedback
    FeedbackController->>FeedbackProcessor: Process feedback
    FeedbackProcessor->>WeightAdjuster: Adjust user weights
    WeightAdjuster->>DB: Update UserPreference
    FeedbackController->>User: Спасибо за фидбек!
```

---

## Применение SOLID принципов

### Single Responsibility Principle (SRP)
- Каждый сервис отвечает за одну четко определенную область:
  - `ContentFilter` - только фильтрация
  - `Deduplicator` - только дедупликация
  - `DigestBuilder` - только построение дайджеста

### Open/Closed Principle (OCP)
- Форматтеры дайджестов наследуются от базового класса:
  ```ruby
  class BaseFormatter
    def format(posts); raise NotImplementedError; end
  end

  class OriginalFormatter < BaseFormatter; end
  class SummaryFormatter < BaseFormatter; end
  class ComboFormatter < BaseFormatter; end
  ```

### Liskov Substitution Principle (LSP)
- Все форматтеры взаимозаменяемы через общий интерфейс
- AI классификаторы (OpenAI, Anthropic, Local) реализуют общий контракт

### Interface Segregation Principle (ISP)
- Контроллеры разделены по командам, не один большой контроллер
- Сервисы имеют минимальные интерфейсы

### Dependency Inversion Principle (DIP)
- Сервисы зависят от абстракций (интерфейсов), а не от конкретных реализаций:
  ```ruby
  class DigestBuilder
    def initialize(filter:, ranker:, formatter:)
      @filter = filter      # Любой объект с методом .filter
      @ranker = ranker      # Любой объект с методом .rank
      @formatter = formatter # Любой объект с методом .format
    end
  end
  ```

---

## Масштабирование и производительность

### Стратегии масштабирования:

1. **Горизонтальное масштабирование воркеров**
   - Solid Queue поддерживает несколько воркеров
   - Разные приоритеты для разных типов задач

2. **Кеширование**
   - AI классификации (TTL: 24 часа)
   - Эмбеддинги для дедупликации (TTL: 7 дней)
   - Рекомендации каналов (TTL: 1 час)

3. **Batch processing**
   - Группировка постов для AI-анализа
   - Batch-отправка дайджестов

4. **Database indexing**
   - Индексы на telegram_id, published_at, importance_score
   - Partial indexes для важных постов

5. **Rate limiting**
   - Лимиты на Telegram API
   - Лимиты на AI API с retry механизмами

---

## Безопасность

### Меры безопасности:

1. **Webhook validation**
   - Проверка токена Telegram
   - HTTPS only

2. **Rate limiting**
   - Защита от спама команд

3. **Data privacy**
   - Шифрование персональных данных
   - GDPR compliance

4. **API keys management**
   - Использование Rails credentials
   - Ротация ключей

---

## Мониторинг и логирование

### Ключевые метрики:

1. **System health**
   - Uptime воркеров
   - Queue depth
   - Database performance

2. **Business metrics**
   - Активные пользователи (DAU/MAU)
   - Retention rate
   - Average posts filtered
   - Digest delivery rate

3. **AI metrics**
   - Classification accuracy (на основе feedback)
   - Duplicate detection rate
   - Summarization quality

### Логирование:

- Structured logging (JSON)
- Correlation IDs для трейсинга
- Error tracking (Bugsnag/Rollbar)
- Performance monitoring (New Relic/Datadog)

---

## Roadmap

Детальный ROADMAP с разбивкой на подэтапы и чекбоксы доступен в отдельном файле:

**[ROADMAP.md](../Product/ROADMAP.md)**
