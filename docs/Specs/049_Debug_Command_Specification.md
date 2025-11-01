# Спецификация 049: Debug Command

## Мета информация

- **Номер:** 049
- **Название:** Debug Command
- **Автор:**
- **Создана:** 2025-11-02
- **Статус:** delivered
- **Связанные спецификации:**



# Спецификация команды /debug

## Обзор

Команда `/debug` позволяет разработчику включать и выключать режим отладки, в котором бот отправляет в Telegram уведомления о внутренней работе системы, таких как ошибки обновления каналов и другие системные события.

## Цель

Предоставить разработчику инструмент для мониторинга внутренней работы системы в реальном времени через Telegram интерфейс.

## Пользовательская история

**Как** разработчик
**Я хочу** периодически включать систему в режим дебага
**Чтобы** получать в телеграмме от бота сообщения о внутренней работе системы

## Функциональные требования

### 1. Команда /debug

- **Команда**: `/debug`
- **Доступ**: Только для администраторов (проверка по `is_admin: true` в `telegram_users`)
- **Функционал**: Переключение режима отладки (вкл/выкл)
- **Ответ**: Текущее состояние режима отладки

### 2. Таблица системных настроек

**Название таблицы**: `system_settings`

**Поля**:
- `id` (primary key)
- `key` (string, unique) - ключ настройки
- `value` (jsonb) - значение настройки
- `description` (text) - описание настройки
- `created_at` (datetime)
- `updated_at` (datetime)

**Настройки**:
- `debug_mode` (boolean) - режим отладки

### 3. Дебаг-сообщения

**Типы сообщений**:
- Ошибки обновления каналов
- Ошибки обработки сообщений
- Системные предупреждения
- Успешные операции (опционально)

**Формат сообщений**:
```
🔍 DEBUG ALERT
Тип: [тип ошибки/события]
Время: [timestamp]
Контекст: [дополнительная информация]
```

## Нефункциональные требования

### Безопасность
- Команда доступна только для администраторов
- Проверка по полю `is_admin: true` в модели `TelegramUser`

### Производительность
- Отправка дебаг-сообщений не должна блокировать основную логику
- Использование фоновых задач для отправки

### Надежность
- Логирование всех попыток включения режима отладки
- Обработка ошибок при отправке дебаг-сообщений

## Технические требования

### 1. Модель SystemSetting

```ruby
class SystemSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  scope :by_key, ->(key) { where(key: key) }

  def self.get(key, default = nil)
    setting = find_by(key: key)
    setting ? setting.value : default
  end

  def self.set(key, value, description = nil)
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.description = description if description.present?
    setting.save!
    setting
  end
end
```

### 2. Сервис для отправки дебаг-сообщений

```ruby
class DebugNotifier
  def self.enabled?
    SystemSetting.get('debug_mode', false)
  end

  def self.notify(message_type, context = {})
    return unless enabled?

    # Получаем всех администраторов
    admin_users = TelegramUser.where(is_admin: true)
    return if admin_users.empty?

    # Отправка через фоновую задачу всем администраторам
  end
end
```

### 3. Обработчик команды /debug

```ruby
class DebugCommand < BaseCommand
  def call
    # Проверка прав разработчика
    # Переключение режима
    # Отправка ответа
  end
end
```

## Интеграция с существующей системой

### 1. Telegram Bot
- Добавление новой команды в `telegram_bot_handlers`
- Интеграция с существующей системой команд

### 2. Background Jobs
- Использование `SolidQueue` для отправки дебаг-сообщений
- Настройка в `config/queue.yml`

### 3. Error Handling
- Интеграция с `Bugsnag` для логирования
- Дополнительный контекст в метаданных

## Тестирование

### Unit тесты
- Тест модели `SystemSetting`
- Тест сервиса `DebugNotifier`
- Тест обработчика команды `DebugCommand`

### Integration тесты
- Тест переключения режима отладки
- Тест отправки дебаг-сообщений
- Тест прав доступа

## Локализация

**Файл**: `config/locales/ru.yml`

```yaml
telegram:
  commands:
    debug:
      enabled: "🔍 Режим отладки включен"
      disabled: "🔴 Режим отладки выключен"
      access_denied: "❌ Доступ запрещен"
      status: "Текущий статус: %{status}"
```

## Временные рамки

Оценка: 4-6 часов
- Создание миграции и модели: 1 час
- Реализация сервиса уведомлений: 1 час
- Реализация команды: 1 час
- Написание тестов: 1.5-2 часа
- Интеграция и отладка: 0.5-1 час

---

## Статус: implemented

**Примечание**: Команда `/debug` полностью реализована:
- ✅ Модель SystemSetting создана и работает
- ✅ DebugNotifierService отправляет уведомления
- ✅ DebugNotificationJob обрабатывает очередь
- ✅ Команда `/debug` доступна администраторам
- ✅ Все компоненты интегрированы и работают в production

**План реализации**: [Spec_Debug_Command_Implementation.md](../Implementation/Spec_Debug_Command_Implementation.md)