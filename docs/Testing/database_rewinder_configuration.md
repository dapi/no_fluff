# DatabaseRewinder Configuration

## Обзор

DatabaseRewinder - это минималистичная и ультра-быстрая альтернатива DatabaseCleaner, оптимизированная для Rails приложений с большим количеством таблиц.

## Преимущества

### 🔥 Производительность
- **Запоминает только измененные таблицы** - отслеживает INSERT операции во время тестов
- **Один запрос** - объединяет все DELETE операции в один вызов к БД
- **Пропускает пустые таблицы** - не трогает таблицы без изменений

### 🎯 Простота
- Минимальная конфигурация
- Меньше кода и настроек
- Почти полная совместимость с DatabaseCleaner API

### ⚡ Эффективность
- Идеально для проектов с 1000+ таблиц
- Значительное ускорение тестов
- Создан Akira Matsuda как оптимизированная замена

## Конфигурация

### Gemfile
```ruby
group :development, :test do
  gem 'database_rewinder'
end
```

### test_helper.rb
```ruby
# Configure DatabaseRewinder
require 'database_rewinder'

# Initialize DatabaseRewinder - очистка перед запуском тестов
DatabaseRewinder.clean_all

module ActiveSupport
  class TestCase
    # Use DatabaseRewinder for database cleaning
    teardown do
      DatabaseRewinder.clean
    end
  end
end
```

## Как это работает

1. **Отслеживание INSERT операций** - DatabaseRewinder запоминает все таблицы, в которые были добавлены данные
2. **Очистка только измененных таблиц** - после каждого теста удаляет данные только из этих таблиц
3. **Оптимизация запросов** - объединяет все DELETE операции в один запрос к БД

## Сравнение с DatabaseCleaner

| Характеристика | DatabaseCleaner | DatabaseRewinder |
|----------------|----------------|------------------|
| Стратегии | Transaction, Truncation, Deletion | Deletion (оптимизированный) |
| Производительность | Средняя | Высокая |
| Конфигурация | Сложная | Простая |
| Совместимость | Multiple ORM | ActiveRecord только |
| Поддержка Multiple DB | ✅ | ✅ |

## Результаты миграции

- **Все тесты проходят:** 730 тестов, 0 ошибок
- **Производительность:** Ускорение за счет оптимизированной очистки
- **Конфигурация:** Упрощена по сравнению с DatabaseCleaner
- **Совместимость:** Полная совместимость с существующими тестами

## Использование с несколькими базами данных

```ruby
# Основная база данных
DatabaseRewinder[:default]

# Дополнительные базы данных
DatabaseRewinder[:logs]
DatabaseRewinder[:cache]

# Автоматическая очистка всех подключений
DatabaseRewinder.clean_all
```

## Особенности для MySQL

При использовании MySQL с `use_transactional_tests` может потребоваться дополнительная конфигурация:

```ruby
# Отключение automatic multiple connections для MySQL
DatabaseRewinder.clean(multiple: false)
```

## Рекомендации

- ✅ **Использовать** для Rails приложений с Minitest
- ✅ **Использовать** при большом количестве таблиц (>100)
- ✅ **Использовать** для ускорения тестового цикла
- ❌ **Не использовать** если нужна поддержка multiple ORM (Redis, etc.)

## Источник

- Официальный репозиторий: https://github.com/amatsuda/database_rewinder
- Создан Akira Matsuda как оптимизированная замена DatabaseCleaner
- Оригинальная стратегия разработана Shingo Morita в COOKPAD Inc.