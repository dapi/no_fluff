# frozen_string_literal: true

# MocksHelper - стандартизация мокирования для тестов
# Предоставляет унифицированные методы для создания моков
module MocksHelper
  # Test token for mocking (clearly not a real token)
  MOCK_TEST_TOKEN = 'mock_test_bot_token_xyz123'

  # Мокирование LimitChecker
  # @param allowed [Boolean] разрешена ли подписка
  # @param user_id [Integer] ID пользователя
  # @return [Mocha::Mock] мок объекта
  def mock_limit_checker(allowed: true, user_id: 12345)
    checker = mock('limit_checker')
    checker.stubs(:user_id).returns(user_id)
    checker.stubs(:allowed?).returns(allowed)
    checker.stubs(:check!).returns(allowed)
    checker.stubs(:remaining_slots).returns(allowed ? 5 : 0)
    checker.stubs(:limit_reached?).returns(!allowed)
    checker
  end

  # Мокирование Telegram API клиента
  # @param bot_token [String] токен бота
  # @return [Mocha::Mock] мок клиента
  def mock_telegram_client(bot_token = MOCK_TEST_TOKEN)
    client = mock('telegram_client')
    client.stubs(:token).returns(bot_token)
    client.stubs(:username).returns('test_bot')
    client.stubs(:get_me).returns(
      'id' => 54321,
      'is_bot' => true,
      'first_name' => 'TestBot',
      'username' => 'test_bot'
    )
    client
  end

  # Мокирование отправки сообщения
  # @param text [String] текст сообщения
  # @param chat_id [Integer] ID чата
  # @param reply_markup [Hash] клавиатура
  # @return [Hash] ответ API
  def mock_send_message(text:, chat_id: 12345, reply_markup: nil)
    response = {
      'message_id' => rand(1000..9999),
      'from' => {
        'id' => 54321,
        'is_bot' => true,
        'first_name' => 'TestBot',
        'username' => 'test_bot'
      },
      'chat' => {
        'id' => chat_id,
        'first_name' => 'Test',
        'username' => 'test_user',
        'type' => 'private'
      },
      'date' => Time.now.to_i,
      'text' => text
    }

    response['reply_markup'] = reply_markup if reply_markup
    response
  end

  # Мокирование ответа на callback query
  # @param text [String] текст ответа
  # @param show_alert [Boolean] показывать ли алерт
  # @return [Hash] ответ API
  def mock_answer_callback_query(text: 'Done', show_alert: false)
    {
      'callback_query_id' => "callback_#{rand(1000..9999)}",
      'text' => text,
      'show_alert' => show_alert
    }
  end

  # Мокирование ApplicationConfig
  # @param overrides [Hash] параметры для переопределения
  # @return [Mocha::Mock] мок конфигурации
  def mock_application_config(overrides = {})
    defaults = {
      'telegram' => {
        'bot' => {
          'token' => 'test_token',
          'username' => 'test_bot'
        }
      },
      'limits' => {
        'free_channels' => 3,
        'premium_channels' => 50
      },
      'features' => {
        'premium_enabled' => true,
        'debug_mode' => false
      }
    }

    config = mock('application_config')
    config.stubs(:[]).returns(defaults.merge(overrides))
    config.stubs(:dig).returns(nil)
    config.stubs(:key?).returns(true)
    config
  end

  # Мокирование HTTP запросов
  # @param url [String] URL запроса
  # @param response [Hash] ответ
  # @param status [Integer] статус код
  def mock_http_request(url, response = {}, status = 200)
    response_body = response.to_json
    headers = { 'Content-Type' => 'application/json' }

    stub_request(:get, url)
      .to_return(
        status: status,
        body: response_body,
        headers: headers
      )
  end

  # Мокирование ошибок Telegram API
  # @param error_code [Integer] код ошибки
  # @param description [String] описание ошибки
  # @return [Telegram::Bot::Exceptions::Base] исключение
  def mock_telegram_api_error(error_code = 400, description = 'Bad Request')
    case error_code
    when 400
      Telegram::Bot::Exceptions::BadRequest.new(description)
    when 401
      Telegram::Bot::Exceptions::Unauthorized.new(description)
    when 403
      Telegram::Bot::Exceptions::Forbidden.new(description)
    when 404
      Telegram::Bot::Exceptions::NotFound.new(description)
    when 429
      Telegram::Bot::Exceptions::TooManyRequests.new(description)
    else
      Telegram::Bot::Exceptions::Base.new(description)
    end
  end

  # Мокирование файла для отправки
  # @param filename [String] имя файла
  # @param content [String] содержимое
  # @return [File] файловый объект
  def mock_file_upload(filename, content = 'test content')
    file = Tempfile.new([ filename, '.txt' ])
    file.write(content)
    file.rewind
    file
  end

  # Мокирование времени
  # @param time [Time] время для мока
  def mock_time(time = Time.new(2024, 1, 1, 12, 0, 0))
    Time.stubs(:now).returns(time)
  end

  # Мокирование генерации случайных чисел
  # @param numbers [Array] последовательность чисел
  def mock_random_numbers(numbers)
    numbers.each do |num|
      rand.stubs(:rand).returns(num)
    end
  end

  # Мокирование кеширования Rails
  def mock_rails_cache
    cache = mock('rails_cache')
    cache.stubs(:read).returns(nil)
    cache.stubs(:write).returns(true)
    cache.stubs(:fetch).yields.returns('cached_value')
    cache.stubs(:delete).returns(true)
    cache.stubs(:exist?).returns(false)
    cache.stubs(:clear).returns(true)
    cache
  end

  # Мокирование Redis для сессий
  def mock_redis_store
    redis = mock('redis')
    redis.stubs(:get).returns(nil)
    redis.stubs(:set).returns('OK')
    redis.stubs(:setex).returns('OK')
    redis.stubs(:del).returns(1)
    redis.stubs(:exists?).returns(false)
    redis.stubs(:expire).returns(1)
    redis
  end

  # Мокирование фоновых задач (Jobs)
  def mock_job_enqueue(job_class)
    job_class.any_instance.stubs(:perform).returns(true)
    job_class.stubs(:perform_later).returns(mock('active_job'))
  end

  # Мокирование логгера
  def mock_logger
    logger = mock('logger')
    logger.stubs(:info).returns(true)
    logger.stubs(:debug).returns(true)
    logger.stubs(:warn).returns(true)
    logger.stubs(:error).returns(true)
    logger.stubs(:fatal).returns(true)
    logger
  end

  # Сброс всех моков после теста
  def reset_all_mocks
    # Mocha автоматически очищает моки после каждого теста
    # Этот метод оставлен для совместимости
  end

  # Мокирование LLM модели (Ruby-LLM)
  # @param response_text [String] текст ответа модели
  # @param model_name [String] название модели
  # @return [Mocha::Mock] мок LLM модели
  def mock_llm_model(response_text = 'Test response', model_name = 'gpt-4')
    model = mock('llm_model')
    model.stubs(:chat).returns(response_text)
    model.stubs(:model_id).returns(model_name)
    model.stubs(:name).returns(model_name)
    model.stubs(:provider).returns('openai')
    model
  end

  # Мокирование вебхука Telegram
  # @param message_text [String] текст сообщения
  # @param chat_id [Integer] ID чата
  # @param user_id [Integer] ID пользователя
  # @return [Hash] данные вебхука
  def mock_telegram_webhook(message_text = 'test', chat_id = 12345, user_id = 67890)
    {
      'update_id' => rand(1000000..9999999),
      'message' => {
        'message_id' => rand(1000..9999),
        'from' => {
          'id' => user_id,
          'is_bot' => false,
          'first_name' => 'Test',
          'username' => 'test_user',
          'language_code' => 'en'
        },
        'chat' => {
          'id' => chat_id,
          'first_name' => 'Test',
          'username' => 'test_user',
          'type' => 'private'
        },
        'date' => Time.now.to_i,
        'text' => message_text
      }
    }
  end

  # Мокирование канала Telegram
  # @param overrides [Hash] параметры для переопределения
  # @return [Hash] данные канала
  def mock_telegram_channel(overrides = {})
    defaults = {
      'id' => -1001234567890,
      'username' => 'testchannel',
      'title' => 'Test Channel',
      'type' => 'channel',
      'description' => 'Test channel description'
    }
    defaults.merge(overrides)
  end

  # Мокирование ошибки сети
  # @param message [String] сообщение об ошибке
  # @return [Net::TimeoutError] исключение
  def mock_network_error(message = 'Network timeout')
    Net::TimeoutError.new(message)
  end

  # Мокирование ответа API с пагинацией
  # @param items [Array] элементы для пагинации
  # @param per_page [Integer] элементов на странице
  # @return [Hash] ответ API с пагинацией
  def mock_paginated_response(items, per_page = 10)
    total_pages = (items.length.to_f / per_page).ceil
    {
      'data' => items.first(per_page),
      'pagination' => {
        'current_page' => 1,
        'total_pages' => total_pages,
        'total_count' => items.length,
        'per_page' => per_page
      }
    }
  end

  # Мокирование валидации модели
  # @param model [ActiveRecord::Base] модель для валидации
  # @param errors [Hash] ошибки валидации
  def mock_validation_errors(model, errors)
    errors.each do |field, messages|
      messages.each do |message|
        model.errors.add(field, message)
      end
    end
  end

  # Создание тестового набора данных для бенчмарков
  # @param count [Integer] количество записей
  # @param factory [Symbol] фабрика для создания
  # @return [Array] массив тестовых данных
  def create_test_dataset(count, factory = :telegram_user)
    Array.new(count) { |i| create(factory, "test_#{i}") }
  end

  # Создание набора моков для базового теста
  # @param overrides [Hash] параметры для переопределения
  # @return [Hash] хеш с моками
  def setup_basic_mocks(overrides = {})
    {
      limit_checker: mock_limit_checker(overrides[:limit_checker] || {}),
      telegram_client: mock_telegram_client(overrides[:telegram_client]),
      application_config: mock_application_config(overrides[:application_config]),
      logger: mock_logger
    }
  end

  # Установка общих моков для Telegram тестов
  def setup_telegram_mocks
    # Мокирование бота
    Telegram.bot.stubs(:token).returns('test_token')
    Telegram.bot.stubs(:username).returns('test_bot')
    Telegram.bot.stubs(:get_me).returns(
      'id' => 54321,
      'is_bot' => true,
      'first_name' => 'TestBot',
      'username' => 'test_bot'
    )

    # Мокирование отправки сообщений
    Telegram.bot.stubs(:send_message).returns(mock_send_message(text: 'test'))
    Telegram.bot.stubs(:answer_callback_query).returns(mock_answer_callback_query)

    # Мокирование конфигурации
    ApplicationConfig.stubs(:[]).returns({})
  end

  # Создание мока для бота с отслеживанием вызовов send_message
  # @return [Array, Object] массив для отслеживания вызовов и мок бота
  def mock_bot_with_message_tracking
    send_message_calls = []

    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    [ send_message_calls, mock_bot ]
  end

  # Создание мока для бота с ошибкой при отправке
  # @param error_message [String] сообщение об ошибке
  # @return [Object] мок бота
  def mock_bot_with_error(error_message = 'Invalid token')
    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      raise Telegram::Bot::Error.new(error_message)
    end
    mock_bot
  end

  # Установка мока для Telegram.bots
  # @param mock_bot [Object] мок бота для установки
  def setup_telegram_bots_mock(mock_bot)
    Telegram.stub(:bots, { default: mock_bot }) do
      yield
    end
  end

  # Очистка системных настроек для тестов
  def cleanup_system_settings(keys = [ 'debug_mode' ])
    keys = [ keys ] unless keys.is_a?(Array)
    SystemSetting.where(key: keys).delete_all
  end

  # Установка системной настройки для тестов
  # @param key [String] ключ настройки
  # @param value [String, Boolean, Integer] значение
  # @param description [String] описание настройки
  def set_system_setting(key, value, description = nil)
    SystemSetting.set(key, value, description)
  end

  # Создание тестовых объектов для отладки
  # @param overrides [Hash] параметры для переопределения
  # @return [OpenStruct] тестовый объект
  def create_test_channel(overrides = {})
    defaults = {
      id: 456,
      username: 'testchannel',
      title: 'Test Channel'
    }
    OpenStruct.new(defaults.merge(overrides))
  end

  # Создание тестового сообщения
  # @param overrides [Hash] параметры для переопределения
  # @return [OpenStruct] тестовое сообщение
  def create_test_message(overrides = {})
    defaults = {
      id: 123,
      content: 'test message',
      text: 'test message'
    }
    OpenStruct.new(defaults.merge(overrides))
  end

  # Создание тестовой ошибки
  # @param message [String] сообщение об ошибке
  # @param error_class [Class] класс ошибки
  # @return [Exception] экземпляр ошибки
  def create_test_error(message = 'Test error', error_class = StandardError)
    error_class.new(message)
  end

  # Проверка количества админов в системе
  # @param expected_count [Integer] ожидаемое количество
  def assert_admin_count(expected_count)
    assert_equal expected_count, TelegramUser.where(is_admin: true).count
  end

  # Очистка тестовых админов
  def cleanup_test_admins
    TelegramUser.where(is_admin: true).where.not(id: telegram_users(:admin_user)&.id).destroy_all
  end
end
