# Рекомендации по написанию тестов для проекта NoFluff

## Обзор

Документ содержит общие рекомендации, паттерны и правила для написания тестов в Rails проекте NoFluff с использованием Minitest.

## Структура тестов

### 1. Организация тестовых файлов

```
test/
├── models/                    # Тесты моделей
│   ├── telegram_user_test.rb
│   ├── channel_test.rb
│   └── concerns/             # Тесты concerns
├── controllers/              # Тесты контроллеров
│   └── telegram/
├── services/                 # Тесты сервисов
│   ├── telegram/
│   └── limits/
├── jobs/                     # Тесты фоновых задач
├── integration/              # Интеграционные тесты
├── fixtures/                 # Фикстуры
└── test_helper.rb           # Общая конфигурация
```

### 2. Именование тестов

Используйте описательные имена тестов на русском языке:

```ruby
# ✅ Хорошо
test 'should create user with valid attributes' do
test 'should validate uniqueness of username' do
test 'should handle API errors gracefully' do

# ❌ Плохо
test 'test_user_creation' do
test 'validation_works' do
test 'error_handling' do
```

## Базовые паттерны

### 1. Структура тестового класса

```ruby
require 'test_helper'

class TelegramUserTest < ActiveSupport::TestCase
  # Подготовка данных для каждого теста
  setup do
    @user = telegram_users(:one)
  end

  # Очистка после каждого теста
  teardown do
    # Очистка, если необходимо
  end

  # Группировка тестов по функциональности
  # Fixture tests
  test 'should load fixture' do
    # код теста
  end

  # Validation tests
  test 'should be valid with valid attributes' do
    # код теста
  end

  # Association tests
  test 'should have many subscriptions' do
    # код теста
  end

  # Business logic tests
  test 'can_add_channel? should respect premium limits' do
    # код теста
  end
end
```

### 2. Работа с фикстурами

```ruby
# ✅ Используйте фикстуры для базовых данных
test 'should load fixture' do
  user = telegram_users(:one)
  assert_not_nil user
end

# ✅ Создавайте данные в тестах для специфических сценариев
test 'should handle premium user limits' do
  user = TelegramUser.create!(
    username: 'premium_user',
    is_premium: true,
    # ... другие атрибуты
  )
  # тестовая логика
end
```

### 3. Тестирование валидаций

```ruby
# ✅ Комплексное тестирование валидаций
test 'should require username' do
  user = TelegramUser.new(timezone: 'UTC', language_code: 'en')
  assert_not user.valid?
  assert user.errors[:username].present?
end

test 'should enforce username uniqueness' do
  existing_user = telegram_users(:one)
  user = TelegramUser.new(username: existing_user.username, timezone: 'UTC')
  assert_not user.valid?
  assert user.errors[:username].present?
end

test 'should use default values for optional fields' do
  user = TelegramUser.new(username: 'test', language_code: 'en')
  assert user.valid?
  assert_equal 'UTC', user.timezone
end
```

### 4. Тестирование ассоциаций

```ruby
test 'should have many subscriptions' do
  user = telegram_users(:one)
  assert_respond_to user, :subscriptions
end

test 'should destroy associated subscriptions when destroyed' do
  user = TelegramUser.create!(username: 'test')
  subscription = user.subscriptions.create!(channel: channels(:one))

  assert_difference 'Subscription.count', -1 do
    user.destroy
  end
end
```

### 5. Тестирование enum

```ruby
test 'should have delivery_frequency enum' do
  user = telegram_users(:one)
  assert_respond_to user, :delivery_frequency_real_time?
  assert_respond_to user, :delivery_frequency_three_times_daily?
end

test 'should set delivery_frequency enum values' do
  user = telegram_users(:one)
  user.delivery_frequency = :real_time
  assert user.delivery_frequency_real_time?
  assert_equal 'real_time', user.delivery_frequency
end
```

### 6. Тестированиеscopes

```ruby
test 'premium scope should return only premium users' do
  premium_user = telegram_users(:one)
  premium_user.update!(is_premium: true)

  premium_users = TelegramUser.premium
  assert_includes premium_users, premium_user
end

test 'non_bots scope should exclude bot users' do
  bot_user = TelegramUser.create!(username: 'bot', is_bot: true)
  regular_user = TelegramUser.create!(username: 'user', is_bot: false)

  non_bots = TelegramUser.non_bots
  assert_not_includes non_bots, bot_user
  assert_includes non_bots, regular_user
end
```

## Тестирование сервисов

### 1. Базовая структура

```ruby
class Telegram::ChannelServiceTest < ActiveSupport::TestCase
  setup do
    @bot = Telegram.bot
    @service = Telegram::ChannelService.new(@bot)
    @user = telegram_users(:one)
  end

  test 'parse_channel_username extracts username from @username format' do
    assert_equal 'testchannel', @service.parse_channel_username('@testchannel')
  end

  test 'parse_channel_username returns nil for invalid format' do
    assert_nil @service.parse_channel_username('invalid format!')
    assert_nil @service.parse_channel_username('')
    assert_nil @service.parse_channel_username(nil)
  end
end
```

### 2. Тестирование с моками

```ruby
test 'add_channel_to_database creates new channel with username' do
  # Мокаем внешние зависимости
  mock_channel_info = {
    id: 12345,
    username: 'testchannel',
    title: 'Test Channel'
  }

  @service.stubs(:get_channel_info).returns(mock_channel_info)

  result = @service.add_channel_to_database('@testchannel')

  assert result[:success]
  assert_not_nil result[:channel]

  channel = result[:channel]
  assert_equal 12345, channel.telegram_id
  assert_equal 'testchannel', channel.username

  # Возвращаем оригинальный метод
  @service.unstub(:get_channel_info)
end
```

### 3. Тестирование обработки ошибок

```ruby
test 'get_channel_info handles errors gracefully' do
  # В тестовом окружении bot stubbed, поэтому get_chat вернет ошибку
  result = @service.get_channel_info('nonexistent')
  assert_nil result
end
```

## Тестирование контроллеров

### 1. Структура тестов контроллеров

```ruby
class TelegramWebhookControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset if @bot
  end

  # Helper методы
  def create_user_update(user_id: 123456, username: 'testuser', command: '/start')
    {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
        'from' => {
          'id' => user_id,
          'username' => username,
          'first_name' => 'Test'
        },
        'chat' => { 'id' => user_id, 'type' => 'private' },
        'text' => command
      }
    }
  end

  def send_webhook_update(update)
    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }
  end
end
```

### 2. Тестирование Telegram Bot API

```ruby
# ✅ Используйте helper методы для извлечения ответов бота
def extract_message_content(requests)
  message_requests = requests.select { |method, _| method == :sendMessage }
  return nil if message_requests.empty?

  method, params = message_requests.first
  params.first
end

test 'start command sends welcome message' do
  update = create_user_update(username: 'newuser', command: '/start')
  send_webhook_update(update)

  assert_response :success

  message_content = extract_message_content(@bot.requests)
  assert_not_nil message_content
  assert_includes message_content[:text], I18n.t('telegram_bot.start.welcome')
end
```

### 3. Тестирование callback queries

```ruby
test 'callback queries update messages appropriately' do
  update = {
    'update_id' => 1,
    'callback_query' => {
      'id' => 'callback_1',
      'from' => { 'id' => 123456, 'username' => 'testuser' },
      'message' => {
        'message_id' => 10,
        'chat' => { 'id' => 123456, 'type' => 'private' }
      },
      'data' => 'settings:'
    }
  }

  send_webhook_update(update)
  assert_response :success

  # Проверяем ответ на callback
  answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
  assert_not_nil answer_request
end
```

## Тестирование Telegram Bot

### 1. Конфигурация тестового окружения

```ruby
# test/test_helper.rb
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# Важно для тестирования telegram-bot
Telegram.reset_bots
Telegram::Bot::ClientStub.stub_all!

module ActiveSupport
  class TestCase
    fixtures :all

    setup do
      if ActiveRecord::Base.connection.respond_to?(:begin_transaction)
        ActiveRecord::Base.connection.begin_transaction(joinable: false)
      end
    end

    teardown do
      if ActiveRecord::Base.connection.respond_to?(:rollback_transaction) &&
          ActiveRecord::Base.connection.current_transaction.open?
        ActiveRecord::Base.connection.rollback_transaction
      end
    end
  end
end
```

### 2. Работа с ClientStub

```ruby
# ✅ Всегда сбрасывайте состояние бота
setup do
  @bot = Telegram.bot
  @bot.reset
end

teardown do
  @bot.reset if @bot
end

# ✅ Проверяйте типы запросов
test 'sends sendMessage request' do
  # код теста

  method, params = @bot.requests.first
  assert_equal :sendMessage, method
  assert_equal 123456, params[:chat_id]
end

# ✅ Проверяйте наличие клавиатур
test 'includes inline keyboard' do
  # код теста

  message_content = extract_message_content(@bot.requests)
  assert_not_nil message_content[:reply_markup]
  assert message_content[:reply_markup].is_a?(Telegram::Bot::Types::InlineKeyboardMarkup)
end
```

## Тестирование LLM сервисов (RubyLLM)

### 1. Изоляция конфигурации

```ruby
# ❌ Плохо - глобальная конфигурация
RubyLLM.configure do |config|
  config.openai_api_key = 'test-key'
end

# ✅ Хорошо - изолированный контекст
setup do
  @llm_context = RubyLLM.context do |config|
    config.openai_api_key = 'test-key'
    config.default_model = 'test-model'
    config.request_timeout = 1
  end
end
```

### 2. Мокирование LLM

```ruby
# ✅ Мокируйте ответы LLM
test 'processes message with mocked LLM' do
  mock_response = Minitest::Mock.new
  mock_response.expect(:content, "Test response")
  mock_response.expect(:model_id, "test-model")

  mock_chat = Minitest::Mock.new
  mock_chat.expect(:ask, mock_response, ["Hello"])

  @llm_context.stub(:chat, mock_chat) do
    service = LLMService.new(@user)
    result = service.process("Hello")
    assert result[:success]
  end

  mock_chat.verify
end
```

### 3. Тестирование обработки ошибок

```ruby
test 'handles LLM API errors gracefully' do
  mock_chat = Minitest::Mock.new
  mock_chat.expect(:ask, nil) do
    raise RubyLLM::Error.new("API Error")
  end

  @llm_context.stub(:chat, mock_chat) do
    service = LLMService.new(@user)
    result = service.process("test")
    assert_not result[:success]
  end
end
```

## Тестирование фоновых задач (Jobs)

### 1. Базовая структура

```ruby
class BotJoinJobTest < ActiveJob::TestCase
  test 'creates job with correct parameters' do
    BotJoinJob.perform_later(telegram_user: @user, channel: @channel)

    assert_enqueued_jobs 1
    assert_equal 'BotJoinJob', enqueued_jobs.last['job_class']
  end

  test 'processes channel join successfully' do
    perform_enqueued_jobs do
      BotJoinJob.perform_now(telegram_user: @user, channel: @channel)
    end

    # Проверяем результат выполнения
    assert @user.subscriptions.exists?(channel: @channel)
  end

  test 'handles join errors gracefully' do
    # Мокируем ошибку
    Telegram::ChannelService.any_instance.stubs(:add_channel_for_user).returns({ success: false })

    perform_enqueued_jobs do
      BotJoinJob.perform_now(telegram_user: @user, channel: @channel)
    end

    # Проверяем что ошибка обработана
  end
end
```

## Интеграционные тесты

### 1. Тестирование полных workflow

```ruby
test 'complete user onboarding workflow' do
  # 1. Создаем нового пользователя
  update = create_user_update(username: 'newbie', command: '/start')
  send_webhook_update(update)
  assert_response :success

  user = TelegramUser.find_by(username: 'newbie')
  assert_not_nil user

  # 2. Пользователь нажимает кнопку онбординга
  @bot.reset
  update = create_callback_update(user_id: user.id, data: 'start_onboarding:')
  send_webhook_update(update)
  assert_response :success

  # 3. Проверяем результат
  edit_content = extract_edited_message_content(@bot.requests)
  assert_includes edit_content[:text], I18n.t('telegram_bot.onboarding.add_channels')
end
```

### 2. Тестирование сложных сценариев

```ruby
test 'subscription management workflow' do
  # Создаем пользователя с подписками
  user = TelegramUser.create!(username: 'subscriber', first_name: 'Test')
  channel1 = Channel.create!(telegram_id: 1001, username: 'channel1', title: 'Channel 1')
  channel2 = Channel.create!(telegram_id: 1002, username: 'channel2', title: 'Channel 2')

  Subscription.create!(telegram_user: user, channel: channel1)
  Subscription.create!(telegram_user: user, channel: channel2)

  # Тестируем команду списка
  update = create_user_update(user_id: user.id, command: '/list')
  send_webhook_update(update)

  message_content = extract_message_content(@bot.requests)
  assert_includes message_content[:text], 'Channel 1'
  assert_includes message_content[:text], 'Channel 2'
end
```

## Best Practices

### 1. Организация тестов

- **Группируйте тесты по функциональности** - валидации, ассоциации, бизнес-логика
- **Используйте описательные имена тестов** на русском языке
- **Создавайте helper методы** для повторяющихся действий
- **Изолируйте тесты** друг от друга с помощью setup/teardown

### 2. Работа с данными

```ruby
# ✅ Используйте фикстуры для базовых данных
user = telegram_users(:one)
channel = channels(:one)

# ✅ Создавайте данные в тестах для специфических сценариев
user = TelegramUser.create!(username: 'test', is_premium: true)

# ❌ Избегайте создания данных в глобальных переменных
```

### 3. Тестирование внешних зависимостей

```ruby
# ✅ Всегда мокируйте внешние API
service.stubs(:external_api_call).returns(mock_response)

# ✅ Возвращайте оригинальные методы после тестов
service.unstub(:external_api_call) if service.respond_to?(:unstub)

# ✅ Тестируйте обработку ошибок
service.stubs(:external_api_call).raises(ExternalAPIError)
```

### 4. Утверждения (assertions)

```ruby
# ✅ Используйте конкретные assertions
assert_equal 'expected_value', actual_value
assert_includes text, 'substring'
assert_respond_to object, :method_name

# ✅ Проверяйте количество записей
assert_difference 'Model.count', 1 do
  # код, создающий запись
end

# ✅ Проверяйте отсутствие изменений
assert_no_difference 'Model.count' do
  # код, не создающий записи
end
```

### 5. Тестирование локализации

```ruby
# ✅ Используйте I18n.t для проверки локализованных строк
assert_includes response[:message], I18n.t('telegram_bot.start.welcome')

# ❌ Избегайте хардкода строк
assert_includes response[:message], 'Добро пожаловать'  # Плохо
```

### 6. Обработка ошибок

```ruby
# ✅ Тестируйте позитивные и негативные сценарии
test 'handles valid input' do
  result = service.process(valid_input)
  assert result[:success]
end

test 'handles invalid input gracefully' do
  result = service.process(invalid_input)
  assert_not result[:success]
  assert_includes result[:error], 'validation failed'
end

# ✅ Тестируйте edge cases
test 'handles nil input' do
  result = service.process(nil)
  assert_not result[:success]
end
```

## Анти-паттерны

### 1. Избегайте этих подходов

```ruby
# ❌ Не создавайте данные в глобальных переменных
@user = User.create! # Плохо

# ❌ Не тестируйте несколько вещей в одном тесте
test 'should create user and send email and update profile' do
  # Разбейте на отдельные тесты
end

# ❌ Не используйте sleep в тестах
sleep 1 # Плохо - используйте моки или асинхронные тесты

# ❌ Не игнорируйте очистку после тестов
# Очищайте временные файлы, моки, транзакции
```

### 2. Слишком сложные тесты

```ruby
# ❌ Избегайте слишком сложной логики в тестах
test 'complex business logic with many conditions' do
  if condition1 && condition2 || condition3
    # Слишком много условий
  end
end

# ✅ Разбивайте на простые, сфокусированные тесты
test 'should handle condition1' do
  # фокус на одном сценарии
end

test 'should handle condition2' do
  # фокус на другом сценарии
end
```

## Производительность тестов

### 1. Оптимизация

```ruby
# ✅ Используйте fixtures для многократно используемых данных
fixtures :all

# ✅ Используйте транзакции для изоляции тестов
setup { ActiveRecord::Base.connection.begin_transaction }
teardown { ActiveRecord::Base.connection.rollback_transaction }

# ✅ Создавайте общие helper методы
def create_telegram_update(command)
  # код создания update
end
```

### 2. Параллельный запуск

```ruby
# test/test_helper.rb
# Отключаем параллельный запуск для telegram-bot тестов
# parallelize(workers: :number_of_processors)
```

## Покрытие кода тестами

### 1. Что тестировать

- ✅ **Все модели** - валидации, ассоциации, методы
- ✅ **Все сервисы** - основную бизнес-логику
- ✅ **Все контроллеры** - основные user flows
- ✅ **Все jobs** - фоновые задачи
- ✅ **Критические пути** - registration, login, core functionality
- ✅ **Обработку ошибок** - API failures, validation errors

### 2. Что можно не тестировать

- ⚠️ **Простые getters/setters** (если нет логики)
- ⚠️ **Тривиальные методы** без зависимостей
- ⚠️ **Код от фреймворков** (сам Rails)
- ⚠️ **Внешние библиотеки** (проверяйте только интеграцию)

Эта документация поможет поддерживать консистентность и качество тестов в проекте NoFluff.