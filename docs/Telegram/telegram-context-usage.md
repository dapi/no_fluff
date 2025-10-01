# Telegram Bot Context Usage Guide

## Обзор для AI-агентов

В проекте NoFluff используется `telegram-bot-rb` gem с фреймворком `UpdatesController`. Понимание **payload** и **context** критически важно для правильной разработки Telegram бота.

---

## 1. Payload - Данные обновления Telegram

### Что такое payload?
`payload` - это полный объект обновления от Telegram API, содержащий все данные о сообщении, callback query, и других событиях.

### Доступ к payload
```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def some_method!
    # payload содержит всё обновление
    update_type = payload.keys.first # 'message', 'callback_query', etc.

    # Проверка типа обновления
    if payload['callback_query']
      # Это callback query
      callback_data = payload['callback_query']['data']
      message = payload['callback_query']['message']
    elsif payload['message']
      # Это обычное сообщение
      text = payload['message']['text']
      user = payload['message']['from']
    end
  end
end
```

### Структура payload
```ruby
# Для callback query:
payload = {
  'update_id' => 123,
  'callback_query' => {
    'id' => 'callback_123',
    'from' => { 'id' => 456, 'username' => 'user' },
    'message' => {
      'message_id' => 789,
      'chat' => { 'id' => 456, 'type' => 'private' },
      'text' => 'Previous text'
    },
    'data' => 'action:param1:param2'
  }
}

# Для обычного сообщения:
payload = {
  'update_id' => 124,
  'message' => {
    'message_id' => 790,
    'from' => { 'id' => 456, 'username' => 'user' },
    'chat' => { 'id' => 456, 'type' => 'private' },
    'text' => '/start'
  }
}
```

---

## 2. Context - Управление состоянием

### MessageContext - Ожидание следующего сообщения
Используется для многошаговых диалогов между ботом и пользователем.

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  def start_registration!(*)
    save_context :await_name
    respond_with :message, text: 'Как ваше имя?'
  end

  # Этот метод будет вызван для следующего сообщения пользователя
  def await_name(text = nil)
    if text
      session[:user_name] = text
      save_context :await_age
      respond_with :message, text: 'Сколько вам лет?'
    else
      respond_with :message, text: 'Пожалуйста, введите имя текстом'
    end
  end

  def await_age(age = nil)
    if age&.match?(/^\d+$/)
      session[:user_age] = age.to_i
      # Завершаем регистрацию
      respond_with :message, text: "Регистрация завершена! Имя: #{session[:user_name]}, возраст: #{session[:user_age]}"
    else
      respond_with :message, text: 'Пожалуйста, введите возраст цифрами'
    end
  end
end
```

### CallbackQueryContext - Роутинг callback кнопок
Автоматически разделяет обработку callback queries по префиксам в `callback_data`.

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext

  # Обработает callback_data = "remove_channel:123"
  def remove_channel_callback_query(channel_id = nil, *)
    answer_callback_query('')

    if channel_id
      subscription = current_user.subscriptions.find_by(channel_id: channel_id)
      if subscription
        subscription.deactivate!
        edit_message :text, text: "Канал удален из подписок"
      end
    end
  end

  # Обработает callback_data = "priority_up:123"
  def priority_up_callback_query(channel_id = nil, *)
    answer_callback_query('')

    if channel_id
      subscription = current_user.subscriptions.find_by(channel_id: channel_id)
      if subscription && subscription.priority < 10
        subscription.update(priority: subscription.priority + 1)
        edit_message :text, text: "Приоритет увеличен"
      end
    end
  end

  # Обработчик для callback без префикса
  def callback_query(data = nil, *)
    answer_callback_query('Неизвестная команда')
  end
end
```

---

## 3. Best Practices для NoFluff проекта

### 3.1. Проверка источника обновления
```ruby
# Определяем, можем ли редактировать сообщение или нужно отправлять новое
if payload['message']
  # Это обычное сообщение - отвечаем новым сообщением
  respond_with :message, text: "Ваши подписки:", reply_markup: keyboard
else
  # Это callback query - редактируем существующее сообщение
  edit_message :text, text: "Ваши подписки:", reply_markup: keyboard
end
```

### 3.2. Безопасная работа с callback данными
```ruby
def some_action_callback_query(action_id = nil, *)
  answer_callback_query('') # Всегда отвечаем на callback query

  # Валидация параметров
  return unless action_id&.match?(/^\d+$/)

  # Поиск сущности
  item = current_user.items.find_by(id: action_id)
  return unless item

  # Выполнение действия
  item.update(status: :processed)

  # Обновление интерфейса
  if payload['callback_query']['message']
    edit_message :text, text: "Обработано!"
  end
end
```

### 3.3. Использование session для временных данных
```ruby
def start_complex_action!(*)
  session[:complex_action] = {
    step: 1,
    data: {},
    started_at: Time.current
  }
  save_context :complex_action_step_1
  respond_with :message, text: 'Шаг 1: введите данные'
end

def complex_action_step_1(input)
  session[:complex_action][:step] = 2
  session[:complex_action][:data][:input1] = input

  save_context :complex_action_step_2
  respond_with :message, text: 'Шаг 2: подтвердите действие'
end
```

---

## 4. Примеры из текущего проекта

### 4.1. Управление подписками (SubscriptionCommands concern)
```ruby
# Callback data: "remove_channel:123"
def remove_channel_callback_query(channel_id)
  answer_callback_query('')
  find_or_create_user

  subscription = current_user.subscriptions.active.find_by(channel_id: channel_id)
  if subscription
    # Показываем подтверждение
    confirm_kb = [
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text: '🗑️ Удалить',
        callback_data: "confirm_remove:#{channel_id}"
      )]
    ]

    edit_message :text,
      text: "Удалить @{subscription.channel.username}?",
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: confirm_kb)
  end
end
```

### 4.2. Обработка разных типов обновлений
```ruby
def my_subscriptions_callback_query(*)
  answer_callback_query('')
  find_or_create_user

  subscriptions = current_user.subscriptions.includes(:channel).active.by_priority

  if subscriptions.empty?
    # Проверяем есть ли сообщение для редактирования
    if payload['message']
      edit_message :text, text: I18n.t('telegram_bot.channels.list.empty')
    else
      respond_with :message, text: I18n.t('telegram_bot.channels.list.empty')
    end
  else
    # Есть подписки - показываем список
    list_content = build_subscriptions_list(subscriptions)
    keyboard = subscriptions_keyboard(subscriptions)

    if payload['message']
      edit_message :text, text: list_content, reply_markup: keyboard
    else
      respond_with :message, text: list_content, reply_markup: keyboard
    end
  end
end
```

---

## 5. Типичные ошибки и как их избежать

### 5.1. Не отвечать на callback query
```ruby
# ❌ ПЛОХО - забыт answer_callback_query
def bad_callback_handler(id)
  # some logic
  edit_message :text, text: "Готово!"
end

# ✅ ХОРОШО - всегда отвечаем на callback
def good_callback_handler(id)
  answer_callback_query('') # Обязательный ответ
  # some logic
  edit_message :text, text: "Готово!"
end
```

### 5.2. Попытка редактировать несуществующее сообщение
```ruby
def safe_edit_example
  # Проверяем наличие message в payload
  if payload['callback_query']&.[]('message')
    edit_message :text, text: "Обновлено"
  else
    respond_with :message, text: "Обновлено"
  end
end
```

### 5.3. Забытый find_or_create_user
```ruby
def callback_handler(id)
  answer_callback_query('')
  find_or_create_user  # Важно для доступа к current_user

  subscription = current_user.subscriptions.find(id)
  # ... logic
end
```

---

## 6. Тестирование с payload

```ruby
test "callback query with complex data" do
  user_data = { 'id' => 123, 'username' => 'testuser' }

  update = {
    'update_id' => 1,
    'callback_query' => {
      'id' => 'callback_1',
      'from' => user_data,
      'message' => {
        'message_id' => 10,
        'chat' => { 'id' => 123, 'type' => 'private' },
        'text' => 'Previous text'
      },
      'data' => 'complex_action:123:456:param'
    }
  }

  post telegram_webhook_path, params: update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  assert_response :success

  # Проверяем answerCallbackQuery
  answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
  assert_not_nil answer_request

  # Проверяем editMessageText
  edit_request = @bot.requests.find { |method, _| method == :editMessageText }
  assert_not_nil edit_request
end
```

---

## Ключевые выводы для AI-агента:

1. **Всегда проверяйте `payload['message']` перед `edit_message`**
2. **Всегда вызывайте `answer_callback_query('')` в callback обработчиках**
3. **Используйте `find_or_create_user` в callback методах для доступа к `current_user`**
4. **Используйте `CallbackQueryContext` для автоматического роутинга callback'ов**
5. **Используйте `MessageContext` для многошаговых диалогов**
6. **Храните временные данные в `session`**
7. **Проверяйте и валидируйте параметры из callback data**
8. **Правильно обрабатывайте случаи когда пользователя или данные не найдены**