# NoFluff Bot - ROADMAP

## Phase 1: MVP (Минимально жизнеспособный продукт)

### 1.1. Инфраструктура и базовая настройка

#### 1.1.1. Database Setup
- [x] Создать миграции для основных таблиц
  - [x] `telegram_users` (id, username, delivery_frequency, content_format, filter_strictness, timezone)
  - [x] `channels` (telegram_id, username, title, description, subscribers_count)
  - [x] `subscriptions` (telegram_user_id, channel_id, priority, active)
  - [x] `posts` (channel_id, telegram_message_id, text, media_urls, published_at, is_important, importance_score, is_ad, is_duplicate_of)
  - [x] `user_digests` (telegram_user_id, status, scheduled_for, sent_at, posts_analyzed_count, posts_included_count)
  - [x] `user_digest_items` (user_digest_id, post_id, position)
- [x] Добавить индексы
  - [x] `index_telegram_users_on_username` (unique)
  - [x] `index_channels_on_telegram_id` (unique)
  - [x] `index_posts_on_channel_id_and_published_at`
  - [x] `index_posts_on_is_important`
  - [x] `index_subscriptions_on_telegram_user_id_and_channel_id` (unique)
- [x] Запустить миграции

#### 1.1.2. Telegram Bot Setup
- [x] Настроить telegram-bot-ruby gem
- [x] Создать `config/initializers/telegram.rb`
- [x] Создать базовый `TelegramWebhookController`
- [x] Добавить routes для webhook
- [x] Протестировать подключение к Telegram

#### 1.1.3. AI/LLM Setup
- [x] Настроить ruby_llm gem
- [x] Создать `config/initializers/ruby_llm.rb`
- [ ] Настроить API ключи (OpenAI/Anthropic/другие)
- [ ] Создать базовый wrapper `lib/ai/classifier.rb`
- [ ] Протестировать подключение к AI API

#### 1.1.4. Background Jobs Setup
- [x] Настроить Solid Queue
- [x] Создать конфигурацию для разных типов джобов
- [x] Настроить приоритеты очередей
- [x] Создать базовый ApplicationJob

### 1.2. Модели и базовая валидация

#### 1.2.1. TelegramUser Model
- [x] Создать `app/models/telegram_user.rb`
- [x] Добавить enum для `delivery_frequency`
- [x] Добавить enum для `content_format`
- [x] Добавить enum для `filter_strictness`
- [x] Добавить associations (has_many :subscriptions, :user_digests)
- [x] Добавить validations
- [x] Добавить scopes (active_telegram_users, by_delivery_time)
- [x] Написать unit тесты

#### 1.2.2. Channel Model
- [x] Создать `app/models/channel.rb`
- [x] Добавить associations (has_many :subscriptions, :posts)
- [x] Добавить validations (telegram_id uniqueness)
- [x] Добавить scopes (active_channels, by_subscribers)
- [x] Добавить методы для работы с Telegram API
- [x] Написать unit тесты

#### 1.2.3. Subscription Model
- [x] Создать `app/models/subscription.rb`
- [x] Добавить associations (belongs_to :telegram_user, :channel)
- [x] Добавить validations (uniqueness, priority range)
- [x] Добавить scopes (active, by_priority)
- [x] Написать unit тесты

#### 1.2.4. Post Model
- [x] Создать `app/models/post.rb`
- [x] Добавить associations (belongs_to :channel)
- [x] Добавить validations
- [x] Добавить scopes (important, not_ads, unique, recent)
- [x] Добавить методы для работы с метаданными
- [x] Написать unit тесты

#### 1.2.5. UserDigest Model (renamed from Digest)
- [x] Создать `app/models/user_digest.rb`
- [x] Добавить enum для `status`
- [x] Добавить associations (belongs_to :telegram_user, has_many :user_digest_items, has_many :posts through: :user_digest_items)
- [x] Добавить validations
- [x] Добавить scopes (pending, sent, failed)
- [x] Написать unit тесты

#### 1.2.6. UserDigestItem Model (renamed from DigestItem)
- [x] Создать `app/models/user_digest_item.rb`
- [x] Добавить associations (belongs_to :user_digest, :post)
- [x] Добавить validations
- [x] Написать unit тесты

### 1.3. Базовый онбординг (Bot Commands)

#### 1.3.1. Start Command
- [x] Создать `app/controllers/telegram_webhook_controller.rb` (используем единый контроллер вместо отдельных)
- [x] Реализовать приветственное сообщение
- [x] Реализовать создание пользователя в БД
- [x] Добавить краткую инструкцию по использованию
- [x] Добавить inline кнопки для быстрого старта
- [x] Написать integration тесты

#### 1.3.2. Add Channel Command
- [ ] Создать `app/controllers/telegram/commands/channel_controller.rb`
- [ ] Реализовать `/add @channelname` команду
- [ ] Добавить валидацию канала через Telegram API
- [ ] Создать подписку в БД
- [ ] Добавить feedback пользователю (успех/ошибка)
- [ ] Написать integration тесты

#### 1.3.3. List Channels Command
- [x] Реализовать `/list` команду в `TelegramWebhookController` через `SubscriptionCommands` concern
- [x] Показать список подписок с приоритетами
- [x] Добавить inline кнопки для управления (удалить, изменить приоритет)
- [x] Написать integration тесты

#### 1.3.4. Remove Channel Command
- [ ] Реализовать `/remove @channelname` команду
- [ ] Удалить подписку из БД
- [ ] Добавить подтверждение действия
- [ ] Написать integration тесты

#### 1.3.5. Settings Command
- [ ] Создать `app/controllers/telegram/commands/settings_controller.rb`
- [ ] Реализовать `/settings` команду
- [ ] Показать текущие настройки
- [ ] Добавить inline меню для изменения:
  - [ ] Частоты доставки (delivery_frequency)
  - [ ] Формата контента (content_format)
  - [ ] Строгости фильтрации (filter_strictness)
- [ ] Сохранять изменения в БД
- [ ] Написать integration тесты

### 1.4. AI Sessions Infrastructure (НОВОЕ - КРИТИЧЕСКИ ВАЖНО)

> **ВАЖНО:** Эта фаза должна быть выполнена ДО Phase 1.6 "AI фильтрация"
> Она закладывает фундамент для персонализации и эффективной работы с AI.

#### 1.4.1. Chat Model Extension
- [x] Установить ruby_llm Rails integration: `rails generate ruby_llm:install`
- [x] Расширить существующую таблицу `chats`
  - [x] Добавить `telegram_user_id` (foreign key)
  - [x] Добавить `session_type` (enum: classification, summarization, personalization, digest_generation)
  - [x] Добавить `status` (enum: active, archived)
  - [x] Добавить `context` (jsonb для хранения контекста сессии)
- [x] Обновить модель `Chat` (уже использует `acts_as_chat`)
  - [x] Добавить связь `belongs_to :telegram_user`
  - [ ] Добавить enum для session_type и status
  - [ ] Добавить store_accessor для context
- [x] Добавить индексы:
  - [x] `index_chats_on_telegram_user_id_and_session_type`
  - [x] `index_chats_on_status`
  - [x] `index_chats_on_context` (GIN)
- [ ] Написать unit тесты для расширенной модели Chat

#### 1.4.2. TelegramUser Model Updates для Chat
- [ ] Добавить `has_many :chats` в TelegramUser модель
- [ ] Реализовать `chat_for(type)` - получить или создать чат
- [ ] Реализовать `build_initial_context` - построить начальный контекст
- [ ] Реализовать `recent_feedback_summary` - сводка последнего фидбека
- [ ] Написать unit тесты для новых методов

#### 1.4.3. Chat Management Service
- [ ] Создать `app/services/ai/chat_manager.rb`
- [ ] Реализовать `with_context` блок для работы с чатом
- [ ] Реализовать управление контекстным окном (sliding window)
- [ ] Реализовать выбор важных сообщений из истории
- [ ] Реализовать архивацию старых сообщений (> 90 дней)
- [ ] Реализовать compacting истории для больших чатов (> 100 сообщений)
- [ ] Написать service тесты

#### 1.4.4. Structured Output Schemas
- [ ] Создать базовый `app/schemas/base_schema.rb`
- [ ] Создать `app/schemas/post_classification_schema.rb`
  - [ ] `importance_score` (number, 0-100)
  - [ ] `is_ad` (boolean)
  - [ ] `is_fluff` (boolean)
  - [ ] `reasoning` (string)
  - [ ] `topics` (array of strings)
  - [ ] `duplicate_check` (object: is_likely_duplicate, similarity_score)
- [ ] Создать `app/schemas/summary_schema.rb`
- [ ] Создать `app/schemas/duplicate_detection_schema.rb`
- [ ] Написать тесты для всех схем

#### 1.4.5. AI Tools (Function Calling)
- [ ] Создать базовый `app/tools/base_tool.rb`
- [ ] Создать `app/tools/classify_post_tool.rb`
  - [ ] Определить параметры (importance_score, is_ad, is_fluff, topics, reasoning)
  - [ ] Реализовать метод `execute`
- [ ] Создать `app/tools/detect_duplicate_tool.rb`
- [ ] Создать `app/tools/extract_topics_tool.rb`
- [ ] Написать тесты для всех инструментов

#### 1.4.6. Context Builder Service
- [ ] Создать `app/services/ai/context_builder.rb`
- [ ] Реализовать `system_prompt` для разных типов сессий
- [ ] Реализовать `relevant_history` - выбор релевантных сообщений
- [ ] Реализовать стратегии:
  - [ ] Sliding window (последние N сообщений)
  - [ ] Importance-based (важные сообщения)
  - [ ] Few-shot examples (примеры из фидбека)
- [ ] Реализовать `feedback_context` - контекст из фидбека пользователя
- [ ] Реализовать `analyze_feedback_patterns` - анализ паттернов
- [ ] Добавить кеширование построенного контекста
- [ ] Написать service тесты

#### 1.4.7. Post Model Updates для Structured Data
- [x] Добавить JSONB поле `classification_data` в Post модель
- [x] Добавить массив `topics` (jsonb array)
- [x] Добавить `classification_reasoning` (text)
- [x] Добавить `classified_by_session_id` (foreign key к Chat)
- [x] Добавить GIN индексы на JSONB и array поля
- [ ] Обновить scopes для работы с JSONB:
  - [ ] `important` - использовать `classification_data->>'importance_score'`
  - [ ] `not_ads` - использовать `classification_data->>'is_ad'`
  - [ ] `by_topic` - использовать `topics && ARRAY[?]`
- [ ] Написать unit тесты

#### 1.4.8. Cleanup Job для Chats
- [ ] Создать `app/jobs/ai/cleanup_chats_job.rb`
- [ ] Реализовать архивацию неактивных чатов (> 90 дней)
- [ ] Реализовать удаление старых архивных чатов (> 180 дней)
- [ ] Реализовать compacting больших активных чатов
- [ ] Настроить периодический запуск (раз в день)
- [ ] Написать job тесты

### 1.5. Мониторинг каналов

#### 1.5.1. Channel Fetcher Library
- [ ] Создать `lib/telegram_client/api_wrapper.rb`
- [ ] Реализовать метод получения постов из канала
- [ ] Добавить обработку ошибок (rate limits, недоступность канала)
- [ ] Создать `lib/telegram_client/channel_fetcher.rb`
- [ ] Реализовать парсинг постов (текст, медиа, метаданные)
- [ ] Написать unit тесты

#### 1.5.2. Monitor Job
- [ ] Создать `app/jobs/channels/monitor_job.rb`
- [ ] Реализовать логику получения активных каналов
- [ ] Вызвать ChannelFetcher для каждого канала
- [ ] Запланировать ProcessPostJob для новых постов
- [ ] Добавить логирование
- [ ] Написать job тесты

#### 1.5.3. Schedule Monitor Job
- [ ] Настроить периодический запуск MonitorJob (каждые 5-10 минут)
- [ ] Использовать Solid Queue recurring jobs или cron
- [ ] Протестировать выполнение

#### 1.5.4. Process Post Job
- [ ] Создать `app/jobs/content/process_post_job.rb`
- [ ] Сохранить пост в БД
- [ ] Нормализовать контент
- [ ] Извлечь метаданные
- [ ] Запланировать ClassifyJob
- [ ] Написать job тесты

### 1.6. AI фильтрация (ОБНОВЛЕНО - использует AI Sessions)

> **ВАЖНО:** Эта фаза использует инфраструктуру из Phase 1.4
> Обеспечивает персонализированную классификацию с использованием истории

#### 1.6.1. AI Classifier Service (с Chat и Structured Output)
- [ ] Создать `app/services/content/ai_classifier.rb`
- [ ] Инициализировать с user и получать Chat через ChatManager
- [ ] Использовать Structured Output (PostClassificationSchema)
- [ ] Реализовать `classify(post)` с использованием Chat
- [ ] Реализовать построение системного промпта с контекстом пользователя
- [ ] Добавить few-shot examples из истории фидбека (через ContextBuilder)
- [ ] Сохранять structured результаты в `post.classification_data`
- [ ] Сохранять связь с Chat через `classified_by_chat_id`
- [ ] Добавить кеширование с зависимостями (user + post версии)
- [ ] Обработать ошибки AI API с retry логикой
- [ ] Логировать токены, latency, model использования
- [ ] Написать service тесты

#### 1.6.2. Batch Classifier Service
- [ ] Создать `app/services/content/batch_classifier.rb`
- [ ] Реализовать классификацию нескольких постов одним AI запросом
- [ ] Оптимизировать использование токенов (batch до 10 постов)
- [ ] Использовать Chat для сохранения batch контекста
- [ ] Добавить параллельную обработку с Async (опционально)
- [ ] Написать service тесты

#### 1.6.3. Cached AI Service
- [ ] Создать `app/services/ai/cached_service.rb`
- [ ] Реализовать `include Cacheable` для кеширования с зависимостями
- [ ] Реализовать автоматическую инвалидацию при изменении user/post
- [ ] Настроить разные TTL для разных операций:
  - [ ] classify: 24 часа
  - [ ] summarize: 12 часов
  - [ ] detect_duplicate: 7 дней
- [ ] Написать service тесты

#### 1.6.4. Content Filter Service (context-aware)
- [ ] Создать `app/services/content/filter.rb`
- [ ] Реализовать фильтрацию постов по importance_score из classification_data
- [ ] Учитывать filter_strictness пользователя
- [ ] Использовать персональный контекст из Chat
- [ ] Фильтровать рекламу и шелуху (is_ad, is_fluff)
- [ ] Фильтровать по темам если настроены в UserPreference
- [ ] Написать service тесты

#### 1.6.5. Classify Job (обновлено)
- [ ] Создать `app/jobs/content/classify_job.rb`
- [ ] Получить всех пользователей подписанных на канал поста
- [ ] Для каждого пользователя вызвать AIClassifier с его контекстом
- [ ] Сохранить персональную классификацию в PostClassification
- [ ] Сохранить общую классификацию в Post.classification_data
- [ ] Сохранить связь с Chat
- [ ] Добавить retry логику при ошибках AI API
- [ ] Логировать метрики (tokens, latency, success rate)
- [ ] Написать job тесты

#### 1.6.6. Streaming Support для дайджестов
- [ ] Обновить DigestBuilder для поддержки streaming
- [ ] Реализовать streaming при генерации саммари
- [ ] Реализовать обновление Telegram сообщения в реальном времени
- [ ] Добавить индикатор прогресса ("Генерирую дайджест...")
- [ ] Оптимизировать частоту обновлений (каждые 10 чанков)
- [ ] Написать integration тесты

#### 1.6.7. PostClassification Model (персональная классификация)
- [x] Создать `app/models/post_classification.rb`
- [ ] Добавить belongs_to :post, :telegram_user, :chat
- [ ] Добавить поля: importance_score, is_relevant, reasoning, confidence
- [ ] Реализовать `for_telegram_user_with_context(telegram_user, post)` - классификация с контекстом
- [x] Добавить индексы на telegram_user_id + post_id
- [ ] Написать unit тесты

#### 1.6.8. Integration Tests
- [ ] Протестировать полный flow:
  - [ ] Новый пост → ProcessPostJob → ClassifyJob
  - [ ] ClassifyJob использует Chat с контекстом пользователя
  - [ ] Результаты сохраняются structured в БД
  - [ ] Связь с Chat записывается
- [ ] Протестировать персонализацию:
  - [ ] Два пользователя получают разные оценки для одного поста
  - [ ] Оценки учитывают их историю фидбека
- [ ] Протестировать кеширование и инвалидацию

### 1.7. Формирование дайджестов

#### 1.7.1. Digest Builder Service
- [ ] Создать `app/services/digest/builder.rb`
- [ ] Реализовать получение важных постов для пользователя
- [ ] Реализовать фильтрацию по времени (с последнего дайджеста)
- [ ] Использовать ContentFilter для отбора постов
- [ ] Вызвать Ranker для сортировки
- [ ] Вызвать Formatter для форматирования
- [ ] Создать Digest запись в БД
- [ ] Написать service тесты

#### 1.6.2. Ranker Service
- [ ] Создать `app/services/digest/ranker.rb`
- [ ] Реализовать ранжирование постов по importance_score
- [ ] Учитывать приоритет канала (subscription.priority)
- [ ] Учитывать свежесть поста
- [ ] Написать service тесты

#### 1.6.3. Formatter Service
- [ ] Создать базовый `app/services/digest/formatter.rb`
- [ ] Создать `OriginalFormatter` (оригинальные посты)
- [ ] Создать `SummaryFormatter` (краткие саммари через AI)
- [ ] Создать `HeadlinesFormatter` (только заголовки)
- [ ] Реализовать форматирование Telegram сообщений (Markdown)
- [ ] Написать service тесты для каждого форматтера

#### 1.6.4. Build Digest Job
- [ ] Создать `app/jobs/digest/build_job.rb`
- [ ] Вызвать DigestBuilder для пользователя
- [ ] Запланировать DeliverJob
- [ ] Написать job тесты

#### 1.6.5. Deliver Digest Job
- [ ] Создать `app/jobs/digest/deliver_job.rb`
- [ ] Отправить дайджест через Telegram API
- [ ] Обновить статус Digest (sent/failed)
- [ ] Обработать ошибки отправки
- [ ] Добавить retry логику
- [ ] Написать job тесты

#### 1.6.6. Scheduler Service
- [ ] Создать `app/services/digest/scheduler.rb`
- [ ] Реализовать логику определения времени отправки
- [ ] Учитывать delivery_frequency
- [ ] Учитывать timezone пользователя
- [ ] Планировать BuildDigestJob для пользователей
- [ ] Написать service тесты

#### 1.6.7. Schedule Digests
- [ ] Настроить периодический запуск Scheduler (каждый час)
- [ ] Протестировать автоматическую отправку

### 1.8. Manual Digest Command

#### 1.8.1. Digest Command
- [ ] Создать `app/controllers/telegram/commands/digest_controller.rb`
- [ ] Реализовать `/digest` команду
- [ ] Запустить BuildDigestJob немедленно
- [ ] Отправить дайджест пользователю
- [ ] Добавить feedback (успех/пусто)
- [ ] Написать integration тесты

### 1.9. Help Command

#### 1.9.1. Help Command
- [ ] Создать `app/controllers/telegram/commands/help_controller.rb`
- [ ] Реализовать `/help` команду
- [ ] Показать список всех доступных команд
- [ ] Добавить краткое описание функционала
- [ ] Написать integration тесты

### 1.10. Error Handling & Logging

#### 1.10.1. Error Handling
- [ ] Настроить глобальный rescue для контроллеров
- [ ] Добавить логирование ошибок
- [ ] Настроить уведомления об ошибках (опционально: Sentry)
- [ ] Добавить user-friendly сообщения об ошибках

#### 1.10.2. Logging
- [ ] Настроить structured logging (JSON)
- [ ] Добавить correlation IDs
- [ ] Логировать все API запросы (Telegram, AI)
- [ ] Логировать выполнение jobs

### 1.11. Testing & Documentation

#### 1.11.1. Integration Tests
- [ ] Написать end-to-end тест: онбординг → добавление канала → получение дайджеста
- [ ] Написать тесты для всех bot команд
- [ ] Протестировать error scenarios

#### 1.11.2. Documentation
- [ ] Обновить README с инструкциями по настройке
- [ ] Документировать все environment variables
- [ ] Создать примеры использования команд

### 1.12. Deployment Preparation

#### 1.12.1. Environment Setup
- [ ] Настроить production environment
- [ ] Настроить credentials для API ключей
- [ ] Настроить database для production
- [ ] Настроить Solid Queue workers

#### 1.12.2. Deploy
- [ ] Задеплоить на production (Kamal/Heroku/VPS)
- [ ] Протестировать бота в production
- [ ] Настроить мониторинг (uptime, logs)

---

## Phase 2: Персонализация и улучшения

### 2.1. Дедупликация
- [ ] Создать `Deduplication Service`
- [ ] Использовать AI embeddings для поиска похожих постов
- [ ] Реализовать кластеризацию дубликатов
- [ ] Выбирать лучший вариант из дубликатов
- [ ] Обновить Post модель (is_duplicate_of)

### 2.2. Персонализация через фидбек (ОБНОВЛЕНО - использует AI Sessions)

> **ВАЖНО:** Эта фаза расширяет возможности AI Sessions для персонализации
> Использует накопленную историю для улучшения классификации

#### 2.2.1. Feedback Model
- [x] Создать `app/models/feedback.rb`
- [ ] Добавить belongs_to :telegram_user, :post
- [ ] Добавить enum sentiment: { dislike: -1, neutral: 0, like: 1 }
- [ ] Добавить after_create callback для обновления AI Session
- [ ] Реализовать метод `update_personalization_session`
- [x] Добавить индексы на telegram_user_id, post_id, created_at
- [ ] Написать unit тесты

#### 2.2.2. Feedback Controller (Telegram Bot)
- [ ] Создать `app/controllers/telegram/commands/feedback_controller.rb`
- [ ] Добавить inline кнопки 👍/👎 к постам в дайджесте
- [ ] Реализовать обработку callback queries
- [ ] Сохранить feedback в БД
- [ ] Запланировать PersonalizationUpdateJob
- [ ] Отправить подтверждение пользователю
- [ ] Написать integration тесты

#### 2.2.3. Chat Updates для фидбека
- [ ] Добавить метод `add_feedback_example(post, feedback)` в Chat
- [ ] Хранить последние 20 примеров фидбека в metadata['feedback_examples']
- [ ] Обновлять updated_at при добавлении фидбека
- [ ] Написать unit тесты

#### 2.2.4. Few-Shot Builder Service
- [ ] Создать `app/services/personalization/few_shot_builder.rb`
- [ ] Реализовать `build_examples` - построение few-shot примеров
- [ ] Сбалансировать liked и disliked примеры (по 5 каждого)
- [ ] Форматировать примеры в user/assistant пары
- [ ] Написать service тесты

#### 2.2.5. Personalization Update Job
- [ ] Создать `app/jobs/personalization_update_job.rb`
- [ ] Получить Chat персонализации для пользователя
- [ ] Проанализировать новый фидбек через AI
- [ ] Обновить понимание предпочтений в истории чата
- [ ] Обновить UserPreference если нужно
- [ ] Написать job тесты

#### 2.2.6. UserPreference Model
- [x] Создать `app/models/user_preference.rb`
- [ ] Добавить belongs_to :telegram_user
- [ ] Добавить JSONB поля для хранения:
  - [x] `topic_weights` - персональные веса тем
  - [x] `channel_weights` - веса каналов
  - [x] `adjusted_importance_threshold` - динамический порог важности
  - [x] `personalization_data` - дополнительные данные персонализации
- [ ] Реализовать `initialize_topic_weights`
- [ ] Реализовать `adjust_topic_weight(topic, feedback)`
- [ ] Реализовать `weighted_importance_score(post)` - пересчет оценки
- [x] Добавить индексы на topic_weights, channel_weights (GIN)
- [ ] Написать unit тесты

#### 2.2.7. Threshold Adjuster Service
- [ ] Создать `app/services/personalization/threshold_adjuster.rb`
- [ ] Реализовать `adjusted_threshold` - динамическая корректировка
- [ ] Реализовать `base_threshold_for_strictness` - базовые пороги
- [ ] Реализовать `calculate_personal_adjustment` - анализ фидбека
- [ ] Учитывать паттерны лайков/дизлайков за последние 7 дней
- [ ] Корректировка порога на основе несоответствий
- [ ] Написать service тесты

#### 2.2.8. Context-Aware Classification Updates
- [ ] Обновить AIClassifier для использования Few-Shot Builder
- [ ] Добавлять few-shot примеры в контекст перед классификацией
- [ ] Использовать ThresholdAdjuster для динамических порогов
- [ ] Использовать UserPreference.weighted_importance_score
- [ ] Логировать влияние персонализации на оценки
- [ ] Написать integration тесты

#### 2.2.9. Feedback Analytics
- [ ] Создать `app/services/personalization/feedback_analyzer.rb`
- [ ] Реализовать анализ паттернов фидбека:
  - [ ] Топ понравившихся тем
  - [ ] Топ отклоненных тем
  - [ ] Средняя оценка понравившихся постов
  - [ ] Correlation между AI-оценкой и фидбеком
- [ ] Использовать результаты в ContextBuilder
- [ ] Написать service тесты

#### 2.2.10. Integration Tests
- [ ] Протестировать полный flow персонализации:
  - [ ] Пользователь дает фидбек (лайк/дизлайк)
  - [ ] Feedback сохраняется и обновляет Chat
  - [ ] PersonalizationUpdateJob обрабатывает фидбек
  - [ ] Следующая классификация учитывает фидбек
  - [ ] Оценки постов изменяются на основе истории
- [ ] Протестировать улучшение точности:
  - [ ] Measure correlation до персонализации
  - [ ] Measure correlation после 10+ фидбеков
  - [ ] Verify improvement > 15%

### 2.3. Статистика
- [ ] Создать `StatsController` (/stats команда)
- [ ] Показывать статистику пользователя:
  - Количество подписок
  - Всего постов проанализировано
  - Отфильтровано постов
  - Дайджестов получено
- [ ] Создать `Analytics Service` для сбора метрик

### 2.4. Улучшенные форматы
- [ ] Создать `UnifiedDigestFormatter` (единый саммари всех постов)
- [ ] Создать `ComboFormatter` (топ-3 + саммари остальных)
- [ ] Добавить группировку по темам в дайджесте

---

## Phase 3: Социальные функции и рекомендации

### 3.1. Рекомендации каналов
- [ ] Создать `ChannelRecommendation Model`
- [ ] Создать `Recommendation Service`
- [ ] Построить социальный граф каналов (collaborative filtering)
- [ ] Создать `DiscoverController` (/discover команда)
- [ ] Показывать рекомендованные каналы

### 3.2. Тематическая фильтрация
- [ ] Добавить классификацию постов по темам (AI)
- [ ] Создать `TopicPreference Model`
- [ ] Позволить пользователям выбирать интересные темы
- [ ] Фильтровать дайджесты по темам

### 3.3. Продвинутая аналитика
- [ ] Dashboard для администратора
- [ ] Метрики:
  - DAU/MAU
  - Retention rate
  - Top channels
  - AI classification accuracy
- [ ] Visualizations

---

## Phase 4: Масштабирование и ML

### 4.1. A/B тестирование
- [ ] Создать A/B тестирование framework
- [ ] Тестировать разные форматы дайджестов
- [ ] Тестировать разные стратегии ранжирования

### 4.2. ML модели
- [ ] Обучить собственную модель предсказания предпочтений
- [ ] Использовать для ранжирования вместо простых правил

### 4.3. Multi-language support
- [ ] Определение языка постов
- [ ] Перевод дайджестов (опционально)
- [ ] Локализация bot интерфейса

### 4.4. Web интерфейс
- [ ] Web dashboard для пользователей
- [ ] Управление настройками через web
- [ ] Просмотр истории дайджестов
