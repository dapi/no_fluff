# Репозиторий паттернов тестирования NoFluff

## Шаблоны для разных типов тестов

### Модельные тесты (Model Tests)
```ruby
require 'test_helper'

class ModelNameTest < ActiveSupport::TestCase
  setup do
    @model = model_name(:one)
  end

  # Fixture tests
  test 'should load fixture' do
    model = model_name(:one)
    assert_not_nil model
  end

  # Validation tests
  test 'should be valid with valid attributes' do
    # тест валидации
  end

  # Association tests  
  test 'should have associations' do
    assert_respond_to @model, :association_name
  end

  # Business logic tests
  test 'should implement business logic correctly' do
    # тест бизнес-логики
  end
end
```

### Telegram Bot тесты (Controller Tests)
```ruby
require 'test_helper'

class TelegramWebhookControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset if @bot
  end

  def create_user_update(command: '/start')
    {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
        'from' => { 'id' => 123456, 'username' => 'testuser' },
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => command
      }
    }
  end

  def send_webhook_update(update)
    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }
  end

  test 'command works correctly' do
    update = create_user_update(command: '/start')
    send_webhook_update(update)

    assert_response :success
    # проверки ответа бота
  end
end
```

### LLM сервис тесты (Service Tests)
```ruby
require 'test_helper'

class LLMServiceTest < ActiveSupport::TestCase
  setup do
    @user = telegram_users(:one)
    @llm_context = RubyLLM.context do |config|
      config.openai_api_key = 'test-key'
      config.default_model = 'test-model'
    end
  end

  teardown do
    RubyLLM.unstub(:chat) if RubyLLM.respond_to?(:unstub)
  end

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
end
```

### Джобы (Background Jobs)
```ruby
require 'test_helper'

class JobNameTest < ActiveJob::TestCase
  test 'enqueues job with correct parameters' do
    JobName.perform_later(param1: 'value1', param2: 'value2')

    assert_enqueued_jobs 1
    assert_equal 'JobName', enqueued_jobs.last['job_class']
  end

  test 'executes job successfully' do
    perform_enqueued_jobs do
      JobName.perform_now(param1: 'value1', param2: 'value2')
    end

    # проверки результата выполнения
  end
end
```

## Частые Helper методы

### Telegram Helper
```ruby
def create_user_update(user_id: 123456, username: 'testuser', command: '/start')
  # создание update объекта
end

def create_callback_update(data: 'test:')
  # создание callback query
end

def extract_message_content(requests)
  message_requests = requests.select { |method, _| method == :sendMessage }
  return nil if message_requests.empty?
  method, params = message_requests.first
  params.first
end

def extract_edited_message_content(requests)
  edit_requests = requests.select { |method, _| method == :editMessageText }
  return nil if edit_requests.empty?
  method, params = edit_requests.first
  params.first
end
```

### LLM Helper
```ruby
def setup_test_llm_context(custom_model: nil)
  @llm_context = RubyLLM.context do |config|
    config.openai_api_key = 'test-key'
    config.default_model = custom_model || 'test-model'
    config.request_timeout = 1
    config.max_retries = 0
  end
end

def mock_llm_response(content, model_id: nil)
  response = Minitest::Mock.new
  response.expect(:content, content)
  response.expect(:model_id, model_id || 'test-model')
  response.expect(:role, 'assistant')
  response
end

def cleanup_llm_mocks
  RubyLLM.unstub(:chat) if RubyLLM.respond_to?(:unstub)
end
```

## Анти-паттерны и как их избежать

### ❌ Анти-паттерн: Глобальные переменные
```ruby
# Плохо
class TestClass < ActiveSupport::TestCase
  @user = User.create!  # глобальная переменная
end

# Хорошо
class TestClass < ActiveSupport::TestCase
  setup do
    @user = User.create!  # локальная для каждого теста
  end
end
```

### ❌ Анти-паттерн: Сложные тесты
```ruby
# Плохо
test 'should handle multiple conditions' do
  if condition1 && condition2 || condition3
    # много логики
  end
end

# Хорошо - разбить на простые тесты
test 'should handle condition1' do
  # фокус на одном сценарии
end

test 'should handle condition2' do
  # фокус на другом сценарии
end
```

## Best Practices чек-лист

### Перед написанием теста
- [ ] Изучен `docs/Testing/testing-recommendations.md`
- [ ] Просмотрены существующие похожие тесты
- [ ] Определен тип теста (model/controller/service)
- [ ] Подготовлены тестовые данные

### Во время написания теста
- [ ] Использованы project-specific паттерны
- [ ] Применены правильные helper методы
- [ ] Использованы фикстуры где возможно
- [ ] Добавлены описательные имена

### После написания теста
- [ ] Проверена работа теста
- [ ] Очищены моки и временные данные
- [ ] Следует принципу RED-GREEN-REFACTOR
- [ ] Тест изолирован от других тестов

Этот репозиторий помогает агентам быстро применять правильные паттерны тестирования в проекте.