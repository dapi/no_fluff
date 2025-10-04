# Практические примеры мокирования LLM для проекта NoFluff

## Обзор

Документация содержит конкретные примеры мокирования RubyLLM для функциональности бота "Без шелухи", включая фильтрацию контента, суммаризацию и классификацию тем.

## 1. Настройка базового тестового окружения

### Создание тестового хелпера для LLM

```ruby
# test/support/llm_test_helper.rb
module LlmTestHelper
  def setup_test_llm_context(custom_model: nil)
    @llm_context = RubyLLM.context do |config|
      config.openai_api_key = 'test-key'
      config.deepseek_api_key = 'test-key'
      config.default_model = custom_model || 'test-model'
      config.request_timeout = 1
      config.max_retries = 0
    end
  end

  def mock_llm_response(content, model_id: nil, tokens: nil)
    response = Minitest::Mock.new
    response.expect(:content, content)
    response.expect(:model_id, model_id || 'test-model')
    response.expect(:role, 'assistant')
    response.expect(:input_tokens, tokens || 10) if tokens
    response.expect(:output_tokens, tokens || 15) if tokens
    response
  end

  def mock_llm_chat(responses = {})
    chat = Minitest::Mock.new

    responses.each do |input, output|
      response = output.is_a?(Hash) ? mock_llm_response(**output) : mock_llm_response(output)
      chat.expect(:ask, response, [input])
    end

    chat
  end

  def cleanup_llm_mocks
    RubyLLM.unstub(:chat) if RubyLLM.respond_to?(:unstub)
    RubyLLM.unstub(:embed) if RubyLLM.respond_to?(:unstub)
  end

  def setup_embedding_context
    @embedding_context = RubyLLM.context do |config|
      config.default_embedding_model = 'test-embedding-model'
    end
  end

  def mock_embedding_response(vectors)
    embedding = Minitest::Mock.new
    embedding.expect(:to_a, vectors)
    embedding.expect(:size, vectors.size)
    embedding
  end
end
```

### Интеграция в test_helper.rb

```ruby
# test/test_helper.rb
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require_relative 'support/llm_test_helper'

module ActiveSupport
  class TestCase
    fixtures :all
    include LlmTestHelper
  end
end
```

## 2. Тестирование фильтрации контента

### Сервис для фильтрации новостей

```ruby
# app/services/content_filter_service.rb
class ContentFilterService
  include Callable

  def initialize(user)
    @user = user
    @chat = RubyLLM.chat(
      model: ApplicationConfig.llm_default_model,
      system: filter_system_prompt,
      temperature: 0.1
    )
  end

  def call(content)
    response = @chat.ask(filter_prompt(content))

    {
      relevant: parse_relevance(response.content),
      reason: extract_reason(response.content),
      categories: extract_categories(response.content)
    }
  rescue RubyLLM::Error => e
    {
      relevant: false,
      reason: "Ошибка фильтрации: #{e.message}",
      categories: []
    }
  end

  private

  def filter_system_prompt
    <<~PROMPT
      Ты - умный фильтр контента для новостного бота.
      Анализируй содержание и определяй:
      1. Актуальность для пользователя (да/нет)
      2. Категорию (технологии, бизнес, наука, политика и т.д.)
      3. Причину решения
      Пользователь интересуется: #{@user.interests.join(', ')}
    PROMPT
  end

  def filter_prompt(content)
    "Проанализируй новость:\n\n#{content}\n\nОтветь в формате JSON: {relevant: boolean, reason: string, categories: array}"
  end

  def parse_relevance(response)
    # Парсинг JSON ответа
    match = response.match(/relevant:\s*(true|false)/i)
    match ? match[1].downcase == 'true' : false
  end

  def extract_reason(response)
    match = response.match(/reason:\s*["']([^"']+)["']/i)
    match ? match[1] : 'Причина не указана'
  end

  def extract_categories(response)
    match = response.match(/categories:\s*\[(.*?)\]/i)
    return [] unless match

    match[1].split(',').map(&:strip).map { |cat| cat.gsub(/["']/, '') }
  end
end
```

### Тестирование сервиса фильтрации

```ruby
# test/services/content_filter_service_test.rb
require 'test_helper'

class ContentFilterServiceTest < ActiveSupport::TestCase
  setup do
    @user = telegram_users(:one)
    @user.update!(interests: ['технологии', 'программирование'])
    setup_test_llm_context
  end

  teardown do
    cleanup_llm_mocks
  end

  test "filters relevant technology content correctly" do
    tech_content = "Новый фреймворк Ruby on Rails 8.0 released с улучшенной производительностью"

    mock_response = mock_llm_response(
      <<~JSON
        {
          "relevant": true,
          "reason": "Новость касается технологий и программирования, что соответствует интересам пользователя",
          "categories": ["технологии", "программирование"]
        }
      JSON
    )

    mock_chat = mock_llm_chat(tech_content => mock_response)

    @llm_context.stub(:chat, mock_chat) do
      service = ContentFilterService.new(@user)
      result = service.call(tech_content)

      assert result[:relevant]
      assert_includes result[:categories], 'технологии'
      assert_includes result[:categories], 'программирование'
      assert_includes result[:reason], 'технологии'
    end

    mock_chat.verify
  end

  test "rejects irrelevant political content" do
    political_content = "Правительство приняло новый закон о налогообложении"

    mock_response = mock_llm_response(
      <<~JSON
        {
          "relevant": false,
          "reason": "Политическая новость не соответствует интересам пользователя в технологиях",
          "categories": ["политика"]
        }
      JSON
    )

    mock_chat = mock_llm_chat(political_content => mock_response)

    @llm_context.stub(:chat, mock_chat) do
      service = ContentFilterService.new(@user)
      result = service.call(political_content)

      assert_not result[:relevant]
      assert_includes result[:categories], 'политика'
      assert_includes result[:reason], 'не соответствует интересам'
    end

    mock_chat.verify
  end

  test "handles API errors gracefully" do
    content = "Тестовый контент"

    mock_chat = Minitest::Mock.new
    mock_chat.expect(:ask, nil) do
      raise RubyLLM::Error.new("API rate limit exceeded")
    end

    @llm_context.stub(:chat, mock_chat) do
      service = ContentFilterService.new(@user)
      result = service.call(content)

      assert_not result[:relevant]
      assert_includes result[:reason], 'Ошибка фильтрации'
      assert_includes result[:reason], 'rate limit'
    end
  end

  test "handles malformed JSON responses" do
    content = "Тестовый контент"

    mock_response = mock_llm_response("Invalid JSON response without proper format")

    mock_chat = mock_llm_chat(content => mock_response)

    @llm_context.stub(:chat, mock_chat) do
      service = ContentFilterService.new(@user)
      result = service.call(content)

      # Должно обработать malformed JSON и вернуть значения по умолчанию
      assert_not result[:relevant]
      assert_equal [], result[:categories]
    end

    mock_chat.verify
  end
end
```

## 3. Тестирование суммаризации контента

### Сервис для создания дайджестов

```ruby
# app/services/content_summarizer_service.rb
class ContentSummarizerService
  include Callable

  def initialize(user, format: :digest)
    @user = user
    @format = format
    @chat = RubyLLM.chat(
      model: ApplicationConfig.llm_default_model,
      system: summarization_system_prompt,
      temperature: 0.3
    )
  end

  def call(contents)
    case @format
    when :digest
      create_digest(contents)
    when :highlights
      create_highlights(contents)
    when :summary
      create_summary(contents)
    end
  rescue RubyLLM::Error => e
    {
      success: false,
      error: "Ошибка суммаризации: #{e.message}",
      content: contents.map { |c| c[:content] }.join("\n\n")
    }
  end

  private

  def summarization_system_prompt
    <<~PROMPT
      Ты - эксперт по созданию новостных дайджестов.
      Создавай краткие, информативные саммари на русском языке.
      Сохраняй основные факты и выводы.
      Учитывай интересы пользователя: #{@user.interests.join(', ')}
    PROMPT
  end

  def create_digest(contents)
    prompt = build_digest_prompt(contents)
    response = @chat.ask(prompt)

    {
      success: true,
      content: response.content,
      format: :digest,
      items_count: contents.size
    }
  end

  def create_highlights(contents)
    prompt = build_highlights_prompt(contents)
    response = @chat.ask(prompt)

    {
      success: true,
      content: response.content,
      format: :highlights,
      items_count: contents.size
    }
  end

  def create_summary(contents)
    prompt = build_summary_prompt(contents)
    response = @chat.ask(prompt)

    {
      success: true,
      content: response.content,
      format: :summary,
      items_count: contents.size
    }
  end

  def build_digest_prompt(contents)
    formatted_content = contents.map.with_index do |item, index|
      "#{index + 1}. #{item[:title]}\n#{item[:content]}\nИсточник: #{item[:source]}"
    end.join("\n\n")

    <<~PROMPT
      Создай новостной дайджест из следующих материалов:

      #{formatted_content}

      Требования:
      - Объём: 2-3 абзаца
      - Сгруппируй по темам
      - Укажи ключевые события
      - Добавь выводы
    PROMPT
  end

  def build_highlights_prompt(contents)
    formatted_content = contents.map { |item| "• #{item[:title]}: #{item[:content][0..100]}..." }.join("\n")

    <<~PROMPT
      Выдели главные события и новости из списка:

      #{formatted_content}

      Формат: маркированный список с краткими описаниями
    PROMPT
  end

  def build_summary_prompt(contents)
    # Аналогично build_digest_prompt но для полного саммари
    build_digest_prompt(contents)
  end
end
```

### Тестирование сервиса суммаризации

```ruby
# test/services/content_summarizer_service_test.rb
require 'test_helper'

class ContentSummarizerServiceTest < ActiveSupport::TestCase
  setup do
    @user = telegram_users(:one)
    @user.update!(interests: ['технологии', 'бизнес'])
    setup_test_llm_context
  end

  teardown do
    cleanup_llm_mocks
  end

  test "creates digest from multiple contents" do
    contents = [
      {
        title: "Вышел новый процессор",
        content: "Intel представила новый процессор с улучшенной производительностью",
        source: "tech-news"
      },
      {
        title: "Рост рынка IT",
        content: "Рынок информационных технологий показывает рост на 15% в этом квартале",
        source: "business-daily"
      }
    ]

    expected_digest = <<~DIGEST
      📰 **Технологический дайджест**

      В этом квартале отмечены два значимых события в мире технологий и бизнеса.

      **Аппаратные инновации:** Intel представила новый процессор с улучшенной производительностью, что может повлиять на весь рынок вычислительной техники.

      **Рыночные тренды:** Сектор информационных технологий демонстрирует впечатляющий рост на 15%, что свидетельствует о восстановлении и инвестициях в цифровую трансформацию.
    DIGEST

    mock_response = mock_llm_response(expected_digest.strip)
    mock_chat = mock_llm_chat(anything => mock_response)

    @llm_context.stub(:chat, mock_chat) do
      service = ContentSummarizerService.new(@user, format: :digest)
      result = service.call(contents)

      assert result[:success]
      assert_equal :digest, result[:format]
      assert_equal 2, result[:items_count]
      assert_includes result[:content], 'Intel'
      assert_includes result[:content], '15%'
    end

    mock_chat.verify
  end

  test "creates highlights from contents" do
    contents = [
      { title: "Новость 1", content: "Содержание первой новости", source: "source1" },
      { title: "Новость 2", content: "Содержание второй новости", source: "source2" }
    ]

    expected_highlights = <<~HIGHLIGHTS
      🚀 **Главные события:**

      • **Вышел новый процессор** - Intel представила инновационное решение
      • **Рост IT рынка** - Сектор показывает впечатляющие темпы развития
    HIGHLIGHTS

    mock_response = mock_llm_response(expected_highlights.strip)
    mock_chat = mock_llm_chat(anything => mock_response)

    @llm_context.stub(:chat, mock_chat) do
      service = ContentSummarizerService.new(@user, format: :highlights)
      result = service.call(contents)

      assert result[:success]
      assert_equal :highlights, result[:format]
      assert_includes result[:content], 'Главные события'
    end

    mock_chat.verify
  end

  test "handles summarization errors" do
    contents = [{ title: "Новость", content: "Содержание", source: "source" }]

    mock_chat = Minitest::Mock.new
    mock_chat.expect(:ask, nil) do
      raise RubyLLM::Error.new("Token limit exceeded")
    end

    @llm_context.stub(:chat, mock_chat) do
      service = ContentSummarizerService.new(@user, format: :digest)
      result = service.call(contents)

      assert_not result[:success]
      assert_includes result[:error], 'Ошибка суммаризации'
      assert_includes result[:error], 'Token limit'
      assert_equal contents.map { |c| c[:content] }.join("\n\n"), result[:content]
    end
  end

  test "adapts summary based on user interests" do
    @user.update!(interests: ['спорт', 'здоровье'])

    contents = [
      {
        title: "Технологическая новость",
        content: "Новый гаджет на рынке",
        source: "tech-news"
      }
    ]

    # Проверяем что промпт содержит правильные интересы
    expected_prompt = /спорт.*здоровье/

    mock_chat = Minitest::Mock.new
    mock_chat.expect(:ask, mock_llm_response("Адаптированный саммари")) do |prompt|
      assert_match expected_prompt, prompt
    end

    @llm_context.stub(:chat, mock_chat) do
      service = ContentSummarizerService.new(@user)
      service.call(contents)
    end

    mock_chat.verify
  end
end
```

## 4. Тестирование классификации и эмбеддингов

### Сервис для поиска похожего контента

```ruby
# app/services/content_similarity_service.rb
class ContentSimilarityService
  include Callable

  def initialize
    @embedder = RubyLLM.embed(
      model: ApplicationConfig.llm_embedding_model || 'text-embedding-3-small'
    )
  end

  def find_similar(content, existing_contents, threshold: 0.8)
    content_embedding = @embedder.embed(content)

    similar_contents = []

    existing_contents.each do |existing|
      existing_embedding = @embedder.embed(existing[:content])
      similarity = cosine_similarity(content_embedding, existing_embedding)

      if similarity >= threshold
        similar_contents << {
          content: existing,
          similarity: similarity
        }
      end
    end

    similar_contents.sort_by { |c| -c[:similarity] }
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding error: #{e.message}"
    []
  end

  private

  def cosine_similarity(vec1, vec2)
    dot_product = vec1.zip(vec2).map { |a, b| a * b }.sum
    magnitude1 = Math.sqrt(vec1.map { |x| x * x }.sum)
    magnitude2 = Math.sqrt(vec2.map { |x| x * x }.sum)

    dot_product / (magnitude1 * magnitude2)
  end
end
```

### Тестирование сервиса сходства

```ruby
# test/services/content_similarity_service_test.rb
require 'test_helper'

class ContentSimilarityServiceTest < ActiveSupport::TestCase
  setup do
    setup_embedding_context
    @service = ContentSimilarityService.new
  end

  teardown do
    cleanup_llm_mocks
  end

  test "finds similar content with high similarity" do
    content = "Новое исследование в области искусственного интеллекта"
    existing_contents = [
      {
        title: "AI исследования",
        content: "Последние исследования в сфере ИИ показывают прорывные результаты",
        id: 1
      },
      {
        title: "Спортивные новости",
        content: "Футбольный матч закончился со счетом 2:1",
        id: 2
      }
    ]

    # Мокируем эмбеддинги
    content_embedding = [0.1, 0.2, 0.3, 0.4, 0.5]
    ai_embedding = [0.11, 0.19, 0.31, 0.39, 0.49]  # Высокая схожесть
    sport_embedding = [0.9, 0.1, 0.2, 0.3, 0.4]   # Низкая схожесть

    mock_content_embedding = mock_embedding_response(content_embedding)
    mock_ai_embedding = mock_embedding_response(ai_embedding)
    mock_sport_embedding = mock_embedding_response(sport_embedding)

    embedder = Minitest::Mock.new
    embedder.expect(:embed, mock_content_embedding, [content])
    embedder.expect(:embed, mock_ai_embedding, [existing_contents[0][:content]])
    embedder.expect(:embed, mock_sport_embedding, [existing_contents[1][:content]])

    @embedding_context.stub(:embed, embedder) do
      similar = @service.find_similar(content, existing_contents, threshold: 0.8)

      assert_equal 1, similar.length
      assert_equal existing_contents[0][:title], similar.first[:content][:title]
      assert similar.first[:similarity] > 0.8
    end

    embedder.verify
  end

  test "returns empty array when no similar content found" do
    content = "Технологическая новость"
    existing_contents = [
      { title: "Спорт", content: "Футбольный матч", id: 1 }
    ]

    # Мокируем эмбеддинги с низкой схожестью
    content_embedding = [0.1, 0.2, 0.3]
    sport_embedding = [0.9, 0.8, 0.7]

    embedder = Minitest::Mock.new
    embedder.expect(:embed, mock_embedding_response(content_embedding), [content])
    embedder.expect(:embed, mock_embedding_response(sport_embedding), [existing_contents[0][:content]])

    @embedding_context.stub(:embed, embedder) do
      similar = @service.find_similar(content, existing_contents, threshold: 0.8)
      assert_empty similar
    end

    embedder.verify
  end

  test "handles embedding errors gracefully" do
    content = "Тестовый контент"
    existing_contents = []

    embedder = Minitest::Mock.new
    embedder.expect(:embed, nil) do
      raise RubyLLM::Error.new("Embedding API unavailable")
    end

    @embedding_context.stub(:embed, embedder) do
      similar = @service.find_similar(content, existing_contents)
      assert_empty similar
    end

    embedder.verify
  end

  test "calculates cosine similarity correctly" do
    # Тест математической функции без моков
    vec1 = [1.0, 2.0, 3.0]
    vec2 = [1.0, 2.0, 3.0]

    # Одинаковые векторы должны иметь схожесть 1.0
    similarity = @service.send(:cosine_similarity, vec1, vec2)
    assert_in_delta 1.0, similarity, 0.001

    # Ортогональные векторы должны иметь схожесть 0.0
    vec3 = [1.0, 0.0, 0.0]
    vec4 = [0.0, 1.0, 0.0]

    similarity = @service.send(:cosine_similarity, vec3, vec4)
    assert_in_delta 0.0, similarity, 0.001
  end
end
```

## 5. Тестирование Tools для RubyLLM

### Tool для поиска релевантных каналов

```ruby
# app/tools/channel_recommendation_tool.rb
class ChannelRecommendationTool < RubyLLM::Tool
  description "Рекомендует похожие каналы на основе интересов пользователя"

  param :user_interests,
    type: :array,
    desc: "Список интересов пользователя"

  param :current_channels,
    type: :array,
    desc: "Текущие подписки пользователя",
    required: false

  def execute(user_interests:, current_channels: [])
    # Поиск релевантных каналов
    recommended_channels = find_relevant_channels(user_interests, current_channels)

    {
      recommendations: recommended_channels,
      count: recommended_channels.size
    }
  end

  private

  def find_relevant_channels(interests, current_channels)
    Channel.where.not(id: current_channels.map(&:id))
           .joins(:subscriptions)
           .where('channels.tags && ?', interests)
           .group('channels.id')
           .order('COUNT(subscriptions.id) DESC')
           .limit(5)
           .map { |channel| format_channel(channel) }
  end

  def format_channel(channel)
    {
      id: channel.id,
      username: channel.username,
      title: channel.title,
      subscribers: channel.subscriptions.active.count,
      description: channel.description
    }
  end
end
```

### Тестирование Tool

```ruby
# test/tools/channel_recommendation_tool_test.rb
require 'test_helper'

class ChannelRecommendationToolTest < ActiveSupport::TestCase
  setup do
    @user = telegram_users(:one)
    @tool = ChannelRecommendationTool.new
  end

  test "recommends channels based on user interests" do
    # Создаем тестовые каналы
    tech_channel = Channel.create!(
      telegram_id: 1001,
      username: 'tech_news',
      title: 'Tech News',
      tags: ['технологии', 'программирование'],
      description: 'Последние новости из мира технологий'
    )

    business_channel = Channel.create!(
      telegram_id: 1002,
      username: 'business_daily',
      title: 'Business Daily',
      tags: ['бизнес', 'экономика'],
      description: 'Бизнес новости и аналитика'
    )

    # Создаем подписки для имитации популярности
    5.times { Subscription.create!(telegram_user: @user, channel: tech_channel, active: true) }
    3.times { Subscription.create!(telegram_user: @user, channel: business_channel, active: true) }

    interests = ['технологии', 'программирование']
    current_channels = []

    result = @tool.execute(user_interests: interests, current_channels: current_channels)

    assert_equal 1, result[:count]
    assert_equal tech_channel.id, result[:recommendations].first[:id]
    assert_equal 'tech_news', result[:recommendations].first[:username]
    assert_equal 5, result[:recommendations].first[:subscribers]
  end

  test "excludes current channels from recommendations" do
    current_channel = Channel.create!(
      telegram_id: 1003,
      username: 'current_channel',
      title: 'Current Channel',
      tags: ['технологии'],
      description: 'Current subscription'
    )

    new_channel = Channel.create!(
      telegram_id: 1004,
      username: 'new_channel',
      title: 'New Channel',
      tags: ['технологии'],
      description: 'New recommendation'
    )

    interests = ['технологии']
    current_channels = [current_channel]

    result = @tool.execute(user_interests: interests, current_channels: current_channels)

    # Должен рекомендовать только new_channel
    assert_equal 1, result[:count]
    assert_equal new_channel.id, result[:recommendations].first[:id]
    assert_not_includes result[:recommendations].map { |r| r[:id] }, current_channel.id
  end

  test "handles empty interests gracefully" do
    result = @tool.execute(user_interests: [], current_channels: [])

    assert_equal 0, result[:count]
    assert_empty result[:recommendations]
  end

  test "limits recommendations to 5 channels" do
    # Создаем 10 каналов
    channels = []
    10.times do |i|
      channels << Channel.create!(
        telegram_id: 2000 + i,
        username: "channel_#{i}",
        title: "Channel #{i}",
        tags: ['технологии'],
        description: "Description #{i}"
      )
    end

    interests = ['технологии']
    result = @tool.execute(user_interests: interests, current_channels: [])

    # Должно быть не более 5 рекомендаций
    assert result[:count] <= 5
    assert_equal result[:count], result[:recommendations].size
  end
end
```

## 6. Интеграционные тесты

### Тест полного workflow обработки контента

```ruby
# test/integrations/content_processing_integration_test.rb
require 'test_helper'

class ContentProcessingIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = telegram_users(:one)
    @user.update!(interests: ['технологии', 'бизнес'])
    setup_test_llm_context
  end

  teardown do
    cleanup_llm_mocks
  end

  test "complete content processing workflow" do
    # Создаем входящие данные
    contents = [
      {
        title: "Вышла новая версия Ruby",
        content: "Ruby 3.2.0 released с улучшенной производительностью и новыми возможностями",
        source: "ruby_news",
        channel: channels(:one)
      },
      {
        title: "Инвестиции в стартапы",
        content: "Венчурные фонды вложили $100м в технологические стартапы",
        source: "tech_crunch",
        channel: channels(:two)
      }
    ]

    # Мокируем все LLM вызовы
    filter_responses = {}
    summary_response = mock_llm_response(
      "📰 **Дайджест технологических и бизнес новостей**\n\nRuby и инвестиции в стартапы..."
    )

    contents.each do |content|
      filter_responses[content[:content]] = mock_llm_response(
        '{"relevant": true, "reason": "Соответствует интересам", "categories": ["технологии"]}'
      )
    end

    mock_filter_chat = mock_llm_chat(filter_responses)
    mock_summary_chat = mock_llm_chat(anything => summary_response)

    @llm_context.stub(:chat, ->(*) { mock_filter_chat }) do
      # Этап 1: Фильтрация контента
      filtered_contents = contents.select do |content|
        service = ContentFilterService.new(@user)
        result = service.call(content[:content])
        result[:relevant]
      end

      assert_equal 2, filtered_contents.length

      # Этап 2: Создание дайджеста
      @llm_context.stub(:chat, ->(*) { mock_summary_chat }) do
        summarizer = ContentSummarizerService.new(@user, format: :digest)
        digest = summarizer.call(filtered_contents)

        assert digest[:success]
        assert_includes digest[:content], 'Ruby'
        assert_includes digest[:content], 'стартапы'
      end
    end
  end

  test "content deduplication workflow" do
    # Создаем похожий контент
    original_content = {
      title: "Apple выпустила iPhone 15",
      content: "Компания Apple представила новый смартфон iPhone 15 с улучшенной камерой",
      source: "tech_news",
      channel: channels(:one)
    }

    duplicate_content = {
      title: "Новый iPhone 15 от Apple",
      content: "Apple анонсировала смартфон iPhone 15 с усовершенствованной камерой",
      source: "another_source",
      channel: channels(:two)
    }

    # Мокируем эмбеддинги для поиска дубликатов
    embedding1 = [0.1, 0.2, 0.3, 0.4, 0.5]
    embedding2 = [0.11, 0.19, 0.31, 0.39, 0.49]  # Высокая схожесть

    embedder = Minitest::Mock.new
    embedder.expect(:embed, mock_embedding_response(embedding1), [original_content[:content]])
    embedder.expect(:embed, mock_embedding_response(embedding2), [duplicate_content[:content]])

    @embedding_context.stub(:embed, embedder) do
      similarity_service = ContentSimilarityService.new
      duplicates = similarity_service.find_similar(
        duplicate_content[:content],
        [original_content],
        threshold: 0.8
      )

      assert_equal 1, duplicates.length
      assert duplicates.first[:similarity] > 0.8
    end

    embedder.verify
  end
end
```

## 7. Best Practices для мокирования LLM

### 1. Используйте изолированные контексты

```ruby
# Плохо - глобальная конфигурация
RubyLLM.configure do |config|
  config.openai_api_key = 'test-key'
end

# Хорошо - изолированный контекст
@llm_context = RubyLLM.context do |config|
  config.openai_api_key = 'test-key'
end
```

### 2. Мокируйте все внешние зависимости

```ruby
# Всегда мокируйте API вызовы
mock_chat = Minitest::Mock.new
mock_response = mock_llm_response("Expected response")
mock_chat.expect(:ask, mock_response, ["input"])

@llm_context.stub(:chat, mock_chat) do
  # Тестируемый код
end
```

### 3. Проверяйте параметры вызовов

```ruby
mock_chat.expect(:ask, response) do |prompt|
  assert_includes prompt, 'Ожидаемый текст в промпте'
  assert_includes prompt, user_specific_content
  true
end
```

### 4. Тестируйте обработку ошибок

```ruby
mock_chat.expect(:ask, nil) do
  raise RubyLLM::Error.new("API Error")
end

# Проверяем что ошибка обрабатывается корректно
```

### 5. Используйте реальные данные для промптов

```ruby
def create_realistic_test_content
  {
    title: "Вышел новый фреймворк для веб-разработки",
    content: "Команда разработчиков представила фреймворк FastAPI 2.0 с улучшенной производительностью и поддержкой WebSockets",
    source: "dev_to",
    tags: ["программирование", "web", "api"]
  }
end
```

Этот подход обеспечивает надежное тестирование LLM-функциональности в проекте NoFluff без реальных API вызовов и поддерживает чистоту тестового окружения.