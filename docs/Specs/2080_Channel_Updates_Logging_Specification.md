# Спецификация: Журналирование обновлений каналов

## Обзор

Система журналирования для отслеживания результатов обновления постов по каналам и мониторинга. Журнал представляет собой базу данных с записями о выполненных операциях.

## Цели

1. Создать централизованную систему логирования результатов выполнения фоновых задач
2. Обеспечить хранение детальной информации об операциях обновления каналов
3. Предоставить историю выполнения для анализа и отладки
4. Создать основу для будущего мониторинга и аналитики

## Требования

### Функциональные

#### 1. Модель журнала
- Создать модель `ChannelUpdateLog` для хранения записей
- Поля:
  - `source` (string) - источник записи (FetchPostsJob, MonitorJob и др.)
  - `message` (text) - текстовое сообщение о результате операции
  - `data` (jsonb) - структурированные данные операции
  - `status` (enum) - статус операции (success, error, warning, info)
  - `channel_id` (references) - связанный канал (если применимо)
  - `job_id` (string) - ID фонового задания
  - `execution_time_ms` (integer) - время выполнения в миллисекундах
  - `created_at` (datetime) - время создания записи

#### 2. Интеграция с FetchPostsJob
- Добавить создание записи в журнал для каждого выполнения
- Сохранять:
  - Количество обработанных постов
  - Ошибки при обработке
  - Время выполнения
  - ID канала
  - Детали в JSON формате

#### 3. Интеграция с MonitorJob
- Добавить создание записи с результатами мониторинга
- Сохранять:
  - Общее количество каналов
  - Количество отправленных на fetch
  - Количество пропущенных каналов
  - Причины пропуска
  - Время выполнения мониторинга

### Нефункциональные

#### 1. Производительность
- Запись логов не должна значительно замедлять выполнение основных задач
- Использовать асинхронную запись если необходимо

#### 2. Хранение данных
- Предусмотреть механизм очистки старых записей
- Оптимизировать запросы к логам

#### 3. Анализируемость
- Структура данных должна поддерживать удобные запросы
- JSON поле должно содержать всю необходимую детализацию

## Модель данных

### ChannelUpdateLog
```ruby
class ChannelUpdateLog < ApplicationRecord
  belongs_to :channel, optional: true

  enum status: { info: 'info', success: 'success', warning: 'warning', error: 'error' }

  validates :source, presence: true
  validates :message, presence: true
  validates :status, presence: true

  scope :by_source, ->(source) { where(source: source) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, ->(hours = 24) { where('created_at > ?', hours.hours.ago) }
  scope :for_channel, ->(channel) { where(channel: channel) }
end
```

### Миграция
```ruby
class CreateChannelUpdateLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_update_logs do |t|
      t.string :source, null: false, index: true
      t.text :message, null: false
      t.jsonb :data, default: {}, null: false
      t.string :status, null: false, index: true
      t.references :channel, null: true, foreign_key: true, index: true
      t.string :job_id, index: true
      t.integer :execution_time_ms
      t.timestamps
    end

    add_index :channel_update_logs, [:source, :created_at]
    add_index :channel_update_logs, [:channel_id, :created_at]
  end
end
```

## Использование

Для создания записей в журнале используется прямой вызов `ChannelUpdateLog.create`:

```ruby
ChannelUpdateLog.create!(
  source: 'FetchPostsJob',
  message: 'Successfully processed 15 posts',
  status: 'success',
  channel: channel,
  job_id: job_id,
  execution_time_ms: 1250,
  data: { posts_count: 15, new_posts: 3 }
)
```

## Интеграция с существующими Job

### FetchPostsJob
- Добавить логирование начала и завершения обработки
- Сохранять детализированную информацию о результате
- Обрабатывать ошибки и логировать их

### MonitorJob
- Логировать результаты мониторинга
- Сохранять статистику по обработанным и пропущенным каналам

## План тестирования

### Unit тесты
1. Простой тест модели ChannelUpdateLog на загружаемость из фикстуры

### Integration тесты
1. Тест интеграции с FetchPostsJob
2. Тест интеграции с MonitorJob
3. Тест сохранения данных в JSON поле
4. Тест ассоциаций с каналами

### Performance тесты
1. Тест производительности логирования
2. Тест влияния на время выполнения Job

## Последующие улучшения

1. **UI для просмотра логов**: Веб-интерфейс для просмотра и фильтрации записей
2. **Оповещения**: Уведомления об ошибках на основе логов
3. **Аналитика**: Статистика и графики на основе данных логов
4. **API эндпоинты**: Для внешнего доступа к логам
5. **Архивирование**: Механизм перемещения старых логов в архив

## Риски и митигации

1. **Размер базы данных**: Регулярная очистка старых записей
2. **Влияние на производительность**: Оптимизация запросов и индексов
3. **Сложность запросов**: Хорошая документация и удобные scopes