# Реализация: Управление командами Telegram бота

## Обзор

Документ описывает реализацию системы автоматического определения и установки команд Telegram бота через API. Система позволяет автоматически сканировать исходный код, определять доступные команды и устанавливать их в интерфейсе Telegram.

## Архитектура

### Основные компоненты

1. **`Telegram::CommandsScanner`** (`app/services/telegram/commands_scanner.rb`)
   - Сканирует контроллеры и concerns для определения команд
   - Извлекает метаданные команд (имя, описание, источник)
   - Разделяет пользовательские и административные команды

2. **`Telegram::CommandsManager`** (`app/services/telegram/commands_manager.rb`)
   - Управляет установкой команд через Telegram API
   - Валидирует формат команд
   - Обрабатывает ошибки и логирует операции

3. **Rake задачи** (`lib/tasks/telegram.rake`)
   - Консольные утилиты для управления командами
   - Поддержка dry-run и валидации
   - Интеграция с процессом развертывания

4. **Административная команда** (`app/controllers/telegram_webhook_controller.rb`)
   - Команда `/set_commands` для управления из чата
   - Callback `show_commands` для просмотра команд
   - Защита от несанкционированного доступа

## Детали реализации

### CommandsScanner

**Основные методы:**

```ruby
# Сканирование команд (без админских по умолчанию)
scanner.scan_commands(exclude_admin: true)

# Все команды включая админские
scanner.all_commands

# Только пользовательские команды
scanner.user_commands

# Только административные команды
scanner.admin_commands
```

**Логика сканирования:**

1. Анализирует `TelegramWebhookController`
2. Сканирует все включенные `concerns`
3. Ищет методы, заканчивающиеся на `!`
4. Исключает приватные методы (начинающиеся с `_`)
5. Определяет административные команды по списку

**Идентификация административных команд:**

```ruby
def admin_command?(command_name)
  %w[debug channels set_commands].include?(command_name.to_s)
end
```

### CommandsManager

**Основные функции:**

```ruby
# Установка команд
manager.set_commands!
# => { success: true, message: 'Команды установлены', commands_count: 5 }

# Проверка актуальности
manager.commands_outdated?
# => true/false

# Синхронизация при необходимости
manager.sync_commands_if_needed

# Форматирование для вывода
manager.format_user_commands_for_display
```

**Валидация команд:**

- Имя команды: только латиница, цифры, подчеркивания (1-32 символа)
- Описание: 1-256 символов
- Максимум 100 команд на бота

### Rake задачи

**Основные задачи:**

```bash
# Установка команд
rake telegram:set_commands

# Показать текущие команды
rake telegram:show_commands

# Показать все команды включая админские
rake telegram:show_all_commands

# Синхронизировать при необходимости
rake telegram:sync_commands

# Валидация формата
rake telegram:validate_commands

# Первоначальная настройка
rake telegram:setup
```

**Опции окружения:**

```bash
# Dry run (только проверка)
rake telegram:set_commands DRY_RUN=true

# Указание webhook URL
rake telegram:set_webhook WEBHOOK_URL=https://example.com/webhook
```

### Административная команда

**Команда `/set_commands`:**

- Доступна только администраторам
- Показывает прогресс установки
- Отображает клавиатуру для управления
- Логирует ошибки в Bugsnag

**Callback команды:**

- `show_commands:` - показывает список всех команд
- `set_commands:` - переустанавливает команды

## Локализация

### Файл локализации (`config/locales/ru.yml`)

```yaml
ru:
  telegram_bot:
    commands:
      start: "Начать работу с ботом"
      help: "Показать справку"
      settings: "Настройки бота"
      add: "Добавить канал (@username)"
      remove: "Удалить канал (@username)"
      list: "Показать мои подписки"
      debug: "Режим отладки (админам)"
      channels: "Список всех каналов (админам)"
      set_commands: "Установить команды бота (админам)"

    bot_commands:
      set_success: "✅ Команды бота успешно установлены!"
      set_error: "❌ Ошибка при установке команд: %{error}"
      no_commands_found: "📭 Команды не найдены"
      commands_list: "📋 Список команд бота:"
      commands_total: "Всего команд: %{count}"
```

## Обработка ошибок

### Уровни обработки ошибок

1. **Валидация команд** - проверка формата перед отправкой
2. **API ошибки** - обработка ошибок Telegram API
3. **Исключения** - отлов непредвиденных ошибок
4. **Логирование** - запись ошибок в Rails logger и Bugsnag

### Пример обработки ошибок

```ruby
def set_commands!
  commands = prepare_commands

  if commands.empty?
    add_error(:no_commands, I18n.t('telegram_bot.bot_commands.no_commands_found'))
    return failure_result(I18n.t('telegram_bot.bot_commands.no_commands_found'))
  end

  response = bot.set_my_commands(commands: commands)

  if response['ok']
    success_result(I18n.t('telegram_bot.bot_commands.set_success'))
  else
    error_message = response['description'] || 'Unknown API error'
    add_error(:api_error, error_message)
    failure_result(I18n.t('telegram_bot.bot_commands.set_error', error: error_message))
  end
rescue => e
  Bugsnag.notify(e) { |b| b.metadata = { service: 'CommandsManager', action: 'set_commands!' } }
  failure_result(I18n.t('telegram_bot.bot_commands.set_error', error: e.message))
end
```

## Тестирование

### Unit тесты

**CommandsScanner тесты:**
- Определение командных методов
- Сканирование контроллеров и concerns
- Фильтрация административных команд
- Генерация описаний по умолчанию

**CommandsManager тесты:**
- Установка команд через API
- Валидация формата команд
- Обработка ошибок API
- Форматирование для вывода

### Integration тесты

**Контроллер тесты:**
- Административная команда `/set_commands`
- Callback `show_commands`
- Проверка прав доступа
- Обработка ошибок

**Rake задачи тесты:**
- Выполнение задач из командной строки
- Обработка переменных окружения
- Dry run режим

## Безопасность

### Ограничения доступа

1. **Административные команды** - только для пользователей с `is_admin: true`
2. **API токен** - хранится в ApplicationConfig
3. **Валидация** - проверка формата команд перед установкой
4. **Логирование** - фиксация всех операций с командами

### Метаданные для Bugsnag

```ruby
Bugsnag.notify(e) do |b|
  b.metadata = {
    service: 'CommandsManager',
    action: 'set_commands!',
    user_id: current_user&.id,
    command_count: commands.count
  }
end
```

## Производительность

### Оптимизации

1. **Кеширование** - результаты сканирования можно кешировать
2. **Ленивая загрузка** - сканирование только при необходимости
3. **Валидация** - проверка перед API вызовами
4. **Batch операции** - установка всех команд одним запросом

### Мониторинг

- Логирование времени выполнения операций
- Счетчик успешных/неуспешных установок
- Метрики в Bugsnag для ошибок

## Развертывание

### Process deployment

1. **Установка зависимостей**
   ```bash
   bundle install
   ```

2. **Настройка переменных окружения**
   ```bash
   export BOT_TOKEN="your_bot_token"
   export WEBHOOK_URL="https://your-domain.com/webhook"
   ```

3. **Установка команд**
   ```bash
   rake telegram:set_commands
   ```

4. **Настройка webhook (опционально)**
   ```bash
   rake telegram:set_webhook
   ```

### CI/CD интеграция

```yaml
# .github/workflows/telegram.yml
- name: Setup Telegram Commands
  run: |
    bundle exec rake telegram:validate_commands
    bundle exec rake telegram:set_commands
```

## Использование

### Для разработчиков

```bash
# Показать текущие команды
rake telegram:show_commands

# Проверить валидность
rake telegram:validate_commands

# Обновить при необходимости
rake telegram:sync_commands

# Dry run для проверки
rake telegram:set_commands DRY_RUN=true
```

### Для администраторов

В Telegram чате:
```
/set_commands - установить команды
```

После установки:
- Нажать "📋 Показать команды" для просмотра
- Нажать "🔄 Обновить команды" для переустановки

## Будущие улучшения

### Планируемые функции

1. **Автоматическое обновление** - отслеживание изменений в коде
2. **Многоязычность** - поддержка описаний на разных языках
3. **Аналитика** - статистика использования команд
4. **Версионирование** - отслеживание изменений в командах

### Технические улучшения

1. **Кеширование** - Redis для хранения результатов сканирования
2. **Background jobs** - асинхронная установка команд
3. **Webhooks** - автоматическое обновление при деплое
4. **API endpoints** - REST API для управления командами

## Заключение

Реализованная система обеспечивает:

- ✅ Автоматическое определение команд из исходного кода
- ✅ Безопасную установку через Telegram API
- ✅ Разделение пользовательских и административных команд
- ✅ Гибкое управление через Rake задачи и команды бота
- ✅ Comprehensive тестирование
- ✅ Обработку ошибок и логирование
- ✅ Локализацию описаний команд

Система готова к использованию в production и легко расширяется для будущих требований.