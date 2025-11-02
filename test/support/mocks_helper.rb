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
end
