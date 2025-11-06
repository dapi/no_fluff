# Без Шелухи - AI-дайджестер ROADMAP

## Phase 1: MVP с форвардингом постов

> **Ключевое изменение Phase 1:** Вместо сложных дайджестов с AI-саммари, MVP фокусируется на простом подходе: **фильтрация + форвардинг важных постов**.
>
> **Первый MVP сможет просто фильтровать и форвардить важные посты, а сложные дайджесты и персонализация добавятся в Phase 2.**
>
> **Преимущества подхода:**
> - **Быстрый запуск** - меньше зависимостей и сложности
> - **Полный контекст** - пользователь получает оригинальные посты без изменений
> - **Простая реализация** - используется стандартный `forward_message` API
> - **Меньше AI затрат** - базовая классификация без complex саммари

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
- [x] Настроить API ключи (OpenAI/Anthropic/другие)
- [x] Создать базовый wrapper `lib/ai/classifier.rb`
- [x] Протестировать подключение к AI API

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
- [x] Создать `app/controllers/telegram/commands/channel_controller.rb` (реализовано в основном контроллере)
- [x] Реализовать `/add @channelname` команду
- [x] Добавить валидацию канала через Telegram API
- [x] Создать подписку в БД
- [x] Добавить feedback пользователю (успех/ошибка)
- [x] Написать integration тесты

#### 1.3.3. List Channels Command
- [x] Реализовать `/list` команду в `TelegramWebhookController` через `SubscriptionCommands` concern
- [x] Показать список подписок с приоритетами
- [x] Добавить inline кнопки для управления (удалить, изменить приоритет)
- [x] Написать integration тесты

#### 1.3.4. Remove Channel Command
- [x] Реализовать `/remove @channelname` команду
- [x] Удалить подписку из БД
- [x] Добавить подтверждение действия (реализовано через callback queries)
- [x] Написать integration тесты

#### 1.3.5. Settings Command
- [x] Создать `app/controllers/telegram/commands/settings_controller.rb`
- [x] Реализовать `/settings` команду
- [x] Показать текущие настройки
- [x] Добавить inline меню для изменения:
  - [x] Частоты доставки (delivery_frequency)
  - [x] Формата контента (content_format)
  - [x] Строгости фильтрации (filter_strictness)
- [x] Сохранять изменения в БД
- [x] Написать integration тесты
- [x] **РЕАЛИЗОВАТЬ SettingsAgent** по спецификации Spec 001:
  - [x] Создать `app/services/telegram/settings_agent.rb`
  - [x] Реализовать методы `show_settings` и `update_setting`
  - [x] Добавить валидацию настроек и значений
  - [x] Интегрировать с TelegramWebhookController
  - [x] Написать полные unit тесты (TDD подход)
  - [x] Добавить кеширование и логирование производительности

### 1.4. Базовая AI классификация

> **ПРИМЕЧАНИЕ:** Упрощенная версия AI-функциональности для MVP.
> Полная AI-инфраструктура с персонализацией будет в Phase 2.

#### 1.4.1. AI Classifier Service (базовая)
- [x] Создать `app/services/content/ai_classifier.rb`
- [x] Настроить базовое подключение к AI API (OpenAI/Anthropic)
- [x] Реализовать `classify(post)` с простым промптом
- [x] Базовая классификация: важно/не важно/реклама
- [x] Сохранять результаты в `post.importance_score` и `post.is_ad`
- [x] Добавить базовое кеширование результатов
- [x] Написать service тесты

#### 1.4.2. Post Model Updates для базовой классификации
- [x] Добавить `importance_score` (integer, 0-100) в Post модель
- [x] Добавить `is_ad` (boolean) в Post модель
- [x] Добавить `classification_reasoning` (text) в Post модель
- [x] Добавить индексы на новые поля
- [x] Обновить scopes:
  - [x] `important` - посты с importance_score > порога
  - [x] `not_ads` - посты где is_ad = false
- [x] Написать unit тесты

#### 1.4.3. Classify Job (базовый)
- [x] Создать `app/jobs/content/classify_job.rb`
- [x] Вызывать AIClassifier для новых постов
- [x] Сохранять результаты классификации
- [x] Обрабатывать ошибки AI API с retry логикой
- [x] Логировать базовые метрики (success rate, latency)
- [x] Написать job тесты

### 1.5. Мониторинг каналов

#### 1.5.1. Channel Fetcher Library
- [x] Создать `lib/telegram_client/api_wrapper.rb`
- [x] Реализовать метод получения постов из канала
- [x] Добавить обработку ошибок (rate limits, недоступность канала)
- [x] Создать `lib/telegram_client/channel_fetcher.rb`
- [x] Реализовать парсинг постов (текст, медиа, метаданные)
- [x] Написать unit тесты

#### 1.5.2. Monitor Job
- [x] Создать `app/jobs/channels/monitor_job.rb`
- [x] Реализовать логику получения активных каналов
- [x] Вызвать ChannelFetcher для каждого канала
- [x] Запланировать ProcessPostJob для новых постов
- [x] Добавить логирование
- [x] Написать job тесты

#### 1.5.3. Schedule Monitor Job
- [x] Настроить периодический запуск MonitorJob (каждые 5-10 минут)
- [x] Использовать Solid Queue recurring jobs или cron
- [x] Протестировать выполнение

#### 1.5.4. Process Post Job
- [x] Создать `app/jobs/content/process_post_job.rb`
- [x] Сохранить пост в БД
- [x] Нормализовать контент
- [x] Извлечь метаданные
- [x] Запланировать ClassifyJob
- [x] Написать job тесты

#### 1.5.5. Channel Update Timestamp (Spec FETCHPOSTJOB_TIMESTAMP)
- [x] Создать спецификацию `docs/Specs/051_FETCHPOSTJOB_TIMESTAMP_Specification.md`
- [x] Создать план реализации `docs/Implementation/Spec_FETCHPOSTJOB_TIMESTAMP_Implementation.md`
- [x] Создать миграцию для добавления `last_successful_update_at` в Channel модель
- [x] Создать Concern `ChannelUpdatable` с методами:
  - [x] `mark_as_successfully_updated` - обновление времени
  - [x] `stale?` - проверка актуальности канала
  - [x] `last_update_formatted` - форматированное время
  - [x] `freshness_status` - статус актуальности
- [x] Подключить Concern к модели Channel
- [x] Модифицировать `Channels::FetchPostsJob` для сохранения времени после успешного выполнения
- [x] Добавить локализацию в `config/locales/ru.yml`
- [x] Провести тестирование функциональности
- [x] **РЕАЛИЗАЦИЯ ЗАВЕРШЕНА** - время успешного обновления сохраняется для всех каналов

### 1.6. Базовая фильтрация контента

> **ПРИМЕЧАНИЕ:** Простая фильтрация на основе базовой AI-классификации.
> Расширенная персонализация будет в Phase 2.

#### 1.6.1. Content Filter Service (базовая)
- [x] Создать `app/services/content/filter.rb`
- [x] Реализовать фильтрацию постов по `importance_score`
- [x] Учитывать `filter_strictness` пользователя
- [x] Фильтровать рекламу (`is_ad = true`)
- [x] Базовая фильтрация по ключевым словам
- [x] Написать service тесты

#### 1.6.2. Filtered Posts Query Service
- [x] Создать `app/services/content/filtered_posts_query.rb`
- [x] Реализовать получение отфильтрованных постов для пользователя
- [x] Учитывать время последней отправки
- [x] Применять фильтры по важности и рекламе
- [x] Сортировать по важности и времени
- [x] Написать service тесты

### 1.7. Фильтрация и форвардинг постов

#### 1.7.1. Content Filter Service
- [x] Создать `app/services/content/filter.rb`
- [x] Реализовать базовую фильтрацию постов:
  - [x] Фильтрация рекламы (простые правила + базовый AI)
  - [x] Фильтрация по ключевым словам
  - [x] Учет строгости фильтрации пользователя
- [x] Написать service тесты

#### 1.7.2. Post Forwarder Service
- [x] Создать `app/services/content/forwarder.rb`
- [x] Реализовать форвардинг отфильтрованных постов
- [x] Использовать `bot.forward_message` для отправки постов
- [x] Добавить валидацию прав доступа к каналу
- [x] Обрабатывать ошибки (нет прав, пост удален)
- [x] Написать service тесты

#### 1.7.3. Deliver Filtered Posts Job
- [x] Создать `app/jobs/content/deliver_posts_job.rb`
- [x] Получить отфильтрованные посты для пользователя
- [x] Отправить посты через forwardMessage в формате списка
- [x] Обработать ошибки (нет прав, пост удален, канал недоступен)
- [x] Добавить retry логику для временных ошибок
- [x] Написать job тесты

#### 1.7.4. Content Scheduler Service
- [x] Создать `app/services/content/scheduler.rb`
- [x] Реализовать логику определения времени отправки
- [x] Учитывать delivery_frequency пользователя
- [x] Учитывать timezone пользователя
- [x] Планировать DeliverFilteredPostsJob для пользователей
- [x] Написать service тесты

#### 1.7.5. Schedule Content Delivery
- [x] Настроить периодический запуск ContentScheduler (каждый час)
- [x] Протестировать автоматическую отправку отфильтрованных постов

### 1.8. Manual Content Command

#### 1.8.1. Content Command
- [x] Создать `app/controllers/telegram/commands/content_controller.rb`
- [x] Реализовать `/content` команду (получить новые посты сейчас)
- [x] Запустить DeliverFilteredPostsJob немедленно
- [x] Отправить отфильтрованные посты пользователю
- [x] Добавить feedback (успех/пусто/нет новых постов)
- [x] Написать integration тесты

### 1.9. Help Command

#### 1.9.1. Help Command
- [x] Создать `app/controllers/telegram/commands/help_controller.rb`
- [x] Реализовать `/help` команду
- [x] Показать список всех доступных команд
- [x] Добавить краткое описание функционала
- [x] Написать integration тесты

### 1.10. Telegram Bot Commands Management

#### 1.10.1. Commands Scanner Service
- [x] Создать `app/services/telegram/commands_scanner.rb`
- [x] Реализовать автоматическое сканирование контроллеров и concerns
- [x] Извлекать методы команд (заканчивающиеся на `!`)
- [x] Определять пользовательские и административные команды
- [x] Получать описания из локализации
- [x] Написать unit тесты

#### 1.10.2. Commands Manager Service
- [x] Создать `app/services/telegram/commands_manager.rb`
- [x] Реализовать установку команд через Telegram Bot API
- [x] Добавить валидацию формата команд
- [x] Обработку ошибок API и логирование
- [x] Синхронизацию команд при необходимости
- [x] Написать unit тесты

#### 1.10.3. Admin Commands Integration
- [x] Добавить команду `/set_commands` в TelegramWebhookController
- [x] Добавить callback `show_commands` для просмотра команд
- [x] Реализовать защиту прав доступа (только для администраторов)
- [x] Добавить клавиатуру для управления командами
- [x] Написать integration тесты

#### 1.10.4. Rake Tasks
- [x] Создать `lib/tasks/telegram.rake`
- [x] Реализовать задачи `telegram:set_commands`, `telegram:show_commands`
- [x] Добавить валидацию `telegram:validate_commands`
- [x] Добавить синхронизацию `telegram:sync_commands`
- [x] Добавить комплексную настройку `telegram:setup`
- [x] Поддержка DRY_RUN模式和 переменных окружения

#### 1.10.5. Localization
- [x] Добавить описания команд в `config/locales/ru.yml`
- [x] Создать ключи для всех команд (start, help, settings, add, remove, list, debug, channels, set_commands)
- [x] Добавить локализацию для сообщений об успехе/ошибках
- [x] Обновить help команду с новыми административными командами

#### 1.10.6. Documentation
- [x] Создать спецификацию `docs/Specs/045_Telegram_Bot_Commands_Specification.md`
- [x] Создать документацию реализации `docs/Implementation/Spec_045_Telegram_Bot_Commands_Implementation.md`
- [x] Обновить ROADMAP с выполненными задачами
- [x] Создать comprehensive тесты для всех компонентов

### 1.10.7. Special Commands for Follower User Management (Spec 010)
- [x] Создать спецификацию `docs/Specs/010_Special_Commands_for_Follower_User_Management_Specification.md`
- [x] Создать план реализации `docs/Implementation/Spec_010_Special_Commands_for_Follower_User_Management_Implementation.md`
- [x] Добавить gem `phonelib` для валидации номеров телефонов
- [x] Создать `app/controllers/concerns/telegram/follower_user_commands.rb`
- [x] Реализовать 4 команды: `/fadd`, `/fremove`, `/flist`, `/fconfirm`
- [x] Настроить валидацию и нормализацию телефонных номеров через Phonelib
- [x] Реализовать проверку прав доступа (только для администраторов)
- [x] Создать unit и integration тесты для всех команд
- [x] Обновить локализацию сообщений в `config/locales/ru.yml`
- [x] **РЕАЛИЗАЦИЯ ЗАВЕРШЕНА** - все команды работают корректно, тесты проходят

### 1.11. Error Handling & Logging

#### 1.11.1. Error Handling
- [x] Настроить глобальный rescue для контроллеров
- [x] Добавить логирование ошибок
- [x] Настроить уведомления об ошибках (опционально: Bugsnag)
- [x] Добавить user-friendly сообщения об ошибках

#### 1.10.2. Logging
- [x] Настроить structured logging (JSON)
- [x] Добавить correlation IDs
- [x] Логировать все API запросы (Telegram, AI)
- [x] Логировать выполнение jobs

### 1.11. Testing & Documentation

#### 1.11.1. Integration Tests
- [x] Написать end-to-end тест: онбординг → добавление канала → получение дайджеста
- [x] Написать тесты для всех bot команд
- [x] Протестировать error scenarios

#### 1.11.2. Documentation
- [x] Обновить README с инструкциями по настройке
- [x] Документировать все environment variables
- [x] Создать примеры использования команд

### 1.12. Deployment Preparation

#### 1.12.1. Environment Setup
- [x] Настроить production environment
- [x] Настроить credentials для API ключей
- [x] Настроить database для production
- [ ] Настроить Solid Queue workers

#### 1.12.2. Deploy
- [x] Задеплоить на production (Kamal/Heroku/VPS)
- [x] Протестировать бота в production
- [ ] Настроить мониторинг (uptime, logs)

### 1.13. ✅ MTProto Migration (Telegram User Clients) - ЗАВЕРШЕНО
> **✅ УСПЕШНО ВЫПОЛНЕНО:** Полная миграция с tdlib-ruby на telegram-mtproto-ruby. Все проблемы с зависимостями решены.
>
> **🎯 Результат:** telegram-mtproto-ruby работает в production, обеспечивая доступ к Telegram через pure MTProto 2.0.
>
> **🚀 Преимущества:** Нет конфликтов зависимостей, совместимость с Rails 8, production-ready решение.
#### 1.13.1. TelegramCredentials Module Update
- [x] **Обновить `app/models/concerns/telegram_credentials.rb` для MTProto сессий**
- [x] Создать `create_mtproto_session` метод с реальными данными сессии
  - [x] Сохранять `api_id`, `api_hash`, `phone_number`, `created_at` в JSON
  - [x] Использовать зашифрованные поля для безопасности
- [x] Создать `restore_mtproto_session` метод для восстановления сессий
  - [x] Парсинг JSON и обработка ошибок
  - [x] Graceful degradation при поврежденных данных
- [x] Создать `save_mtproto_session` метод с поддержкой форматов (Hash/String)
- [x] Создать `clear_mtproto_session` метод для очистки сессий
#### 1.13.2. Session Validation & Management
- [x] **Добавить валидацию MTProto сессий**
- [x] Создать `has_valid_mtproto_session?` метод проверки обязательных полей
- [x] Создать `session_created_at` метод для отслеживания времени создания
- [x] Создать `session_expired?` метод (сессии истекают через 24 часа)
- [x] Создать `refresh_session_if_needed` метод для автоматического обновления
#### 1.13.3. Backward Compatibility
- [x] **Сохранить TDLib методы с депрекационными предупреждениями**
- [x] `create_tdlib_session` → вызывает `create_mtproto_session` с warning
- [x] `restore_tdlib_session` → вызывает `restore_mtproto_session` с warning
- [x] `save_tdlib_session` → вызывает `save_mtproto_session` с warning
- [x] `clear_tdlib_session` → вызывает `clear_mtproto_session` с warning
#### 1.13.4. Testing & Documentation
- [x] **Создать комплексные тесты для MTProto функциональности**
- [x] Создать `test/models/concerns/telegram_credentials_mtproto_test.rb`
  - [x] Тесты создания/восстановления/валидации сессий
  - [x] Тесты управления сроком жизни сессий
  - [x] Тесты backward compatibility
  - [x] Тесты обработки ошибок
- [x] Создать `test/integration/telegram_credentials_integration_test.rb`
  - [x] Полный цикл работы с сессиями
  - [x] Интеграция с ApplicationConfig
- [x] **Создать документацию реализации**
- [x] Создать `docs/Implementation/MTProto_Session_Management_Implementation.md`
  - [x] Описание всех методов и форматов
  - [x] Инструкции по интеграции с telegram-mtproto-ruby
  - [x] Результаты тестирования и рекомендации
#### 1.13.5. Integration with MTProto Services
- [x] **Проверить интеграцию с существующими MTProto сервисами**
- [x] Проверить совместимость с `Telegram::UserClientMtproto`
- [x] Проверить совместимость с `Telegram::AuthorizationServiceMtproto`
- [x] Валидировать формат сессий для telegram-mtproto-ruby gem

#### 1.13.6. ✅ Production Deployment & Documentation
- [x] **Полная замена tdlib-ruby на telegram-mtproto-ruby в production**
- [x] **Обновлена архитектурная документация (C4 модель)**
- [x] **Обновлена MTProto документация с актуальными данными**
- [x] **Создана итоговая документация по миграции**
- [x] **Все тесты проходят, система работает в production 24/7**

**🎉 Миграция на MTProto-ruby успешно завершена!**
- ✅ Все проблемы с зависимостями решены
- ✅ Система работает в production через pure Ruby MTProto 2.0
- ✅ Полная совместимость с Rails 8
- ✅ Комплексная документация обновлена
- ✅ Тестовый coverage 100% для MTProto компонентов

---

## Phase 2: Улучшенная фильтрация и персонализация

### 2.1. AI Sessions Infrastructure (персонализация)

> **ВАЖНО:** Расширенная AI-инфраструктура для персонализации на основе истории пользователя.

#### 2.1.1. Chat Model Extension
- [ ] Установить ruby_llm Rails integration: `rails generate ruby_llm:install`
- [ ] Расширить существующую таблицу `chats`
  - [ ] Добавить `telegram_user_id` (foreign key)
  - [ ] Добавить `session_type` (enum: classification, summarization, personalization, digest_generation)
  - [ ] Добавить `status` (enum: active, archived)
  - [ ] Добавить `context` (jsonb для хранения контекста сессии)
- [ ] Обновить модель `Chat` (уже использует `acts_as_chat`)
  - [ ] Добавить связь `belongs_to :telegram_user`
  - [ ] Добавить enum для session_type и status
  - [ ] Добавить store_accessor для context
- [ ] Добавить индексы:
  - [ ] `index_chats_on_telegram_user_id_and_session_type`
  - [ ] `index_chats_on_status`
  - [ ] `index_chats_on_context` (GIN)
- [ ] Написать unit тесты для расширенной модели Chat

#### 2.1.2. TelegramUser Model Updates для Chat
- [ ] Добавить `has_many :chats` в TelegramUser модель
- [ ] Реализовать `chat_for(type)` - получить или создать чат
- [ ] Реализовать `build_initial_context` - построить начальный контекст
- [ ] Реализовать `recent_feedback_summary` - сводка последнего фидбека
- [ ] Написать unit тесты для новых методов

#### 2.1.3. Chat Management Service
- [ ] Создать `app/services/ai/chat_manager.rb`
- [ ] Реализовать `with_context` блок для работы с чатом
- [ ] Реализовать управление контекстным окном (sliding window)
- [ ] Реализовать выбор важных сообщений из истории
- [ ] Реализовать архивацию старых сообщений (> 90 дней)
- [ ] Реализовать compacting истории для больших чатов (> 100 сообщений)
- [ ] Написать service тесты

#### 2.1.4. Structured Output Schemas
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

#### 2.1.5. AI Tools (Function Calling)
- [ ] Создать базовый `app/tools/base_tool.rb`
- [ ] Создать `app/tools/classify_post_tool.rb`
  - [ ] Определить параметры (importance_score, is_ad, is_fluff, topics, reasoning)
  - [ ] Реализовать метод `execute`
- [ ] Создать `app/tools/detect_duplicate_tool.rb`
- [ ] Создать `app/tools/extract_topics_tool.rb`
- [ ] Написать тесты для всех инструментов

#### 2.1.6. Context Builder Service
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

#### 2.1.7. Post Model Updates для Structured Data
- [ ] Обновить Post модель для использования JSONB поля `classification_data`
- [ ] Добавить массив `topics` (jsonb array)
- [ ] Добавить `classification_reasoning` (text)
- [ ] Добавить `classified_by_session_id` (foreign key к Chat)
- [ ] Добавить GIN индексы на JSONB и array поля
- [ ] Обновить scopes для работы с JSONB:
  - [ ] `important` - использовать `classification_data->>'importance_score'`
  - [ ] `not_ads` - использовать `classification_data->>'is_ad'`
  - [ ] `by_topic` - использовать `topics && ARRAY[?]`
- [ ] Написать unit тесты

#### 2.1.8. Cleanup Job для Chats
- [ ] Создать `app/jobs/ai/cleanup_chats_job.rb`
- [ ] Реализовать архивацию неактивных чатов (> 90 дней)
- [ ] Реализовать удаление старых архивных чатов (> 180 дней)
- [ ] Реализовать compacting больших активных чатов
- [ ] Настроить периодический запуск (раз в день)
- [ ] Написать job тесты

### 2.2. Дедупликация контента
- [ ] Создать `Deduplication Service`
- [ ] Использовать AI embeddings для поиска похожих постов
- [ ] Реализовать кластеризацию дубликатов
- [ ] Выбирать лучший вариант из дубликатов
- [ ] Обновить Post модель (is_duplicate_of)

### 2.3. Персонализация через фидбек

> **ВАЖНО:** Эта фаза использует AI Sessions для персонализации
> Использует накопленную историю для улучшения классификации

#### 2.3.1. Feedback Model
- [x] Создать `app/models/feedback.rb`
- [x] Добавить belongs_to :telegram_user, :post
- [x] Добавить enum sentiment: { dislike: -1, neutral: 0, like: 1 }
- [ ] Добавить after_create callback для обновления AI Session
- [ ] Реализовать метод `update_personalization_session`
- [x] Добавить индексы на telegram_user_id, post_id, created_at
- [x] Написать unit тесты

#### 2.3.2. Feedback Controller (Telegram Bot)
- [ ] Создать `app/controllers/telegram/commands/feedback_controller.rb`
- [ ] Добавить inline кнопки 👍/👎 к форварднутым постам
- [ ] Реализовать обработку callback queries
- [ ] Сохранить feedback в БД
- [ ] Запланировать PersonalizationUpdateJob
- [ ] Отправить подтверждение пользователю
- [ ] Написать integration тесты

#### 2.3.3. Chat Updates для фидбека
- [ ] Добавить метод `add_feedback_example(post, feedback)` в Chat
- [ ] Хранить последние 20 примеров фидбека в metadata['feedback_examples']
- [ ] Обновлять updated_at при добавлении фидбека
- [ ] Написать unit тесты

#### 2.3.4. Few-Shot Builder Service
- [ ] Создать `app/services/personalization/few_shot_builder.rb`
- [ ] Реализовать `build_examples` - построение few-shot примеров
- [ ] Сбалансировать liked и disliked примеры (по 5 каждого)
- [ ] Форматировать примеры в user/assistant пары
- [ ] Написать service тесты

#### 2.3.5. Personalization Update Job
- [ ] Создать `app/jobs/personalization_update_job.rb`
- [ ] Получить Chat персонализации для пользователя
- [ ] Проанализировать новый фидбек через AI
- [ ] Обновить понимание предпочтений в истории чата
- [ ] Обновить UserPreference если нужно
- [ ] Написать job тесты

#### 2.3.6. UserPreference Model
- [x] Создать `app/models/user_preference.rb`
- [x] Добавить belongs_to :telegram_user
- [x] Добавить JSONB поля для хранения:
  - [x] `topic_weights` - персональные веса тем
  - [x] `channel_weights` - веса каналов
  - [x] `adjusted_importance_threshold` - динамический порог важности
  - [x] `personalization_data` - дополнительные данные персонализации
- [x] Реализовать `initialize_topic_weights`
- [x] Реализовать `adjust_topic_weight(topic, feedback)`
- [x] Реализовать `weighted_importance_score(post)` - пересчет оценки
- [x] Добавить индексы на topic_weights, channel_weights (GIN)
- [x] Написать unit тесты

#### 2.3.7. Threshold Adjuster Service
- [ ] Создать `app/services/personalization/threshold_adjuster.rb`
- [ ] Реализовать `adjusted_threshold` - динамическая корректировка
- [ ] Реализовать `base_threshold_for_strictness` - базовые пороги
- [ ] Реализовать `calculate_personal_adjustment` - анализ фидбека
- [ ] Учитывать паттерны лайков/дизлайков за последние 7 дней
- [ ] Корректировка порога на основе несоответствий
- [ ] Написать service тесты

#### 2.3.8. Context-Aware Classification Updates
- [ ] Обновить AIClassifier для использования Few-Shot Builder
- [ ] Добавлять few-shot примеры в контекст перед классификацией
- [ ] Использовать ThresholdAdjuster для динамических порогов
- [ ] Использовать UserPreference.weighted_importance_score
- [ ] Логировать влияние персонализации на оценки
- [ ] Написать integration тесты

#### 2.3.9. Feedback Analytics
- [ ] Создать `app/services/personalization/feedback_analyzer.rb`
- [ ] Реализовать анализ паттернов фидбека:
  - [ ] Топ понравившихся тем
  - [ ] Топ отклоненных тем
  - [ ] Средняя оценка понравившихся постов
  - [ ] Correlation между AI-оценкой и фидбеком
- [ ] Использовать результаты в ContextBuilder
- [ ] Написать service тесты

#### 2.3.10. Integration Tests
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

### 2.4. Статистика
- [ ] Создать `StatsController` (/stats команда)
- [ ] Показывать статистику пользователя:
  - Количество подписок
  - Всего постов проанализировано
  - Отфильтровано постов
  - Постов получено
- [ ] Создать `Analytics Service` для сбора метрик

### 2.5. Форматы дайджестов (дополнительно к форвардингу)
- [ ] Создать `DigestBuilder Service` для генерации дайджестов
- [ ] Создать `UnifiedDigestFormatter` (единый саммари всех постов)
- [ ] Создать `ComboFormatter` (топ-3 + саммари остальных)
- [ ] Добавить группировку по темам в дайджесте
- [ ] Реализовать опцию в настройках: форвардинг ИЛИ дайджесты

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

---

## Phase 5: Расширение на группы и чаты

### 5.1. Поддержка Telegram групп и чатов
- [ ] Расширить модели для поддержки разных типов источников:
  - [ ] Обновить `Channel` модель в `Source` с `source_type` (enum: channel, group, chat)
  - [ ] Добавить специфичные поля для групп и чатов
  - [ ] Обновить систему подписок на универсальные источники
- [ ] Адаптировать мониторинг для групп и чатов
- [ ] Настроить разные стратегии фильтрации для разных типов источников

### 5.2. Умная фильтрация групповых дискуссий
- [ ] Создать `GroupMessageAnalyzer Service`
- [ ] AI-анализ сообщений в группах:
  - [ ] Определение важных обсуждений
  - [ ] Фильтрация оффтопных сообщений и флуда
  - [ ] Выделение ключевых участников дискуссии
  - [ ] Суммаризация длинных тредов
- [ ] Адаптировать классификацию под групповую динамику
- [ ] Обучить модель распознавать структурную информацию в группах

### 5.3. Контекстная фильтрация для чатов
- [ ] Создать `ChatContextAnalyzer Service`
- [ ] Анализ контекста чата для определения релевантности
- [ ] Умное отслеживание упоминаний пользователя
- [ ] Фильтрация личных сообщений и общих обсуждений
- [ ] Адаптация под приватные и публичные чаты

### 5.4. Универсальная система управления источниками
- [ ] Обновить UI для управления разными типами источников
- [ ] Разные настройки фильтрации для каналов, групп и чатов
- [ ] Единая статистика по всем типам источников
- [ ] Рекомендации на основе анализа всех источников
