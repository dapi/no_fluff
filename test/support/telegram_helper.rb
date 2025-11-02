# frozen_string_literal: true

# TelegramHelper - базовые helper методы для Telegram тестов
# Предоставляет унифицированные методы создания тестовых данных для Telegram
module TelegramHelper
  # Создание тестового update для сообщения
  # @param text [String] текст сообщения
  # @param user_id [Integer] ID пользователя
  # @param chat_id [Integer] ID чата
  # @return [Hash] Telegram update хеш
  def create_message_update(text:, user_id: 12345, chat_id: 12345)
    {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
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
        'text' => text
      }
    }
  end

  # Создание тестового update для callback query
  # @param data [String] callback_data
  # @param user_id [Integer] ID пользователя
  # @param chat_id [Integer] ID чата
  # @param message_id [Integer] ID сообщения
  # @return [Hash] Telegram update хеш
  def create_callback_update(data:, user_id: 12345, chat_id: 12345, message_id: 1)
    {
      'update_id' => 1,
      'callback_query' => {
        'id' => 'callback_123',
        'from' => {
          'id' => user_id,
          'is_bot' => false,
          'first_name' => 'Test',
          'username' => 'test_user',
          'language_code' => 'en'
        },
        'message' => {
          'message_id' => message_id,
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
          'text' => 'Previous message'
        },
        'chat_instance' => '123456789',
        'data' => data
      }
    }
  end

  # Создание тестового update для команды
  # @param command [String] команда (например, '/start')
  # @param args [Array] аргументы команды
  # @param user_id [Integer] ID пользователя
  # @return [Hash] Telegram update хеш
  def create_command_update(command:, args: [], user_id: 12345)
    text = args.empty? ? command : "#{command} #{args.join(' ')}"
    create_message_update(text: text, user_id: user_id)
  end

  # Создание тестового update для пользователя (расширенная версия)
  # @param user_id [Integer] ID пользователя
  # @param username [String] юзернейм пользователя
  # @param command [String] команда или текст сообщения
  # @param first_name [String] имя пользователя
  # @param last_name [String] фамилия пользователя
  # @param language_code [String] языковой код
  # @param is_premium [Boolean] является ли пользователем premium
  # @return [Hash] Telegram update хеш
  def create_user_update(user_id: 123456, username: 'testuser', command: '/start',
                        first_name: 'Test', last_name: 'User', language_code: 'ru',
                        is_premium: false)
    {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
        'from' => {
          'id' => user_id,
          'username' => username,
          'first_name' => first_name,
          'last_name' => last_name,
          'language_code' => language_code,
          'is_premium' => is_premium
        },
        'chat' => { 'id' => user_id, 'type' => 'private' },
        'text' => command
      }
    }
  end

  # Извлечение текста сообщения из update
  # @param update [Hash] Telegram update
  # @return [String, nil] текст сообщения
  def extract_message_content(update)
    update.dig('message', 'text') || update.dig('edited_message', 'text')
  end

  # Извлечение callback_data из update
  # @param update [Hash] Telegram update
  # @return [String, nil] callback_data
  def extract_callback_data(update)
    update.dig('callback_query', 'data')
  end

  # Извлечение ID пользователя из update
  # @param update [Hash] Telegram update
  # @return [Integer, nil] ID пользователя
  def extract_user_id(update)
    update.dig('message', 'from', 'id') ||
    update.dig('callback_query', 'from', 'id') ||
    update.dig('edited_message', 'from', 'id')
  end

  # Извлечение ID чата из update
  # @param update [Hash] Telegram update
  # @return [Integer, nil] ID чата
  def extract_chat_id(update)
    update.dig('message', 'chat', 'id') ||
    update.dig('callback_query', 'message', 'chat', 'id') ||
    update.dig('edited_message', 'chat', 'id')
  end

  # Создание тестового пользователя Telegram
  # @param overrides [Hash] параметры для переопределения
  # @return [TelegramUser] пользователь
  def create_telegram_user(overrides = {})
    defaults = {
      id: 12345,
      username: 'test_user',
      first_name: 'Test',
      last_name: 'User',
      is_premium: false,
      is_bot: false,
      language_code: 'en'
    }

    TelegramUser.create!(defaults.merge(overrides))
  end

  # Создание premium пользователя
  # @param overrides [Hash] параметры для переопределения
  # @return [TelegramUser] premium пользователь
  def create_premium_user(overrides = {})
    create_telegram_user(overrides.merge(is_premium: true))
  end

  # Создание admin пользователя
  # @param overrides [Hash] параметры для переопределения
  # @return [TelegramUser] admin пользователь
  def create_admin_user(overrides = {})
    create_telegram_user(overrides.merge(is_admin: true))
  end

  # Создание админа с указанными параметрами
  # @param username [String] юзернейм
  # @param telegram_id [Integer] ID в Telegram
  # @param first_name [String] имя
  # @param last_name [String] фамилия
  # @param overrides [Hash] дополнительные параметры
  # @return [TelegramUser] admin пользователь
  def create_admin_with_params(username:, telegram_id:, first_name: 'Admin', last_name: 'User', overrides: {})
    create_admin_user(
      username: username,
      telegram_id: telegram_id,
      first_name: first_name,
      last_name: last_name,
      **overrides
    )
  end

  # Проверка наличия кнопки в клавиатуре
  # @param reply_markup [Hash] клавиатура
  # @param button_text [String] текст кнопки
  # @return [Boolean] наличие кнопки
  def keyboard_has_button?(reply_markup, button_text)
    return false unless reply_markup&.dig('inline_keyboard')

    reply_markup['inline_keyboard'].any? do |row|
      row.any? { |button| button['text'] == button_text }
    end
  end

  # Извлечение текста всех кнопок из клавиатуры
  # @param reply_markup [Hash] клавиатура
  # @return [Array<String>] массив текстов кнопок
  def extract_button_texts(reply_markup)
    return [] unless reply_markup&.dig('inline_keyboard')

    reply_markup['inline_keyboard'].flat_map do |row|
      row.map { |button| button['text'] }
    end
  end

  # Ожидание отправки сообщения в тестах
  # @param expected_text [String, Regexp] ожидаемый текст
  # @param from_bot [Telegram::Bot::Client] бот для проверки
  def expect_message_sent(expected_text, from_bot = Telegram.bot)
    sent_messages = from_bot.requests.select { |req| req[:method] == :sendMessage }

    sent_messages.any? do |message|
      text = message.dig(:args, :text)
      expected_text.is_a?(Regexp) ? text&.match?(expected_text) : text == expected_text
    end
  end

  # Ожидание ответа на callback query
  # @param expected_text [String, Regexp] ожидаемый текст
  # @param from_bot [Telegram::Bot::Client] бот для проверки
  def expect_callback_answered(expected_text, from_bot = Telegram.bot)
    callback_answers = from_bot.requests.select { |req| req[:method] == :answerCallbackQuery }

    callback_answers.any? do |answer|
      text = answer.dig(:args, :text)
      expected_text.is_a?(Regexp) ? text&.match?(expected_text) : text == expected_text
    end
  end

  # Отправка webhook update в контроллер
  # @param update [Hash] Telegram update
  # @param headers [Hash] дополнительные заголовки
  def send_webhook_update(update, headers = {})
    default_headers = { 'Content-Type' => 'application/json' }
    final_headers = default_headers.merge(headers)

    post telegram_webhook_path, params: update.to_json, headers: final_headers
  end

  # Расширенное извлечение контента из сообщений запросов
  # @param requests [Array] массив запросов к боту
  # @return [Hash, nil] параметры сообщения
  def extract_message_content_from_requests(requests)
    message_requests = requests.select { |method, _| method == :sendMessage }
    return nil if message_requests.empty?

    method, params = message_requests.first
    params.is_a?(Array) ? params.first : params
  end

  # Извлечение контента из отредактированных сообщений
  # @param requests [Array] массив запросов к боту
  # @return [Hash, nil] параметры отредактированного сообщения
  def extract_edited_message_content(requests)
    edit_requests = requests.select { |method, _| method == :editMessageText }
    return nil if edit_requests.empty?

    method, params = edit_requests.first
    params.is_a?(Array) ? params.first : params
  end

  # Сброс всех запросов бота
  # @param bot [Telegram::Bot::Client] бот для сброса
  def reset_bot_requests(bot = Telegram.bot)
    bot.reset if bot.respond_to?(:reset)
  end

  # Проверка логирования в тестах
  # @param expected_message [String] ожидаемое сообщение в логах
  def assert_logs(expected_message)
    log_output = StringIO.new
    logger = Logger.new(log_output)

    original_logger = Rails.logger
    Rails.logger = logger

    yield

    log_content = log_output.string
    assert_includes log_content, expected_message
  ensure
    Rails.logger = original_logger
  end
end
