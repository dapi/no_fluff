# NoFluff Bot - ROADMAP

## Phase 1: MVP (Минимально жизнеспособный продукт)

### 1.1. Инфраструктура и базовая настройка

#### 1.1.1. Database Setup
- [ ] Создать миграции для основных таблиц
  - [ ] `users` (telegram_id, username, delivery_frequency, content_format, filter_strictness, timezone)
  - [ ] `channels` (telegram_id, username, title, description, subscribers_count)
  - [ ] `subscriptions` (user_id, channel_id, priority, active)
  - [ ] `posts` (channel_id, telegram_message_id, text, media_urls, published_at, is_important, importance_score, is_ad, is_duplicate_of)
  - [ ] `digests` (user_id, status, scheduled_for, sent_at, posts_analyzed_count, posts_included_count)
  - [ ] `digest_items` (digest_id, post_id, position)
- [ ] Добавить индексы
  - [ ] `index_users_on_telegram_id` (unique)
  - [ ] `index_channels_on_telegram_id` (unique)
  - [ ] `index_posts_on_channel_id_and_published_at`
  - [ ] `index_posts_on_is_important`
  - [ ] `index_subscriptions_on_user_id_and_channel_id` (unique)
- [ ] Запустить миграции

#### 1.1.2. Telegram Bot Setup
- [ ] Настроить telegram-bot-ruby gem
- [ ] Создать `config/initializers/telegram.rb`
- [ ] Настроить webhook или polling (выбрать стратегию)
- [ ] Создать базовый `Telegram::WebhookController`
- [ ] Добавить routes для webhook
- [ ] Протестировать подключение к Telegram

#### 1.1.3. AI/LLM Setup
- [ ] Настроить ruby_llm gem
- [ ] Создать `config/initializers/ruby_llm.rb`
- [ ] Настроить API ключи (OpenAI/Anthropic/другие)
- [ ] Создать базовый wrapper `lib/ai/classifier.rb`
- [ ] Протестировать подключение к AI API

#### 1.1.4. Background Jobs Setup
- [ ] Настроить Solid Queue
- [ ] Создать конфигурацию для разных типов джобов
- [ ] Настроить приоритеты очередей
- [ ] Создать базовый ApplicationJob

### 1.2. Модели и базовая валидация

#### 1.2.1. User Model
- [ ] Создать `app/models/user.rb`
- [ ] Добавить enum для `delivery_frequency`
- [ ] Добавить enum для `content_format`
- [ ] Добавить enum для `filter_strictness`
- [ ] Добавить associations (has_many :subscriptions, :digests)
- [ ] Добавить validations
- [ ] Добавить scopes (active_users, by_delivery_time)
- [ ] Написать unit тесты

#### 1.2.2. Channel Model
- [ ] Создать `app/models/channel.rb`
- [ ] Добавить associations (has_many :subscriptions, :posts)
- [ ] Добавить validations (telegram_id uniqueness)
- [ ] Добавить scopes (active_channels, by_subscribers)
- [ ] Добавить методы для работы с Telegram API
- [ ] Написать unit тесты

#### 1.2.3. Subscription Model
- [ ] Создать `app/models/subscription.rb`
- [ ] Добавить associations (belongs_to :user, :channel)
- [ ] Добавить validations (uniqueness, priority range)
- [ ] Добавить scopes (active, by_priority)
- [ ] Написать unit тесты

#### 1.2.4. Post Model
- [ ] Создать `app/models/post.rb`
- [ ] Добавить associations (belongs_to :channel)
- [ ] Добавить validations
- [ ] Добавить scopes (important, not_ads, unique, recent)
- [ ] Добавить методы для работы с метаданными
- [ ] Написать unit тесты

#### 1.2.5. Digest Model
- [ ] Создать `app/models/digest.rb`
- [ ] Добавить enum для `status`
- [ ] Добавить associations (belongs_to :user, has_many :digest_items, has_many :posts through: :digest_items)
- [ ] Добавить validations
- [ ] Добавить scopes (pending, sent, failed)
- [ ] Написать unit тесты

#### 1.2.6. DigestItem Model
- [ ] Создать `app/models/digest_item.rb`
- [ ] Добавить associations (belongs_to :digest, :post)
- [ ] Добавить validations
- [ ] Написать unit тесты

### 1.3. Базовый онбординг (Bot Commands)

#### 1.3.1. Start Command
- [ ] Создать `app/controllers/telegram/commands/start_controller.rb`
- [ ] Реализовать приветственное сообщение
- [ ] Реализовать создание пользователя в БД
- [ ] Добавить краткую инструкцию по использованию
- [ ] Добавить inline кнопки для быстрого старта
- [ ] Написать integration тесты

#### 1.3.2. Add Channel Command
- [ ] Создать `app/controllers/telegram/commands/channel_controller.rb`
- [ ] Реализовать `/add @channelname` команду
- [ ] Добавить валидацию канала через Telegram API
- [ ] Создать подписку в БД
- [ ] Добавить feedback пользователю (успех/ошибка)
- [ ] Написать integration тесты

#### 1.3.3. List Channels Command
- [ ] Реализовать `/list` команду в `ChannelController`
- [ ] Показать список подписок с приоритетами
- [ ] Добавить inline кнопки для управления (удалить, изменить приоритет)
- [ ] Написать integration тесты

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

### 1.4. Мониторинг каналов

#### 1.4.1. Channel Fetcher Library
- [ ] Создать `lib/telegram_client/api_wrapper.rb`
- [ ] Реализовать метод получения постов из канала
- [ ] Добавить обработку ошибок (rate limits, недоступность канала)
- [ ] Создать `lib/telegram_client/channel_fetcher.rb`
- [ ] Реализовать парсинг постов (текст, медиа, метаданные)
- [ ] Написать unit тесты

#### 1.4.2. Monitor Job
- [ ] Создать `app/jobs/channels/monitor_job.rb`
- [ ] Реализовать логику получения активных каналов
- [ ] Вызвать ChannelFetcher для каждого канала
- [ ] Запланировать ProcessPostJob для новых постов
- [ ] Добавить логирование
- [ ] Написать job тесты

#### 1.4.3. Schedule Monitor Job
- [ ] Настроить периодический запуск MonitorJob (каждые 5-10 минут)
- [ ] Использовать Solid Queue recurring jobs или cron
- [ ] Протестировать выполнение

#### 1.4.4. Process Post Job
- [ ] Создать `app/jobs/content/process_post_job.rb`
- [ ] Сохранить пост в БД
- [ ] Нормализовать контент
- [ ] Извлечь метаданные
- [ ] Запланировать ClassifyJob
- [ ] Написать job тесты

### 1.5. AI фильтрация

#### 1.5.1. AI Classifier Service
- [ ] Создать `app/services/content/ai_classifier.rb`
- [ ] Реализовать классификацию важности поста (0-100)
- [ ] Реализовать определение рекламы (true/false)
- [ ] Использовать ruby_llm для запросов к AI
- [ ] Добавить prompt engineering (системный промпт)
- [ ] Добавить кеширование результатов (Solid Cache)
- [ ] Обработать ошибки AI API
- [ ] Написать service тесты

#### 1.5.2. Content Filter Service
- [ ] Создать `app/services/content/filter.rb`
- [ ] Реализовать фильтрацию постов по importance_score
- [ ] Учитывать filter_strictness пользователя
- [ ] Фильтровать рекламу
- [ ] Написать service тесты

#### 1.5.3. Classify Job
- [ ] Создать `app/jobs/content/classify_job.rb`
- [ ] Вызвать AIClassifier для поста
- [ ] Сохранить результаты в БД (importance_score, is_ad)
- [ ] Добавить retry логику при ошибках
- [ ] Написать job тесты

#### 1.5.4. Integration
- [ ] Интегрировать ClassifyJob с ProcessPostJob
- [ ] Протестировать полный flow: новый пост → классификация → сохранение

### 1.6. Формирование дайджестов

#### 1.6.1. Digest Builder Service
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

### 1.7. Manual Digest Command

#### 1.7.1. Digest Command
- [ ] Создать `app/controllers/telegram/commands/digest_controller.rb`
- [ ] Реализовать `/digest` команду
- [ ] Запустить BuildDigestJob немедленно
- [ ] Отправить дайджест пользователю
- [ ] Добавить feedback (успех/пусто)
- [ ] Написать integration тесты

### 1.8. Help Command

#### 1.8.1. Help Command
- [ ] Создать `app/controllers/telegram/commands/help_controller.rb`
- [ ] Реализовать `/help` команду
- [ ] Показать список всех доступных команд
- [ ] Добавить краткое описание функционала
- [ ] Написать integration тесты

### 1.9. Error Handling & Logging

#### 1.9.1. Error Handling
- [ ] Настроить глобальный rescue для контроллеров
- [ ] Добавить логирование ошибок
- [ ] Настроить уведомления об ошибках (опционально: Sentry)
- [ ] Добавить user-friendly сообщения об ошибках

#### 1.9.2. Logging
- [ ] Настроить structured logging (JSON)
- [ ] Добавить correlation IDs
- [ ] Логировать все API запросы (Telegram, AI)
- [ ] Логировать выполнение jobs

### 1.10. Testing & Documentation

#### 1.10.1. Integration Tests
- [ ] Написать end-to-end тест: онбординг → добавление канала → получение дайджеста
- [ ] Написать тесты для всех bot команд
- [ ] Протестировать error scenarios

#### 1.10.2. Documentation
- [ ] Обновить README с инструкциями по настройке
- [ ] Документировать все environment variables
- [ ] Создать примеры использования команд

### 1.11. Deployment Preparation

#### 1.11.1. Environment Setup
- [ ] Настроить production environment
- [ ] Настроить credentials для API ключей
- [ ] Настроить database для production
- [ ] Настроить Solid Queue workers

#### 1.11.2. Deploy
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

### 2.2. Персонализация через фидбек
- [ ] Создать `Feedback Model` (user_id, post_id, sentiment)
- [ ] Создать `FeedbackController` (👍/👎 inline кнопки)
- [ ] Создать `Personalization Service`
- [ ] Корректировать веса важности на основе фидбека
- [ ] Создать `UserPreference Model` для хранения персональных весов

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
