# NoFluff Telegram Bot Project Overview

## Project Purpose
Телеграм бот "Без шелухи" (@bez_sheluhi_bot) - это Ruby on Rails приложение, которое:
- Принимает от пользователя наборы телеграм каналов для мониторинга
- Отслеживает активность в этих каналах  
- Выдает пользователю только важную информацию без рекламы и "шелухи"
- Создает социальную сеть для продвижения интересных каналов на схожую тематику

## Tech Stack
- **Framework**: Ruby on Rails 8.0.3
- **Database**: PostgreSQL 
- **Background Jobs**: Solid Queue (multiple queue types)
- **Telegram Integration**: telegram-bot gem (0.16.7) для Bot API
- **AI/LLM**: ruby_llm gem (1.8) с поддержкой OpenAI и DeepSeek
- **State Management**: state_machines-activerecord (0.6)
- **Error Tracking**: Bugsnag (6.28)
- **Template Engine**: Slim templates
- **Asset Pipeline**: Sprockets Rails

## Key Models (Current Architecture)
- **Channel**: Основная модель для телеграм каналов с state machine для bot join статуса
- **TelegramUser**: Пользователи бота
- **Subscription**: Связь между пользователями и каналами
- **Post**: Посты из каналов
- **Message**: Сообщения
- **Chat**: Чаты
- **UserDigest**: Дайджесты для пользователей

## Current Channel Model Features
- State machine для bot_join_status (not_joined, joining, joined, join_failed)
- Scopes для разных статусов и фильтрации
- Методы для управления процессом вступления бота в канал
- Поддержка активных/неактивных каналов
- Ведение статистики (subscribers_count, last_post_at)

## Background Jobs Architecture
Множественные типы очередей с разным concurrency:
- **realtime**: 2 процесса (срочные задачи)
- **digest/default**: 3 процесса (дайджесты)
- **content/channels**: 2 процесса (обработка контента)
- **ai/low_priority**: 1 процесс (AI задачи и фоновые процессы)

## Code Style & Conventions
- Ruby/Rails Omakase стайлинг (rubocop-rails-omakase)
- Minitest для тестирования (5.25+)
- State machines для управления статусами
- Service layer паттерн для бизнес-логики
- Solid Queue для фоновых задач
- Environment variables с префиксом NO_FLUFF_
- Russian language in documentation and comments

## Development Commands
- `./bin/rails generate model` - создание моделей
- `./bin/rails db:migrate` - миграции базы
- `rubocop -A` - линтинг и авто-фикс
- `./bin/rails test` - запуск тестов
- `./bin/rails server` - запуск сервера разработки

## Configuration Features
- Anyway Config (2.7) для управления конфигурацией
- Поддержка multiple AI провайдеров (OpenAI, DeepSeek)
- Telegram Bot интеграция через Bot API
- Solid Queue Dashboard для мониторинга фоновых задач
- Kamal для деплоя контейнерами

## Important Architecture Notes
- Использует Bot API (не MTProto) для взаимодействия с Telegram
- Channel модель уже имеет state machine для bot join процесса
- Система уже поддерживает мониторинг активности каналов
- Фоновая обработка распределена по типам задач с разным приоритетом