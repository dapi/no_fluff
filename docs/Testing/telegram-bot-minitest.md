# Тестирование Telegram Bot контроллеров через Minitest

## Обзор

Документация описывает лучшие практики тестирования Telegram ботов на Rails с использованием Minitest и gem `telegram-bot`. Особое внимание уделено проверке ответов бота и использованию ClientStub для мокирования API запросов.

## 1. Настройка тестового окружения

### В `test/test_helper.rb`:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Важно для тестирования telegram-bot
Telegram.reset_bots
Telegram::Bot::ClientStub.stub_all!

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end
```

## 2. Структура теста контроллера

```ruby
require "test_helper"

class TelegramWebhookControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset  # Очищаем предыдущие запросы
  end

  teardown do
    @bot.reset  # Очищаем после каждого теста
  end

  # Пример теста команды
  test "start command creates user and sends welcome message" do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test',
      'last_name' => 'User',
      'language_code' => 'ru'
    }

    update = {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/start'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success
    # Проверки ответа бота...
  end
end
```

## 3. Проверка ответов бота

### Основные методы проверки:

```ruby
# Проверка количества запросов к API
assert_equal 1, @bot.requests.size

# Получение первого запроса
method, params = @bot.requests.first
params = params.first

# Проверка метода API
assert_equal :sendMessage, method
assert_equal :editMessageText, method
assert_equal :answerCallbackQuery, method

# Проверка параметров запроса
assert_equal 123456, params[:chat_id]
assert_includes params[:text], 'Привет!'
assert_includes params[:text], 'No Fluff Bot'

# Проверка наличия клавиатуры
assert_not_nil params[:reply_markup]
assert params[:reply_markup].is_a?(Telegram::Bot::Types::InlineKeyboardMarkup)
```

### Поиск конкретных типов запросов:

```ruby
# Найти все sendMessage запросы
send_message_requests = @bot.requests.select { |method, _| method == :sendMessage }

# Найти конкретный тип запроса
edit_request = @bot.requests.find { |method, _| method == :editMessageText }
answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }

# Проверка наличия запроса
assert_not_nil edit_request, "Expected editMessageText request"
```

## 4. Тестирование разных типов обновлений

### Команды:

```ruby
test "help command sends help message" do
  update = {
    'update_id' => 2,
    'message' => {
      'message_id' => 2,
      'from' => user_data,
      'chat' => { 'id' => 123456, 'type' => 'private' },
      'text' => '/help'
    }
  }

  post telegram_webhook_path, params: update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  assert_response :success
  # Проверки...
end
```

### Callback queries:

```ruby
test "callback query handles button click" do
  update = {
    'update_id' => 3,
    'callback_query' => {
      'id' => 'callback_1',
      'from' => user_data,
      'message' => {
        'message_id' => 10,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => 'Previous text'
      },
      'data' => 'start_onboarding:'
    }
  }

  post telegram_webhook_path, params: update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  assert_response :success

  # Проверяем ответ на callback
  answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
  assert_not_nil answer_request

  # Проверяем редактирование сообщения
  edit_request = @bot.requests.find { |method, _| method == :editMessageText }
  assert_not_nil edit_request
end
```

### Обычные сообщения:

```ruby
test "message with @username triggers channel addition" do
  update = {
    'update_id' => 4,
    'message' => {
      'message_id' => 15,
      'from' => user_data,
      'chat' => { 'id' => 123456, 'type' => 'private' },
      'text' => '@testchannel'
    }
  }

  post telegram_webhook_path, params: update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  assert_response :success
  # Проверки...
end
```

## 5. Тестирование клавиатур

```ruby
# Проверка inline клавиатуры
def assert_inline_keyboard_present(params)
  assert_not_nil params[:reply_markup], "Expected reply_markup"
  assert params[:reply_markup].is_a?(Telegram::Bot::Types::InlineKeyboardMarkup)
end

# Проверка кнопок
def assert_button(keyboard, row_index, col_index, text, callback_data = nil)
  assert keyboard.length > row_index, "Keyboard doesn't have row #{row_index}"
  assert keyboard[row_index].length > col_index, "Row #{row_index} doesn't have column #{col_index}"

  button = keyboard[row_index][col_index]
  assert_equal text, button.text
  assert_equal callback_data, button.callback_data if callback_data
end

# Использование в тесте
test "list command shows management buttons" do
  # ... код теста ...

  keyboard = params[:reply_markup].inline_keyboard
  assert_equal 2, keyboard.length  # Две строки

  # Проверяем кнопки управления
  assert_button(keyboard, 0, 0, '⬆️', 'priority_up:123')
  assert_button(keyboard, 0, 1, '⬇️', 'priority_down:123')
  assert_button(keyboard, 0, 2, '🗑️', 'remove_channel:123')
end
```

## 6. Тестирование сессий

```ruby
test "multi-step dialog with sessions" do
  # Шаг 1: Начало регистрации
  post telegram_webhook_path, params: start_update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  # Проверяем первый ответ
  assert_equal 1, @bot.requests.size

  # Шаг 2: Ответ на вопрос
  post telegram_webhook_path, params: name_update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  # Проверяем второй ответ
  assert_equal 2, @bot.requests.size
  method, params = @bot.requests.last
  assert_equal :sendMessage, method
  assert_includes params[:text], 'Сколько вам лет?'
end
```

## 7. Тестирование ошибок

```ruby
test "invalid channel format returns error" do
  update = {
    'update_id' => 5,
    'message' => {
      'message_id' => 14,
      'from' => user_data,
      'chat' => { 'id' => 123456, 'type' => 'private' },
      'text' => '/add invalid!'
    }
  }

  post telegram_webhook_path, params: update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  assert_response :success

  method, params = @bot.requests.first
  assert_equal :sendMessage, method
  assert_includes params[:text], 'Неверный формат'
end
```

## 8. Best Practices

1. **Используйте descriptive test names** - `test "start command creates user and sends welcome message"`
2. **Создавайте helper методы** для повторяющихся проверок
3. **Изолируйте тесты** - сбрасывайте бот состояние в setup/teardown
4. **Тестируйте все типы ответов** - sendMessage, editMessageText, answerCallbackQuery
5. **Проверяйте параметры** - chat_id, текст, клавиатуры
6. **Используйте fixtures или factory** для создания тестовых данных
7. **Тестируйте edge cases** - неверные данные, пустые списки и т.д.

## 9. Отладка тестов

```ruby
# Для отладки можно вывести все запросы
puts "All requests: #{@bot.requests.inspect}"

# Или посмотреть конкретный запрос
method, params = @bot.requests.first
puts "Method: #{method}, Params: #{params.inspect}"
```

## 10. Пример полного теста

```ruby
test "complete subscription management flow" do
  # Создаем тестовые данные
  user = TelegramUser.create!(
    username: 'testuser',
    first_name: 'Test',
    language_code: 'ru'
  )

  channel = Channel.create!(
    telegram_id: 1001,
    username: 'testchannel',
    title: 'Test Channel'
  )

  subscription = Subscription.create!(
    telegram_user: user,
    channel: channel,
    priority: 5,
    active: true
  )

  # 1. Проверяем команду /list
  list_update = {
    'update_id' => 10,
    'message' => {
      'message_id' => 10,
      'from' => {
        'id' => 123456,
        'username' => 'testuser',
        'first_name' => 'Test'
      },
      'chat' => { 'id' => 123456, 'type' => 'private' },
      'text' => '/list'
    }
  }

  post telegram_webhook_path, params: list_update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  assert_response :success
  assert_equal 1, @bot.requests.size

  method, params = @bot.requests.first
  assert_equal :sendMessage, method
  assert_includes params[:text], 'Test Channel'
  assert_inline_keyboard_present(params)

  # 2. Нажимаем кнопку увеличения приоритета
  priority_update = {
    'update_id' => 11,
    'callback_query' => {
      'id' => 'callback_priority',
      'from' => {
        'id' => 123456,
        'username' => 'testuser'
      },
      'message' => {
        'message_id' => 10,
        'chat' => { 'id' => 123456, 'type' => 'private' }
      },
      'data' => "priority_up:#{channel.id}"
    }
  }

  post telegram_webhook_path, params: priority_update.to_json,
    headers: { 'Content-Type' => 'application/json' }

  assert_response :success
  assert_equal 2, @bot.requests.size

  # Проверяем что приоритет изменился
  subscription.reload
  assert_equal 6, subscription.priority

  # Проверяем ответ на callback
  answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
  assert_not_nil answer_request
end
```

Этот подход позволяет полноценно тестировать Telegram ботов с использованием Minitest, проверяя все аспекты работы контроллера.