# Telegram Keyboard Helpers

## Обзор

`Telegram::KeyboardHelpers` - это concern, который предоставляет удобные методы для создания inline-клавиатур в Telegram ботах, сокращая количество дублирующегося кода и улучшая читаемость.

## Проблема

Стандартный способ создания inline-кнопок в telegram-bot-rb требует много дублирования:

```ruby
# Старый способ
kb = [
  [
    Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Настройки',
      callback_data: 'settings:'
    ),
    Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Помощь',
      callback_data: 'help:'
    )
  ],
  [
    Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Назад',
      callback_data: 'main:'
    )
  ]
]
Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
```

## Решение

С использованием `Telegram::KeyboardHelpers` код становится гораздо чище:

```ruby
# Новый способ
inline_keyboard(
  keyboard_row(
    callback_button('Настройки', 'settings:'),
    callback_button('Помощь', 'help:')
  ),
  keyboard_row(
    callback_button('Назад', 'main:')
  )
)
```

## Использование

### 1. Подключение concern

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::KeyboardHelpers

  # ваши методы
end
```

### 2. Основные методы

#### `callback_button(text, data)`
Создает кнопку с `callback_data`.

```ruby
callback_button('Настройки', 'settings:')
callback_button('Удалить', "delete:#{item.id}")
```

#### `url_button(text, url)`
Создает кнопку, открывающую URL.

```ruby
url_button('Google', 'https://google.com')
url_button('Перейти', post.link)
```

#### `button(text, callback_data = nil, url: nil, **options)`
Универсальный метод для создания кнопок с любыми параметрами.

```ruby
# Callback кнопка
button('Настройки', 'settings:')

# URL кнопка
button('Google', nil, url: 'https://google.com')

# Inline query кнопка
button('Поиск', nil, switch_inline_query: 'query')

# С дополнительными параметрами
button('Текст', 'data', **{parse_mode: 'Markdown'})
```

#### `keyboard_row(*buttons)`
Создает ряд кнопок.

```ruby
keyboard_row(
  callback_button('Да', 'yes'),
  callback_button('Нет', 'no')
)
```

#### `inline_keyboard(*rows)`
Создает полную клавиатуру из рядов кнопок.

```ruby
inline_keyboard(
  keyboard_row(button1, button2),
  keyboard_row(button3),
  keyboard_row(button4, button5, button6)
)
```

## Примеры из реального кода

### Простая клавиатура

```ruby
def start_keyboard
  inline_keyboard(
    keyboard_row(
      callback_button('Начать', 'start_onboarding:'),
      callback_button('Подробнее', 'more_info:')
    ),
    keyboard_row(
      callback_button('⚙️ Настройки', 'settings:')
    )
  )
end
```

### Клавиатура с динамическими кнопками

```ruby
def subscriptions_keyboard(subscriptions)
  return nil if subscriptions.empty?

  keyboard = subscriptions.map do |subscription|
    keyboard_row(
      callback_button('⬆️', "priority_up:#{subscription.channel_id}"),
      callback_button('⬇️', "priority_down:#{subscription.channel_id}"),
      callback_button('❌', "remove_channel:#{subscription.channel_id}")
    )
  end

  inline_keyboard(*keyboard)
end
```

### Клавиатура с условными кнопками

```ruby
def delivery_frequency_keyboard
  inline_keyboard(
    keyboard_row(
      callback_button(
        'Реальное время',
        current_user.delivery_frequency_real_time? ? 'settings:' : 'set_delivery_frequency:real_time'
      ),
      callback_button(
        '3 раза в день',
        current_user.delivery_frequency_three_times_daily? ? 'settings:' : 'set_delivery_frequency:three_times_daily'
      )
    ),
    keyboard_row(
      callback_button('← Назад', 'settings:')
    )
  )
end
```

### Клавиатура с разными типами кнопок

```ruby
def complex_keyboard
  inline_keyboard(
    keyboard_row(
      callback_button('Действие 1', 'action1:'),
      url_button('Внешний сайт', 'https://example.com')
    ),
    keyboard_row(
      button('Поиск', nil, switch_inline_query: 'search:')
    )
  )
end
```

## Преимущества

1. **Меньше дублирования** - не нужно писать `Telegram::Bot::Types::InlineKeyboardButton.new` для каждой кнопки
2. **Лучше читаемость** - `callback_button('Текст', 'data')` легче читать, чем длинная конструкция с `new`
3. **Типобезопасность** - все еще создаются правильные объекты Telegram API
4. **Гибкость** - универсальный метод `button` позволяет создавать кнопки с любыми параметрами
5. **Легкая отладка** - более чистый код легче отлаживать

## Миграция со старого кода

### Было:
```ruby
def settings_keyboard
  kb = [
    [
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: 'Частота',
        callback_data: 'frequency:'
      ),
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: 'Формат',
        callback_data: 'format:'
      )
    ],
    [
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: 'Назад',
        callback_data: 'main:'
      )
    ]
  ]
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
end
```

### Стало:
```ruby
def settings_keyboard
  inline_keyboard(
    keyboard_row(
      callback_button('Частота', 'frequency:'),
      callback_button('Формат', 'format:')
    ),
    keyboard_row(
      callback_button('Назад', 'main:')
    )
  )
end
```

## Результат

- **Строк кода:** уменьшено на ~60%
- **Читаемость:** значительно улучшена
- **Поддерживаемость:** упрощена
- **Функциональность:** полностью сохранена