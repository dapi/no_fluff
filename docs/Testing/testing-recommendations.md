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

## MocksHelper - Унифицированные моки

### 1. Базовые моки

```ruby
# ✅ Используйте встроенные моки из MocksHelper
test 'should handle user limits correctly' do
  limit_checker = mock_limit_checker(allowed: false, user_id: 12345)

  service = SubscriptionService.new(user)
  service.stubs(:limit_checker).returns(limit_checker)

  result = service.add_channel(channel)
  assert_not result[:success]
  assert_includes result[:error], 'limit exceeded'
end

# ✅ Мокирование Telegram клиента
test 'should send welcome message' do
  client = mock_telegram_client
  Telegram.stubs(:bot).returns(client)

  service = TelegramBotService.new
  service.send_welcome(12345, 'Welcome!')

  # Проверка вызовов
  assert client.called?
end
```

### 2. Продвинутые моки

```ruby
# ✅ Мокирование LLM моделей
test 'should process message with LLM' do
  llm_mock = mock_llm_model('Processed response', 'gpt-4')

  service = LLMProcessingService.new
  service.stubs(:llm_model).returns(llm_mock)

  result = service.process('Original message')
  assert_equal 'Processed response', result
end

# ✅ Мокирование вебхуков Telegram
test 'should handle webhook update' do
  webhook_data = mock_telegram_webhook('/start', 12345, 67890)

  service = WebhookService.new
  result = service.process_update(webhook_data)

  assert result[:success]
end

# ✅ Мокирование ответов API с пагинацией
test 'should handle paginated response' do
  items = ['item1', 'item2', 'item3']
  response = mock_paginated_response(items, 2)

  service.stubs(:api_call).returns(response)

  result = service.fetch_items
  assert_equal 2, result[:data].length
  assert_equal 3, result[:pagination][:total_count]
end
```

### 3. Комплексные сценарии

```ruby
# ✅ Создание набора моков для сложных тестов
test 'complete subscription workflow' do
  mocks = setup_basic_mocks(
    limit_checker: { allowed: true },
    telegram_client: { username: 'test_bot' },
    application_config: { 'limits' => { 'free_channels' => 5 } }
  )

  # Настройка моков
  Telegram.stubs(:bot).returns(mocks[:telegram_client])
  ApplicationConfig.stubs(:[]).returns(mocks[:application_config])

  # Тестирование workflow
  user = telegram_users(:one)
  channel = channels(:one)

  service = SubscriptionService.new(user)
  result = service.subscribe(channel)

  assert result[:success]
  assert user.subscriptions.exists?(channel: channel)
end

# ✅ Мокирование ошибок API
test 'should handle Telegram API errors' do
  error = mock_telegram_api_error(429, 'Too many requests')

  service = TelegramNotificationService.new
  service.stubs(:send_message).raises(error)

  result = service.notify_user(12345, 'Test message')
  assert_not result[:success]
  assert_includes result[:error], 'rate limit'
end
```

### 4. Хелперы для создания тестовых данных

```ruby
# ✅ Используйте хелперы для создания тестовых объектов
test 'should process channel data' do
  channel_data = create_test_channel(
    id: 12345,
    username: 'testchannel',
    title: 'Test Channel'
  )

  result = ChannelProcessor.process(channel_data)
  assert result[:success]
end

# ✅ Создание наборов данных для бенчмарков
test 'should handle large dataset efficiently' do
  users = create_test_dataset(100, :telegram_user)

  start_time = Time.now
  result = BulkUserService.process(users)
  end_time = Time.now

  assert result[:success]
  assert (end_time - start_time) < 5.0  # Должно выполняться менее 5 секунд
end
```

## Оптимизация тестов (Этапы 1-6 рефакторинга)

### 1. Использование AssertionHelper

```ruby
# ✅ Новые assertion методы
test 'should validate admin access' do
  user = telegram_users(:admin_user)
  assert_admin_access(user)
end

test 'should validate response format' do
  response = service.process_request(data)
  assert_response_format(response, success: true, data: Hash)
end
```

### 2. Оптимизированные фикстуры

```ruby
# ✅ Улучшенные фикстуры с реальными данными
test 'should use realistic user preferences' do
  user = telegram_users(:one)
  preferences = user_preferences(:one)

  assert preferences.topic_weights.present?
  assert_equal 1.5, preferences.adjusted_importance_threshold
  assert_equal 'medium', preferences.personalization_data['preferred_length']
end
```

### 3. Тестирование с FactoryHelper

```ruby
# ✅ Создание тестовых данных с фабрик
test 'should handle user with multiple subscriptions' do
  user = create_test_user_with_subscriptions(
    username: 'multi_sub_user',
    subscription_count: 5
  )

  assert_equal 5, user.subscriptions.count
  assert user.subscriptions.all? { |sub| sub.active? }
end

test 'should handle digest with items' do
  digest = create_test_digest_with_items(
    user: telegram_users(:one),
    items_count: 3
  )

  assert_equal 3, digest.user_digest_items.count
  assert digest.user_digest_items.all? { |item| item.position.present? }
end
```

### 4. Тестирование с TelegramHelper

```ruby
# ✅ Упрощенное тестирование Telegram бота
test 'should handle command processing' do
  bot = setup_test_bot
  user = telegram_users(:one)

  message = create_telegram_message(user, '/start')
  response = process_telegram_command(bot, message)

  assert_command_success(response)
  assert_includes response[:text], I18n.t('telegram_bot.start.welcome')
end

test 'should handle callback queries' do
  bot = setup_test_bot
  user = telegram_users(:one)

  callback = create_telegram_callback(user, 'settings:')
  response = process_telegram_callback(bot, callback)

  assert_callback_handled(response)
end
```

### 5. Профилирование производительности

```ruby
# ✅ Измерение времени выполнения
test 'should complete processing within time limit' do
  start_time = Time.now

  result = HeavyProcessingService.process(large_dataset)

  processing_time = Time.now - start_time
  assert processing_time < 2.0, "Processing took #{processing_time}s, expected < 2.0s"
  assert result[:success]
end

# ✅ Бенчмаркинг
test 'benchmark subscription creation' do
  iterations = 100

  time = Benchmark.realtime do
    iterations.times do
      Subscription.create!(
        telegram_user: telegram_users(:one),
        channel: channels(:one)
      )
    end
  end

  avg_time = time / iterations
  assert avg_time < 0.01, "Average creation time: #{avg_time}s"
end
```

### 6. Тестирование системных настроек

```ruby
# ✅ Работа с системными настройками в тестах
test 'should respect debug mode setting' do
  set_system_setting('debug_mode', true, 'Enable debug logging')

  service = DebugService.new
  result = service.process_debug_info

  assert result[:debug_enabled]

  cleanup_system_settings('debug_mode')
end

test 'should handle feature flags' do
  set_system_setting('premium_enabled', false)

  user = telegram_users(:one)
  result = SubscriptionService.check_premium_access(user)

  assert_not result[:premium_available]

  cleanup_system_settings('premium_enabled')
end
```

## Новые паттерны после рефакторинга

### 1. Унифицированная структура тестов

```ruby
# ✅ Стандартизированная структура
class ExampleTest < ActiveSupport::TestCase
  include MocksHelper
  include AssertionHelper
  include FactoryHelper

  setup do
    setup_telegram_mocks
    @user = telegram_users(:one)
  end

  teardown do
    cleanup_test_admins
    reset_all_mocks
  end

  # Группировка тестов по типу
  test 'validations: should require username' do
    # тест валидации
  end

  test 'associations: should have many subscriptions' do
    # тест ассоциаций
  end

  test 'business logic: should respect user limits' do
    # тест бизнес-логики
  end

  test 'error handling: should handle API failures' do
    # тест обработки ошибок
  end
end
```

### 2. Тестирование с помощью хелперов

```ruby
# ✅ Комплексные тесты с использованием всех хелперов
test 'complete user onboarding with optimizations' do
  # Подготовка данных
  user = create_test_user(username: 'newbie')
  bot = setup_test_bot

  # Мокирование внешних сервисов
  llm_mock = mock_llm_model('Welcome response!')
  service = OnboardingService.new(user)
  service.stubs(:llm).returns(llm_mock)

  # Тестирование процесса
  result = service.complete_onboarding

  # Проверки с помощью хелперов
  assert_response_format(result, success: true)
  assert_user_exists_with_attributes(user, username: 'newbie')
  assert_command_sent(result[:bot_response])
end
```

### 3. Измерение производительности

```ruby
# ✅ Тесты с замером времени
test 'should process 1000 subscriptions within performance budget' do
  subscriptions = create_test_dataset(1000, :subscription)

  processing_time = Benchmark.realtime do
    result = BulkSubscriptionProcessor.process(subscriptions)
    assert result[:success]
  end

  # Бюджет производительности: менее 5 секунд
  assert processing_time < 5.0,
    "Processing took #{processing_time.round(2)}s, budget is 5.0s"
end
```

Эта документация поможет поддерживать консистентность и качество тестов в проекте NoFluff с учетом всех оптимизаций и новых паттернов, внедренных в ходе рефакторинга тестовой системы.