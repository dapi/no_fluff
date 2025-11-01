# NoFluff Bot - Документация проекта

## 📁 Структура документации

### 📋 Спецификации и имплементации
- **[Specs/](./Specs/)** - Спецификации функционала
  - Формат: `XXX_Name_Specification.md`
  - Статусы: `draft` → `need_plan` → `approved` → `implemented`
- **[Implementation/](./Implementation/)** - Планы имплементации
  - Формат: `Spec_XXX_Name_Implementation.md`
  - TDD подход с чекбоксами прогресса

### 🏗️ Архитектура и продукт
- **[Product/](./Product/)** - Документация по продукту
  - Целевая аудитория, проблемы, фичи
- **[Architecture/](./Architecture/)** - Архитектурная документация
  - [C4 Model v1.0 (Bot-based)](./Architecture/c4-model.md) - устаревшая версия
  - [C4 Model v2.0 (User-based)](./Architecture/c4-model-updated.md) 🚨 **Новая архитектура**
  - [Migration Plan v1→v2](./Architecture/user-based-access-migration.md) 🚨 **План миграции**
  - Telegram сессии, обработка ошибок

### 📚 Техническая документация
- **[gems/](./gems/)** - Документация по gem-ам
  - Telegram Bot, Ruby LLM
- **[Testing/](./Testing/)** - Тестирование
  - Minitest, LLM мокинг, Telegram боты
- **[Development/](./Development/)** - Инструменты разработки

### 🔧 Дополнительные материалы
- **[Other/](./Other/)** - Прочая документация
- **[Telegram/](./Telegram/)** - Telegram специфичная документация
- **[Hidden/](./Hidden/)** - Скрытая документация

## 🔄 Работа со спецификациями

**Что такое спецификация?** 👉 [Что такое спецификация в проекте](./What_Is_Specification.md)

**Регламент работы**: 👉 [Регламент работы со спецификациями](./Specification_Workflow_Guide.md)

### Статусы спецификаций
- 🟡 **draft** - Черновик, требует доработки
- 🟠 **need_plan** - Спецификация готова, нужен план имплементации
- 🟢 **approved** - Одобрена к реализации
- 🔵 **implemented** - Реализована

### Процесс работы
1. **Создание** → `draft`
2. **Доработка** → `need_plan`
3. **План имплементации** → `approved`
4. **Реализация** → `implemented`

## 📋 Текущий статус проекта

### ✅ Реализованные спецификации
- [001] SettingsAgent (71% выполнено)
- [003] Subscription Free Channels (реализовано)
- [045] Telegram Bot Commands (реализовано)
- [048] Channels Command (реализовано)
- [051] FETCHPOSTJOB_TIMESTAMP (реализовано)

### 🔄 В работе
- [046] Bot Channel Join Process
- [049] Debug Command (код готов, нужно обновить план)
- [050] Deploy Notification (код готов, нужно обновить план)

### ⏳ Ожидает реализации
- [006] Telegram Message Processing (требует план)
- [002] Subscription Sharing Platform
- [004] Subscription Sharing Social
- [040] Bot Removal From Channel Status

## 🎯 Быстрый доступ

### Для разработки
- [ROADMAP](./ROADMAP.md) - Дорожная карта проекта
- [C4 Model](./Architecture/c4-model.md) - Архитектура
- [Telegram Bot Gem](./gems/telegram-bot.md) - Основной gem
- [TDD Guide](./Implementation/tdd-for-telegram-agents.md) - TDD подход

### Для продукта
- [Проблемы пользователей](./Product/problems.md) - Боли которые решаем
- [Целевая аудитория](./Product/target-audience.md) - Для кого делаем
- [Фичи](./Product/features.md) - Функционал

---

**📝 При работе со спецификациями всегда следуй [регламенту](./Specification_Workflow_Guide.md)!**