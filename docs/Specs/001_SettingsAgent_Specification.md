# Спецификация 001: SettingsAgent

## Мета информация

- **Номер:** 001
- **Название:** Settingsagent
- **Автор:**
- **Создана:** 2025-11-02
- **Статус:** delivered
- **Связанные спецификации:**



## Общее описание
Агент для управления пользовательскими настройками Telegram бота.

## Основные функции

### 1. Отображение настроек
- **Вход**: пользователь Telegram
- **Выход**: форматированное сообщение с текущими настройками
- **Формат**: текст + inline клавиатура
- **Локализация**: поддержка русского языка

### 2. Изменение настроек
- **Поддерживаемые настройки**:
  - delivery_frequency: real_time, three_times_daily, twice_daily, once_daily, every_few_days, weekly, on_demand
  - content_format: original, summaries, unified_digest, combo, headlines
  - filter_strictness: ultra, high, medium, low, smart

### 3. Валидация
- Проверять название настройки
- Проверять допустимые значения
- Показывать понятные сообщения об ошибках

## Error handling
- Некорректная настройка → сообщение об ошибке
- Недопустимое значение → сообщение об ошибке
- Проблемы с БД → общее сообщение об ошибке
- Проблемы с Telegram API → логирование + общая ошибка

## Performance requirements
- Время ответа: < 500ms
- Кеширование текстов шаблонов на 1 час
- Логирование всех операций

## Integration points
- Telegram Bot API (отправка сообщений)
- ActiveRecord (работа с пользователем)
- I18n (локализация)
- Rails.logger (логирование)

---

# Контракты SettingsAgent

## Initialize
```ruby
SettingsAgent.new(bot: Telegram::Bot::Client, user: TelegramUser)
```

## Public методы
```ruby
# Показать настройки
# Return: void (отправляет сообщение через bot API)
show_settings()

# Обновить настройку
# Args: setting_name: String, value: String
# Return: void (отправляет результат через bot API)
update_setting(setting_name, value)
```

## Private методы (для внутренней логики)
```ruby
validate_setting(setting, value) -> { success: boolean, error: String }
build_settings_text() -> String
build_settings_keyboard() -> InlineKeyboardMarkup
```

---

# Acceptance Criteria

## Feature: Управление настройками бота

### Scenario: Пользователь просматривает текущие настройки
**Given** пользователь "test_user" с настройками по умолчанию
**When** он вызывает команду /settings
**Then** он видит сообщение с заголовком "Настройки"
**And** он видит текущие значения всех настроек
**And** он видит inline клавиатуру с кнопками настроек

### Scenario: Пользователь изменяет частоту доставки
**Given** пользователь "test_user" с частотой "once_daily"
**When** он нажимает кнопку "delivery_frequency"
**And** выбирает "real_time"
**Then** его настройка обновляется на "real_time"
**And** он получает сообщение об успешном обновлении

### Scenario: Пользователь пытается установить некорректное значение
**Given** пользователь "test_user"
**When** он пытается установить frequency в "invalid_value"
**Then** он получает сообщение об ошибке
**And** его настройки не изменяются

---

# Критерии успеха SettingsAgent

## Функциональные критерии
- [ ] Все настройки корректно отображаются
- [ ] Все настройки успешно обновляются
- [ ] Валидация работает для всех полей
- [ ] Сообщения об ошибках понятны пользователю
- [ ] Поддержка локализации работает

## Нефункциональные критерии
- [ ] Время ответа < 500ms
- [ ] 100% test coverage
- [ ] Нет memory leaks
- [ ] Корректная работа при высокой нагрузке
- [ ] Все ошибки логируются

## Интеграционные критерии
- [ ] Работает с Telegram Bot API
- [ ] Интегрируется с существующими контроллерами
- [ ] Не нарушает существующую логику
- [ ] Совместим с current_user системой

---

# Архитектура SettingsAgent

## Диаграмма зависимостей
```
TelegramWebhookController
           ↓
   SettingsAgent
    ↓         ↓
TelegramUser  Telegram::Bot::Client
    ↓         ↓
Database    Telegram API
```

## Поток данных
1. Контроллер получает команду от пользователя
2. Создает экземпляр SettingsAgent
3. Вызывает публичный метод агента
4. Агент валидирует данные, работает с БД
5. Агент формирует ответ и отправляет через Telegram API
6. Агент логирует операцию

---

# Техническая спецификация SettingsAgent

## Зависимости
- telegram-bot gem
- Rails (ActiveRecord, I18n, Logger)
- Telegram::KeyboardHelpers

## Структура классов
```ruby
class SettingsAgent
  # Constants
  VALID_SETTINGS = [...]
  VALID_VALUES = {...}

  # Initialize
  def initialize(bot, user)

  # Public interface
  def show_settings
  def update_setting(setting, value)

  # Private helpers
  def validate_setting
  def build_text
  def build_keyboard
  def send_message
  def log_action
end
```

## Конфигурация
- Тексты локализации в config/locales/ru.yml
- Кеширование через Rails.cache
- Логирование через Rails.logger

## Error handling strategy
- Rescue StandardError → общее сообщение об ошибке
- Rescue ActiveRecord::RecordInvalid → валидационная ошибка
- Rescue Telegram::Bot::Error → проблема с API

---

# Тест-план SettingsAgent

## Unit тесты
- [ ] initialize корректно сохраняет зависимости
- [ ] show_settings формирует правильное сообщение
- [ ] update_setting обновляет валидные настройки
- [ ] update_setting отвергает невалидные настройки
- [ ] keyboard генерируется корректно
- [ ] локализация работает для всех текстов

## Integration тесты
- [ ] Интеграция с Telegram::Bot::Client
- [ ] Интеграция с ActiveRecord model
- [ ] Интеграция с I18n
- [ ] Интеграция с Rails.logger

## End-to-end тесты
- [ ] Полный сценарий просмотра настроек
- [ ] Полный сценарий изменения настройки
- [ ] Полный сценарий обработки ошибки

## Performance тесты
- [ ] Load testing: 100 запросов/секунду
- [ ] Memory usage testing
- [ ] Response time testing

---

# Связанные документы
- [TDD для Telegram агентов](../Implementation/tdd-for-telegram-agents.md)
- [Документация telegram-bot gem](../gems/telegram-bot.md)

---

## Статус: implemented

**Примечание**: SettingsAgent полностью реализован в проекте:
- ✅ Все основные функции работают в production
- ✅ Команда `/settings` доступна пользователям
- ✅ Валидация настроек реализована
- ✅ Локализация работает
- ✅ Интеграция с TelegramWebhookController выполнена

**План реализации**: [Spec_001_SettingsAgent_Implementation.md](../Implementation/Spec_001_SettingsAgent_Implementation.md)