# Тестирование RubyLLM в Rails приложении

## Обзор

Документация описывает лучшие практики конфигурации и мокирования RubyLLM в тестовом окружении Rails с использованием Minitest.

## 1. Конфигурация для тестов

### Изоляция конфигурации

RubyLLM не должен конфигурироваться в тестовом окружении для предотвращения реальных API запросов:

```ruby
# config/initializers/ruby_llm.rb
unless Rails.env.test?
  RubyLLM.configure do |config|
    config.openai_api_key = ApplicationConfig.openai_api_key
    config.deepseek_api_key = ApplicationConfig.deepseek_api_key
    config.default_model = ApplicationConfig.llm_default_model
    config.use_new_acts_as = true
  end
end
```

### Создание изолированного контекста для тестов

Используйте `RubyLLM.context` для создания изолированной конфигурации в тестах:

```ruby
def setup_ruby_llm_context
  @llm_context = RubyLLM.context do |config|
    config.openai_api_key = 'test-key'
    config.default_model = 'test-model'
    config.request_timeout = 5
    # Отключаем реальные запросы
    config.openai_api_base = 'http://localhost:1234/v1'
  end
end
```

## 2. Мокирование RubyLLM

### Базовое мокирование с использованием Minitest::Mock

```ruby
require 'test_helper'

class ChatServiceTest < ActiveSupport::TestCase
  setup do
    @llm_context = setup_ruby_llm_context

    # Создаем mock для chat
    @chat_mock = Minitest::Mock.new
    @llm_context.stub(:chat, @chat_mock) do
      # Тестовый код здесь
    end
  end

  test "chat interaction works correctly" do
    # Настраиваем ожидания
    response_mock = Minitest::Mock.new
    response_mock.expect(:content, "Test response")
    response_mock.expect(:model_id, "test-model")

    @chat_mock.expect(:ask, response_mock, ["Hello"])

    # Выполняем тестируемый код
    chat = @llm_context.chat
    response = chat.ask("Hello")

    # Проверяем результаты
    assert_equal "Test response", response.content
    @chat_mock.verify
  end
end
```

### Мокирование с использованием stubs (Borrowed from existing tests)

```ruby
test "handles RubyLLM errors gracefully" do
  # Мокаем метод chat чтобы вызвать ошибку
  RubyLLM.stubs(:chat).raises(RubyLLM::Error.new("API Error"))

  service = ChatService.new
  result = service.process_message("test")

  assert_not result[:success]
  assert_includes result[:error], "Произошла ошибка"

  RubyLLM.unstub(:chat)
end
```

### Мокирование tools

```ruby
class WeatherTool < RubyLLM::Tool
  description "Gets weather for a location"
  param :location, desc: "City name"

  def execute(location:)
    { temperature: 22, conditions: "sunny" }
  end
end

test "tool execution works correctly" do
  tool_instance = WeatherTool.new

  # Мокаем выполнение инструмента
  tool_instance.stub(:execute, { temperature: 25, conditions: "cloudy" }) do
    chat = @llm_context.chat.with_tool(tool_instance)

    # Мокаем ответ модели
    response_mock = Minitest::Mock.new
    response_mock.expect(:content, "Погода в Москве: 25°C, облачно")
    chat.stub(:ask, response_mock) do
      result = chat.ask("Какая погода в Москве?")
      assert_includes result.content, "25°C"
    end
  end
end
```

## 3. Тестирование моделей с acts_as_chat

### Подготовка тестовых данных

```ruby
# test/fixtures/chats.yml
one:
  telegram_user: one
  model: one
  created_at: <%= 1.hour.ago %>

# test/fixtures/models.yml
one:
  model_id: gpt-4
  name: GPT-4
  provider: openai
  family: gpt-4

# test/fixtures/messages.yml
one:
  chat: one
  content: "Hello world"
  role: user
  created_at: <%= 1.hour.ago %>
```

### Тестирование модели Chat

```ruby
class ChatTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
  end

  test "chat can process messages with mocked LLM" do
    # Мокаем LLM interaction
    mock_response = Minitest::Mock.new
    mock_response.expect(:content, "AI response")
    mock_response.expect(:role, "assistant")

    # Мокаем метод ask для чата
    @chat.stub(:ask, mock_response) do
      response = @chat.ask("Test question")
      assert_equal "AI response", response.content
    end
  end

  test "chat handles tool calls" do
    # Создаем тестовый tool
    test_tool = Class.new(RubyLLM::Tool) do
      description "Test tool"
      param :input, desc: "Test input"

      def execute(input:)
        "Processed: #{input}"
      end
    end

    # Мокаем tool execution
    tool_instance = test_tool.new
    @chat.stub(:with_tool, @chat) do
      @chat.stub(:ask, OpenStruct.new(content: "Tool executed")) do
        response = @chat.with_tool(tool_instance).ask("Execute tool")
        assert_equal "Tool executed", response.content
      end
    end
  end
end
```

## 4. Тестирование сервисов с RubyLLM

### Пример сервиса для тестирования

```ruby
# app/services/ai_assistant_service.rb
class AiAssistantService
  def initialize(user)
    @user = user
    @chat = RubyLLM.chat(
      model: user.preferred_model || ApplicationConfig.llm_default_model,
      system: system_prompt
    )
  end

  def process_message(message)
    response = @chat.ask(message)

    # Сохраняем в базу
    chat_record = Chat.create!(
      telegram_user: @user,
      model: Model.find_by(model_id: response.model_id)
    )

    Message.create!(
      chat: chat_record,
      content: message,
      role: :user
    )

    Message.create!(
      chat: chat_record,
      content: response.content,
      role: :assistant
    )

    {
      success: true,
      response: response.content,
      model_used: response.model_id
    }
  rescue RubyLLM::Error => e
    {
      success: false,
      error: "AI service unavailable: #{e.message}"
    }
  end

  private

  def system_prompt
    "You are a helpful assistant for NoFluff bot."
  end
end
```

### Тестирование сервиса

```ruby
class AiAssistantServiceTest < ActiveSupport::TestCase
  setup do
    @user = telegram_users(:one)
    @service = AiAssistantService.new(@user)

    # Создаем изолированный контекст для каждого теста
    @llm_context = RubyLLM.context do |config|
      config.openai_api_key = 'test-key'
      config.default_model = 'test-model'
    end
  end

  test "successfully processes message" do
    # Мокаем chat и ответ
    mock_chat = Minitest::Mock.new
    mock_response = Minitest::Mock.new

    mock_response.expect(:content, "Test AI response")
    mock_response.expect(:model_id, "test-model")

    mock_chat.expect(:ask, mock_response, ["Hello"])

    # Заменяем chat в сервисе
    @service.instance_variable_set(:@chat, mock_chat)

    result = @service.process_message("Hello")

    assert result[:success]
    assert_equal "Test AI response", result[:response]
    assert_equal "test-model", result[:model_used]

    # Проверяем что сообщения были сохранены
    assert_equal 1, Chat.count
    assert_equal 2, Message.count  # user + assistant

    mock_chat.verify
  end

  test "handles API errors gracefully" do
    # Мокаем chat чтобы вызвать ошибку
    mock_chat = Minitest::Mock.new
    mock_chat.expect(:ask, nil) do
      raise RubyLLM::Error.new("API Error")
    end

    @service.instance_variable_set(:@chat, mock_chat)

    result = @service.process_message("Hello")

    assert_not result[:success]
    assert_includes result[:error], "AI service unavailable"

    # Проверяем что ничего не было сохранено
    assert_equal 0, Chat.count
    assert_equal 0, Message.count
  end

  test "uses user preferred model" do
    @user.update!(preferred_model: "gpt-4")

    service = AiAssistantService.new(@user)

    # Проверяем что сервис использует правильную модель
    # Это потребует рефакторинга сервиса для лучшей тестируемости
    # Например, вынести конфигурацию чата в отдельный метод
    chat = service.send(:initialize_chat)

    # Проверка зависит от реализации
    assert_includes chat.instance_variables, :@model
  end
end
```

## 5. Тестирование streaming

```ruby
class StreamingChatServiceTest < ActiveSupport::TestCase
  test "processes streaming responses" do
    service = StreamingChatService.new(@user)

    # Мокаем streaming chunks
    chunks = [
      OpenStruct.new(content: "Hello "),
      OpenStruct.new(content: "world!"),
      OpenStruct.new(content: "", tool_calls: nil)  # End marker
    ]

    mock_chat = Minitest::Mock.new

    # Мокаем streaming ask
    mock_chat.expect(:ask, nil) do |message, &block|
      chunks.each(&block)
      OpenStruct.new(content: "Hello world!")
    end

    service.instance_variable_set(:@chat, mock_chat)

    accumulated_content = ""
    result = service.process_streaming_message("Test") do |chunk|
      accumulated_content += chunk.content if chunk.content
    end

    assert_equal "Hello world!", accumulated_content
    assert result[:success]
  end
end
```

## 6. Интеграционные тесты с VCR (опционально)

Если необходимо тестировать реальные API взаимодействия:

```ruby
# Gemfile
group :test do
  gem 'vcr'
  gem 'webmock'
end

# test/support/vcr_setup.rb
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ApplicationConfig.openai_api_key }
  config.filter_sensitive_data('<DEEPSEEK_API_KEY>') { ApplicationConfig.deepseek_api_key }
end

# test/test_helper.rb
require_relative 'support/vcr_setup'

class RubyLLMIntegrationTest < ActiveSupport::TestCase
  test "real API integration" do
    VCR.use_cassette("ruby_llm_chat") do
      chat = RubyLLM.chat(model: "gpt-3.5-turbo")
      response = chat.ask("What is 2+2?")

      assert_includes response.content, "4"
    end
  end
end
```

## 7. Best Practices

### 1. Изолируйте тесты
- Используйте `RubyLLM.context` для изоляции конфигурации
- Не конфигурируйте RubyLLM глобально в тестах
- Сбрасывайте моки после каждого теста

### 2. Мокируйте внешние зависимости
- Всегда мокируйте API запросы к LLM провайдерам
- Используйте `stubs` для простого мокирования
- Используйте `Minitest::Mock` для сложных сценариев

### 3. Тестируйте обработку ошибок
- Проверяйте обработку `RubyLLM::Error`
- Тестируйте сетевые ошибки
- Проверяйте обработку невалидных ответов

### 4. Тестируйте модели и ассоциации
- Проверяйте корректность сохранения в базу данных
- Тестируйте `acts_as_chat`, `acts_as_message` и т.д.
- Используйте fixtures для создания тестовых данных

### 5. Организация тестов
- Создавайте базовые классы для тестов с RubyLLM
- Выносите повторяющийся код в helper методы
- Используйте описательные имена тестов

## 8. Пример полного тестового класса

```ruby
require 'test_helper'

class LLMServiceTest < ActiveSupport::TestCase
  setup do
    @user = telegram_users(:one)
    setup_llm_context
  end

  teardown do
    clear_llm_mocks
  end

  private

  def setup_llm_context
    @llm_context = RubyLLM.context do |config|
      config.openai_api_key = 'test-key'
      config.default_model = 'test-model'
      config.request_timeout = 1
    end
  end

  def mock_chat_response(content, model_id = 'test-model')
    response = Minitest::Mock.new
    response.expect(:content, content)
    response.expect(:model_id, model_id)
    response.expect(:role, 'assistant')
    response
  end

  def clear_llm_mocks
    RubyLLM.unstub(:chat) if RubyLLM.respond_to?(:unstub)
  end

  test "comprehensive LLM interaction" do
    # Пример комплексного теста
    mock_chat = Minitest::Mock.new
    mock_response = mock_chat_response("Complete response")

    mock_chat.expect(:ask, mock_response, ["Test message"])

    @llm_context.stub(:chat, mock_chat) do
      service = LLMService.new(@user)
      result = service.process("Test message")

      assert result[:success]
      assert_equal "Complete response", result[:content]
    end

    mock_chat.verify
  end
end
```

Этот подход обеспечивает надежное тестирование функциональности RubyLLM без реальных API запросов и поддерживает чистоту тестового окружения.