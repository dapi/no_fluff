# План рефакторинга: Переход на DatabaseRewinder

## Контекст

Анализ DatabaseCleaner vs DatabaseRewinder для Rails проекта с Minitest.

### Результаты анализа

**DatabaseCleaner:**
- Зрелый библиотека с большим сообществом (25k+ проектов)
- Поддерживает multiple ORM (ActiveRecord, Redis, etc.)
- 3 стратегии: transaction (по умолчанию), truncation, deletion
- Медленнее на проектах с большим количеством таблиц
- Требует больше настроек

**DatabaseRewinder:**
- Ультра-быстрый - запоминает таблицы с INSERT операциями
- Минималистичный - меньше кода и настроек
- Оптимизирован для проектов с 1000+ таблиц
- Один DELETE запрос для всех таблиц
- Создан Akira Matsuda как оптимизированная замена DatabaseCleaner

### Рекомендация

**Использовать DatabaseRewinder** потому что:
1. **Производительность** - быстрее при большом количестве таблиц
2. **Простота** - меньше конфигурации
3. **Minitest совместимость** - отлично работает
4. **Современный подход** - оптимизированная замена

## План реализации

### Текущая ситуация
- Используется `database_cleaner-active_record` со стратегией `:transaction`
- Конфигурация в `test_helper.rb` строками 23-27
- Автоматическая очистка после каждого теста

### Этапы рефакторинга

#### Этап 1: Подготовка ✅
- [x] Проанализировать текущую конфигурацию DatabaseCleaner
- [x] Изучить существующие настройки в test_helper.rb

#### Этап 2: Замена зависимостей
- [ ] Заменить в Gemfile:
  ```ruby
  # Было:
  gem 'database_cleaner-active_record', require: false

  # Стало:
  gem 'database_rewinder'
  ```
- [ ] Выполнить `bundle install`

#### Этап 3: Обновление конфигурации test_helper.rb
- [ ] Заменить строки 23-27:
  ```ruby
  # Старый код:
  require 'database_cleaner/active_record'
  DatabaseCleaner.strategy = :transaction
  DatabaseCleaner.allow_remote_database_url = true

  # Новый код:
  require 'database_rewinder'
  DatabaseRewinder.clean_all
  ```

- [ ] Заменить блок setup/teardown:
  ```ruby
  # Старый код:
  setup { DatabaseCleaner.start }
  teardown { DatabaseCleaner.clean }

  # Новый код:
  teardown { DatabaseRewinder.clean }
  ```

#### Этап 4: Валидация
- [ ] Запустить тесты: `./bin/rails test`
- [ ] Проверить производительность
- [ ] Убедиться что все тесты проходят

#### Этап 5: Документация
- [ ] Создать файл `docs/Testing/database_rewinder_configuration.md`
- [ ] Описать преимущества и конфигурацию

### Преимущества DatabaseRewinder

1. **Скорость:** Запоминает только измененные таблицы, очищает их одним запросом
2. **Простота:** Минимум конфигурации
3. **Эффективность:** Идеально для проектов с большим количеством таблиц
4. **Совместимость:** Почти полностью совместим с DatabaseCleaner API

### Ожидаемые результаты

- Ускорение выполнения тестов
- Упрощение конфигурации
- Сохранение функциональности
- Улучшение поддерживаемости кода

## Статус

**Создан:** 2 ноября 2024 г.
**Автор:** Claude Code Assistant
**Статус:** Готов к реализации