# Спецификация 006: Telegram Message Processing

## Мета информация

- **Номер:** 006
- **Название:** Telegram Message Processing
- **Автор:**
- **Создана:** 2025-11-02
- **Статус:** delivered
- **Связанные спецификации:**



# 006 Telegram Message Processing Specification

## Обзор

Спецификация описывает обработку входящих сообщений Telegram с четким разделением на прямые сообщения от пользователей и сообщения из каналов, на которые подписан бот.

## Требования

### 1. Разделение типов сообщений

Бот должен различать два типа входящих сообщений:
- **Прямые сообщения (Direct Messages)**: Сообщения, отправленные напрямую боту пользователем
- **Канальные сообщения (Channel Messages)**: Сообщения из каналов, на которые подписан бот

### 2. Поведение бота

#### 2.1 Прямые сообщения
- Бот должен обрабатывать все прямые сообщения от пользователей
- Бот должен отвечать на прямые сообщения согласно основной логике
- Прямые сообщения сохраняются в стандартной таблице `telegram_messages`

#### 2.2 Канальные сообщения
- Бот НЕ должен реагировать на сообщения из каналов
- Бот НЕ должен отправлять ответы на канальные сообщения
- ВСЕ канальные сообщения должны сохраняться в специальную таблицу

### 3. Структура данных

#### 3.1 Таблица `channel_messages`
```ruby
create_table :channel_messages do |t|
  t.bigint "message_id", null: false
  t.bigint "channel_id", null: false
  t.string "channel_username"
  t.string "channel_title"
  t.bigint "sender_id"
  t.string "sender_username"
  t.string "sender_first_name"
  t.string "sender_last_name"
  t.text "content"
  t.string "message_type"
  t.jsonb "raw_data"
  t.datetime "created_at", precision: 6, null: false

  t.index ["channel_id"], name: "index_channel_messages_on_channel_id"
  t.index ["message_id", "channel_id"], name: "index_channel_messages_on_unique", unique: true
end
```

#### 3.2 Модель ChannelMessage
```ruby
class ChannelMessage < ApplicationRecord
  validates :message_id, presence: true
  validates :channel_id, presence: true
  validates :content, presence: true

  scope :from_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :recent, -> { order(created_at: :desc) }
end
```

### 4. Логика TelegramController

#### 4.1 Определение типа сообщения
```ruby
def message_type
  if update[:message]&.dig(:chat)&.dig(:type) == 'channel'
    :channel_message
  else
    :direct_message
  end
end
```

#### 4.2 Основной flow
```ruby
def process_message
  case message_type
  when :channel_message
    save_channel_message
    # НИКАКИХ ответов и обработки
  when :direct_message
    process_direct_message
    # Стандартная обработка
  end
end
```

#### 4.3 Сохранение канальных сообщений
```ruby
def save_channel_message
  message = update[:message]
  ChannelMessage.create!(
    message_id: message[:message_id],
    channel_id: message.dig(:chat, :id),
    channel_username: message.dig(:chat, :username),
    channel_title: message.dig(:chat, :title),
    sender_id: message.dig(:from, :id),
    sender_username: message.dig(:from, :username),
    sender_first_name: message.dig(:from, :first_name),
    sender_last_name: message.dig(:from, :last_name),
    content: extract_content(message),
    message_type: extract_message_type(message),
    raw_data: message
  )
end
```

### 5. Типы контента в канальных сообщениях

- `text` - текстовые сообщения
- `photo` - фотографии
- `video` - видео
- `document` - документы
- `audio` - аудио
- `voice` - голосовые сообщения
- `sticker` - стикеры
- `animation` - GIF анимации

### 6. Обработка ошибок

При сохранении канальных сообщений:
- Логировать ошибки сохранения в Bugsnag
- Не прерывать обработку других сообщений
- Сохранять raw_data для анализа проблем

### 7. Тестирование

#### 7.1 Unit тесты
- Тестирование определения типа сообщения
- Тестирование сохранения канальных сообщений
- Тестирование извлечения контента

#### 7.2 Integration тесты
- Тестирование полного flow обработки канальных сообщений
- Проверка что бот не отвечает на канальные сообщения
- Проверка сохранения всех типов контента

#### 7.3 Тестовые данные
Пример webhook с канальным сообщением:
```json
{
  "update_id": 123456789,
  "message": {
    "message_id": 987,
    "chat": {
      "id": -1001234567890,
      "title": "Test Channel",
      "username": "testchannel",
      "type": "channel"
    },
    "date": 1640995200,
    "text": "Test message from channel",
    "from": {
      "id": 123456789,
      "first_name": "Test",
      "username": "testuser"
    }
  }
}
```

### 8. Мониторинг

- Метрики по количеству сохраненных канальных сообщений
- Ошибки сохранения канальных сообщений
- Активность каналов по времени

### 9. Ограничения

- Максимальный размер контента: 1MB для текста, 20MB для файлов
- Уникальность: `(message_id, channel_id)` должен быть уникальным
- Хранение raw_data только для анализа проблем

### 10. Будущие улучшения

- Возможность настройки фильтрации каналов
- Агрегация статистики по каналам
- Поиск по содержимому канальных сообщений
- Экспорт канальных сообщений

---

## Статус: need_plan

**Примечание**: Спецификация готова и имеет план имплементации:
- ✅ Все требования детально описаны
- ✅ Форматы данных определены
- ✅ Edge cases продуманы
- ✅ План реализации создан

**План реализации**: [Spec_006_Telegram_Message_Processing_Implementation.md](../Implementation/Spec_006_Telegram_Message_Processing_Implementation.md)