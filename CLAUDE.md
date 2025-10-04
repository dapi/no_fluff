Документация по проекту лежит в ./docs

Клади туда все генерируемые докуенты если я прошу их сохранить. В именовании
между словами используй минус.

При добавлении текстов в ответ бота сохраняй их в `./config/locales` и используй
от туда через `I18n.t`

Мы не используем переменные окружения напрямую (ENV), доставай значения через ApplicationConfig

Перед тем как отвечать на вопросы касающиеся продукта изучи ./docs/Product

## Структура документации

- ./docs/Product - документация по продукту
  - target-audience.md - целевая аудитория
  - bot-descriptions.md - описания ботов
  - problems.md - проблемы которые решает продукт
  - telegram-descriptions.md - описания для Telegram
  - core-settings.md - основные настройки
  - features.md - функциональность
  - user-flow.md - пользовательский поток
- ./docs/Architecture - архитектурная документация
  - c4-model.md - C4 модель архитектуры
- ./docs/gems - документация по используемым gem-ам
  - telegram-bot.md - Telegram bot
  - ruby-llm.md - Ruby LLM
- ./docs/Other - прочая документация
- ./docs/Hidden - скрытая документация
- ./docs/ROADMAP.md - дорожная карта проекта

Модели и новые таблицы создаем через `rails g model` а не через прямое создание
миграций.

При планировании проекта с нуля сначала заводим модели и все необходимые
свойства схемы делаем через `rails g model`

Рельсовые команды запускай через `./bin/rails`

В миграциях в базе вместо `json` всегда используй `jsonb`

При создании индексов в базе учти что индексы для references колонок уже
создаются автоматически.

После выполнения пункта из ROADMAP отмечай его выполненным.

Перед тем как что-то делать или планировать делать с кодом изучай файлы в ./docs/Architecture

При создании тестов изучай ./docs/Testing

Если делаешь обещания - записывай их в .claude/promises.md

/file:.claude-on-rails/context.md
/file:.claude/promises.md
- Когда работаешь с фоновыми задачами учитывай config/queue.yml


# Инстуркции для claude

Always use context7 when I need code generation, setup or configuration steps, or
library/API documentation. This means you should automatically use the Context7 MCP
tools to resolve library id and get library docs without me having to explicitly ask.
