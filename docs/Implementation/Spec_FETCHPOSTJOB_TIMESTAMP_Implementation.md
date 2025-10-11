# План реализации: Сохранение времени удачного обновления канала (fetchpostjob)

## Обзор

Документ описывает пошаговый план реализации функциональности сохранения времени последнего успешного обновления канала.

## Шаг 1: Создание миграции

### 1.1 Создание миграции
```bash
./bin/rails g migration AddLastSuccessfulUpdateAtToChannels last_successful_update_at:timestamp
```

### 1.2 Содержимое миграции
```ruby
class AddLastSuccessfulUpdateAtToChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :channels, :last_successful_update_at, :timestamp, null: true
    add_index :channels, :last_successful_update_at
  end
end
```

### 1.3 Применение миграции
```bash
./bin/rails db:migrate
```

## Шаг 2: Создание Concern для обновлений канала

### 2.1 Создание файла Concern
```ruby
# app/models/concerns/channel_updatable.rb

module ChannelUpdatable
  extend ActiveSupport::Concern

  # Обновление времени успешного обновления
  def mark_as_successfully_updated
    update!(last_successful_update_at: Time.current)
  end

  # Проверка на актуальность канала
  def stale?(threshold = 24.hours)
    last_successful_update_at.blank? ||
    last_successful_update_at < threshold.ago
  end

  # Форматированное время обновления
  def last_update_formatted
    return I18n.t('channels.never_updated') if last_successful_update_at.blank?

    I18n.l(last_successful_update_at, format: :short)
  end

  # Статус актуальности
  def freshness_status
    return 'never_updated' if last_successful_update_at.blank?
    return 'stale' if stale?
    'fresh'
  end
end
```

### 2.2 Подключение Concern к модели Channel
```ruby
# app/models/channel.rb

class Channel < ApplicationRecord
  include ChannelUpdatable

  # ... существующий код ...
end
```

## Шаг 3: Модификация Jobs::FetchPostJob

### 3.1 Анализ существующего кода
- Найти файл `app/jobs/fetch_post_job.rb`
- Определить место успешного завершения операций

### 3.2 Интеграция сохранения времени
```ruby
# app/jobs/fetch_post_job.rb

class FetchPostJob < ApplicationJob
  # ... существующий код ...

  def perform(channel)
    # ... существующая логика ...

    # После успешного выполнения всех операций
    channel.mark_as_successfully_updated

  # ... существующий код ...
  rescue => e
    # ... существующая обработка ошибок ...
    raise e
  end
end
```

## Шаг 4: Добавление локализации

### 4.1 Обновление файла локализации
```yaml
# config/locales/ru.yml

ru:
  channels:
    never_updated: 'Никогда не обновлялся'
    last_update: 'Последнее обновление'
    status:
      fresh: 'Актуальный'
      stale: 'Устаревший'
      never_updated: 'Без обновлений'
```

## Шаг 5: Тестирование

### 5.1 Проверка миграции
```bash
./bin/rails db:migrate:status
```

### 5.2 Ручное тестирование
1. Выполнить задачу FetchPostJob для тестового канала
2. Проверить что поле `last_successful_update_at` заполнено
3. Проверить что время обновляется при повторных выполнениях
4. Проверить что время НЕ обновляется при ошибке

## Шаг 6: Валидация

### 6.1 Проверка критериев готовности
- [ ] Миграция успешно применена
- [ ] Поле времени обновляется после успешного выполнения fetchpostjob
- [ ] Время не обновляется при ошибках
- [ ] Локализация работает корректно

### 6.2 Дополнительные проверки
- Производительность не ухудшилась
- Нет ошибок в логах при выполнении задачи
- Обратная совместимость с существующими каналами

## Риски и митигация

### Риск 1: Ошибки при сохранении времени
**Митигация**: Обернуть вызов в try-catch, чтобы не прерывать основную логику

### Риск 2: Ухудшение производительности
**Митигация**: Добавить индекс, минимизировать количество запросов к БД

### Риск 3: Проблемы с часовыми поясами
**Митигация**: Использовать `Time.current` и форматирование через I18n

## Завершение

После выполнения всех шагов и валидации функциональность будет готова к использованию. Время последнего успешного обновления будет сохраняться для всех каналов.