# 🔄 План рефакторинга тестовой структуры ./test

**Дата создания:** 2025-01-02
**Статус:** Запланировано
**Версия:** v1.0

## 🎯 Общая стратегия

Проводим рефакторинг по принципу **RED-GREEN-REFACTOR**:
1. Создаем новую структуру parallel со старой
2. Переносим тесты постепенно
3. Удаляем старую структуру
4. Оптимизируем новую

---

## 🗓️ План по дням (12 дней)

### День 1: Базовая конфигурация и foundation

#### Задачи:
- [x] **1.1** Обновить `test/test_helper.rb`
  - Перенести Telegram bot конфигурацию из инициализации
  - Добавить DatabaseCleaner конфигурацию
  - Улучшить изоляцию транзакций
- [x] **1.2** Создать `test/support/` директорию
- [x] **1.3** Создать `test/support/telegram_helper.rb`
  - Базовые helper методы для Telegram
  - Стандартизация создания update
  - Унификация извлечения сообщений
- [x] **1.4** Создать `test/support/mocks_helper.rb`
  - Стандартизация мокирования LimitChecker
  - Мокирование Telegram API
  - Мокирование ApplicationConfig

**Результат**: ✅ Готовая основа для рефакторинга - ВЫПОЛНЕНО

---

### День 2: Создание Factory Helpers и расширенные фикстуры

#### Задачи:
- [x] **2.1** Создать `test/support/factory_helper.rb`
  - Factory для пользователей с разными ролями
  - Factory для каналов с разными статусами
  - Factory для сложных сценариев
- [x] **2.2** Расширить фикстуры в `test/fixtures/`
  - Добавить `premium_user`, `admin_user` фикстуры
  - Создать `test/fixtures/channels.yml` с разными типами каналов
  - Добавить `test/fixtures/subscriptions.yml` для тестовых подписок
- [x] **2.3** Создать `test/support/assertion_helper.rb`
  - Дополнительные assertions для Telegram
  - Custom matchers для бизнес-логики

**Результат**: ✅ Удобные инструменты создания тестовых данных - ВЫПОЛНЕНО

---

### День 3: Реорганизация моделей тестов

#### Задачи:
- [x] **3.1** Создать `test/models/telegram_user/base_test.rb`
  - Перенести базовые валидации и ассоциации
  - Оставить в основном файле только основное
- [x] **3.2** Создать `test/models/telegram_user/session_test.rb`
  - Перенести все тесты сессий
  - Использовать новые factory helpers
- [x] **3.3** Создать `test/models/telegram_user/limits_test.rb`
  - Перенести тесты лимитов подписок
  - Оптимизировать с помощью factory
- [x] **3.4** Создать `test/models/telegram_user/admin_test.rb`
  - Перенести admin функциональность
- [x] **3.5** Обновить основной `telegram_user_test.rb`
  - Оставить только базовые тесты
  - Подключить support модули

**Результат**: ✅ Структурированные и читаемые тесты моделей - ВЫПОЛНЕНО

---

### День 4: Рефакторинг сервисных тестов

#### Задачи:
- [ ] **4.1** Обновить `test/services/telegram/channel_service_test.rb`
  - Использовать TelegramHelper
  - Заменить моки на MocksHelper
  - Разбить на логические секции
- [ ] **4.2** Создать `test/services/telegram/shared_examples.rb`
  - Общие паттерны тестирования сервисов
  - Reusable тестовые сценарии
- [ ] **4.3** Оптимизировать тесты `limits/`
  - Использовать FactoryHelper для создания данных
  - Стандартизировать подход к мокам

**Результат**: 🔄 Унифицированные сервисные тесты - В ПРОЦЕССЕ

---

### День 5: Контроллеры - базовая структура

#### Задачи:
- [ ] **5.1** Переименовать `telegram_webhook_controller_test.rb` → `webhook_controller_test.rb`
  - Исправить имя класса на `Telegram::WebhookControllerTest`
- [ ] **5.2** Создать `test/controllers/telegram/webhook_controller/base_test.rb`
  - Вынести базовые webhook тесты
  - Helper методы в support модуль
- [ ] **5.3** Извлечь helper методы в `TelegramHelper`
  - `create_user_update`, `create_callback_update`
  - `send_webhook_update`, `extract_message_content`

**Результат**: Переименованные и базово-реорганизованные контроллер тесты

---

### День 6: Контроллеры - разделение на модули

#### Задачи:
- [ ] **6.1** Создать `test/controllers/telegram/webhook_controller/commands_test.rb`
  - Тесты команд (/start, /help, /add, /remove)
- [ ] **6.2** Создать `test/controllers/telegram/webhook_controller/callbacks_test.rb`
  - Тесты callback query обработки
- [ ] **6.3** Создать `test/controllers/telegram/webhook_controller/admin_session_test.rb`
  - Тесты admin сессий (/remember, /recall, /forget)
- [ ] **6.4** Создать `test/controllers/telegram/webhook_controller/integration_test.rb`
  - Полные workflow тесты
- [ ] **6.5** Обновить основной `webhook_controller_test.rb`
  - Оставить только базовые тесты
  - Подключить все support модули

**Результат**: Модульные и управляемые контроллер тесты

---

### День 7: Jobs тесты оптимизация

#### Задачи:
- [ ] **7.1** Создать `test/jobs/shared_job_examples.rb`
  - Общие паттерны для тестирования jobs
  - Стандартизация assertions
- [ ] **7.2** Обновить `test/jobs/channels/bot_join_job_test.rb`
  - Использовать MocksHelper
  - Добавить factory для каналов
- [ ] **7.3** Оптимизировать остальные job тесты
  - `debug_notification_job_test.rb`
  - `deploy_notification_job_test.rb`

**Результат**: Унифицированные job тесты

---

### День 8: Интеграционные тесты реорганизация

#### Задачи:
- [ ] **8.1** Создать `test/integration/workflows/` директорию
- [ ] **8.2** Разделить `bot_channel_join_integration_test.rb`:
  - `user_onboarding_test.rb`
  - `channel_management_test.rb`
  - `subscription_workflows_test.rb`
- [ ] **8.3** Создать `test/integration/integration_test_case.rb`
  - Базовый класс для интеграционных тестов
  - Общие helper методы

**Результат**: Структурированные интеграционные тесты

---

### День 9: Оптимизация и удаление дублирования

#### Задачи:
- [ ] **9.1** Провести аудит всех тестов на дублирование
- [ ] **9.2** Создать `test/support/scenario_helper.rb`
  - Сложные сценарии для переиспользования
- [ ] **9.3** Оптимизировать фикстуры
  - Удалить неиспользуемые
  - Добавить недостающие
- [ ] **9.4** Обновить все тесты для использования统一的helpers

**Результат**: Устранение дублирования кода

---

### День 10: Производительность и параллелизация

#### Задачи:
- [ ] **10.1** Настроить parallel execution где возможно
- [ ] **10.2** Оптимизировать моки
  - Предзагрузка общих моков
  - Кэширование дорогих операций
- [ ] **10.3** Профилировать медленные тесты
- [ ] **10.4** Оптимизировать транзакции

**Результат**: Ускоренные тесты на 20-30%

---

### День 11: Финальная очистка и документация

#### Задачи:
- [ ] **11.1** Удалить старые файлы и методы
- [ ] **11.2** Обновить `docs/Testing/testing-recommendations.md`
  - Добавить информацию о новой структуре
  - Документировать support модули
- [ ] **11.3** Создать `test/README.md`
  - Описание структуры тестов
  - Инструкции по добавлению новых тестов
- [ ] **11.4** Проверить все тесты на работу

**Результат**: Чистая и документированная тестовая структура

---

### День 12: Валидация и ревью

#### Задачи:
- [ ] **12.1** Запустить все тесты и убедиться что они проходят
- [ ] **12.2** Проверить покрытие кода
- [ ] **12.3** Получить code review от команды
- [ ] **12.4** Внести финальные правки

**Результат**: Готовая к использованию новая тестовая структура

---

## 📁 Новая структура файлов после рефакторинга

```
test/
├── support/
│   ├── telegram_helper.rb          # Telegram-specific helpers
│   ├── mocks_helper.rb             # Standardized mocking
│   ├── factory_helper.rb           # Factories for complex objects
│   ├── assertion_helper.rb         # Custom assertions
│   └── scenario_helper.rb          # Complex scenarios
├── models/
│   ├── telegram_user_test.rb       # Base tests only
│   └── telegram_user/
│       ├── session_test.rb         # Session functionality
│       ├── limits_test.rb          # Subscription limits
│       └── admin_test.rb           # Admin functionality
├── controllers/telegram/
│   ├── webhook_controller_test.rb  # Base controller tests
│   └── webhook_controller/
│       ├── commands_test.rb        # Command handling
│       ├── callbacks_test.rb       # Callback queries
│       ├── admin_session_test.rb   # Admin sessions
│       └── integration_test.rb     # Full workflows
├── services/
│   └── shared_examples.rb          # Common service patterns
├── jobs/
│   └── shared_job_examples.rb      # Common job patterns
├── integration/
│   ├── integration_test_case.rb     # Base for integration tests
│   └── workflows/
│       ├── user_onboarding_test.rb
│       ├── channel_management_test.rb
│       └── subscription_workflows_test.rb
└── README.md                       # Testing guide
```

## 🔧 Ключевые принципы рефакторинга

1. **Постепенное изменение** - не ломаем работающие тесты
2. **RED-GREEN-REFACTOR** - сначала работающий код, потом оптимизация
3. **TDD подход** - каждый новый компонент тестируется сразу
4. **Параллельная разработка** - старые тесты работают до финального переноса

## 📊 Ожидаемые метрики после рефакторинга

- **Количество файлов**: 37 → 45+ (но более структурированных)
- **Размер файлов**: средний размер уменьшится на 40%
- **Дублирование**: снизится на 50%
- **Скорость выполнения**: улучшится на 20-30%
- **Покрытие**: сохранится или улучшится

## 🎯 Цели рефакторинга

### Качество
- ✅ Улучшение читаемости и поддерживаемости тестов
- ✅ Снижение дублирования кода на 40-50%
- ✅ Унификация подходов к тестированию
- ✅ Упрощение отладки тестов

### Производительность
- ⚡ Ускорение выполнения тестов на 20-30%
- ⚡ Уменьшение потребления памяти
- ⚡ Возможность параллельного выполнения

### Поддерживаемость
- 🛠️ Легкое добавление новых тестов
- 🛠️ Понятная структура для новых разработчиков
- 🛠️ Упрощенное рефакторинг тестов

---

## 📋 Проблемы текущей структуры

### 1. **Отсутствие Telegram Bot конфигурации**
- В `test_helper.rb` нет настроек для `telegram-bot` gem
- Отсутствует `Telegram.reset_bots` и `Telegram::Bot::ClientStub.stub_all!`

### 2. **Несоответствие именования**
- Файл `telegram_webhook_controller_test.rb` содержит класс `TelegramWebhookControllerImprovedTest`
- Несоответствие имени файла и класса теста

### 3. **Избыточность и дублирование**
- Огромные helper методы в контроллер тестах (70+ строк)
- Повторяющиеся паттерны создания тестовых данных
- Дублирование логики мокирования в разных тестах

### 4. **Проблемы с организацией**
- Тесты разбросаны по множеству поддиректорий
- Некоторые тесты логически не соответствуют своей директории
- Отсутствует единая стратегия именования тестов

### 5. **Сложность поддержки**
- Очень длинные тестовые классы (600+ строк)
- Сложные интеграционные тесты с множественными зависимостями
- Трудность отладки из-за обилия моков

---

**Статус выполнения:** 🔄 В процессе (Дни 1-3 выполнены, День 4 в процессе)
**Дата начала:** 2025-01-02
**Ответственный:** Claude Code Assistant
**Обновлено:** 2025-01-02

---

## 📊 Прогресс выполнения

### ✅ Выполнено (Дни 1-3)
- **День 1**: Базовая конфигурация и foundation - 100% ✅
- **День 2**: Factory Helpers и расширенные фикстуры - 100% ✅
- **День 3**: Реорганизация моделей тестов - 100% ✅

### 🔄 В процессе (День 4)
- **День 4**: Рефакторинг сервисных тестов - 0%

### ⏳ Запланировано (Дни 5-12)
- **Дни 5-12**: Контроллеры, Jobs, Интеграционные тесты, Оптимизация - 0%

---

## 📈 Общий прогресс: 25% выполнено (3 из 12 дней)

### ✅ Завершенные этапы:
- ✅ **Foundation** - Полная инфраструктура для тестирования
- ✅ **Support Tools** - Все хелперы и фикстуры готовы
- ✅ **Model Tests** - Полностью реорганизованы и структурированы

### 🎯 Достигнутые результаты:
- **Код организации**: Улучшена структура и читаемость тестов
- **Переиспользование**: Созданы универсальные хелперы и фикстуры
- **Разделение ответственности**: Тесты разделены по функциональным областям
- **Качество**: Все тесты проходят (48 runs, 122 assertions, 0 failures)

---

## 🎯 Текущие результаты

### Созданные файлы:
- `test/support/telegram_helper.rb` - Telegram-specific helpers
- `test/support/mocks_helper.rb` - Standardized mocking
- `test/support/factory_helper.rb` - Factories for complex objects
- `test/support/assertion_helper.rb` - Custom assertions
- `test/models/telegram_user/base_test.rb` - Base tests for TelegramUser
- `test/models/telegram_user/session_test.rb` - Session functionality tests
- `test/models/telegram_user/limits_test.rb` - Subscription limits tests
- `test/models/telegram_user/admin_test.rb` - Admin functionality tests

### Обновленные файлы:
- `test/test_helper.rb` - Добавлены Telegram bot конфигурация и DatabaseCleaner
- `test/fixtures/telegram_users.yml` - Расширен фикстуры
- `test/fixtures/channels.yml` - Новые фикстуры каналов
- `test/fixtures/subscriptions.yml` - Фикстуры подписок
- `test/models/telegram_user_test.rb` - Базовые тесты с подключением support модулей