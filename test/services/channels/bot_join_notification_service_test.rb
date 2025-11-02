require 'test_helper'

class Channels::BotJoinNotificationServiceTest < ActiveSupport::TestCase
  def setup
    # Используем существующего админа из фикстур
    @admin_user = telegram_users(:admin_user)
    @channel = channels(:one)
    @channel.update!(bot_join_at: Time.current) # Set timestamp for I18n
  end

  test 'should send success notifications to all admins' do
    # Создаем второго администратора
    admin2 = TelegramUser.create!(
      username: 'admin2',
      telegram_id: 999999,
      first_name: 'Admin',
      last_name: 'User',
      is_admin: true
    )

    # Мокаем бота
    send_message_calls = []

    # Создаем mock API
    mock_api = Object.new
    mock_api.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    # Создаем mock bot
    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      service = Channels::BotJoinNotificationService.new
      service.notify_success(@channel)
    end

    # Проверяем вызовы
    assert_equal 2, send_message_calls.length
    assert_includes send_message_calls.map { |c| c[:chat_id] }, @admin_user.telegram_id
    assert_includes send_message_calls.map { |c| c[:chat_id] }, admin2.telegram_id
    send_message_calls.each do |call|
      assert_includes call[:text], 'Test Channel One'
      assert_equal 'Markdown', call[:parse_mode]
    end
  end

  test 'should send failure notifications to all admins' do
    error_message = 'Channel not found'

    # Мокаем бота
    send_message_calls = []

    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      service = Channels::BotJoinNotificationService.new
      service.notify_failure(@channel, error_message)
    end

    # Проверяем вызовы
    assert_equal 1, send_message_calls.length
    assert_equal @admin_user.telegram_id, send_message_calls.first[:chat_id]
    assert_includes send_message_calls.first[:text], 'Test Channel One'
    assert_includes send_message_calls.first[:text], error_message
    assert_equal 'Markdown', send_message_calls.first[:parse_mode]
  end

  test 'should not send notifications when no admins exist' do
    # Убираем права администратора у всех
    TelegramUser.where(is_admin: true).update_all(is_admin: false)

    # Мокаем бота
    send_message_calls = []

    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      service = Channels::BotJoinNotificationService.new
      service.notify_success(@channel)
      service.notify_failure(@channel, 'Test error')
    end

    # Проверяем что уведомления не были отправлены
    assert_empty send_message_calls
  end

  test 'should handle Telegram API errors gracefully' do
    # Мокаем бота который вызывает ошибку
    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      raise Telegram::Bot::Error.new('Invalid token')
    end

    # Не должно вызывать исключение
    assert_nothing_raised do
      Telegram.stub(:bots, { default: mock_bot }) do
        service = Channels::BotJoinNotificationService.new
        service.notify_success(@channel)
      end
    end
  end

  test 'should log notification sending' do
    # Мокаем бота
    send_message_calls = []

    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      service = Channels::BotJoinNotificationService.new
      assert_logs('Sent bot join success notifications') do
        service.notify_success(@channel)
      end
    end
  end

  test 'should include channel details in success message' do
    @channel.update!(
      title: 'Test Channel Title',
      username: 'testchannel',
      telegram_id: -1001234567890,
      subscribers_count: 5000,
      bot_join_at: 1.hour.ago
    )

    # Мокаем бота
    send_message_calls = []

    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      service = Channels::BotJoinNotificationService.new
      service.notify_success(@channel)
    end

    # Проверяем детали сообщения
    assert_equal 1, send_message_calls.length
    message = send_message_calls.first[:text]
    assert_includes message, 'Test Channel Title'
    assert_includes message, '@testchannel'
    assert_includes message, '-1001234567890'
    assert_includes message, '5000'
    assert_equal 'Markdown', send_message_calls.first[:parse_mode]
  end

  test 'should include error details in failure message' do
    error = 'Forbidden: bot was kicked from the channel'

    # Мокаем бота
    send_message_calls = []

    mock_bot = Object.new
    mock_bot.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      service = Channels::BotJoinNotificationService.new
      service.notify_failure(@channel, error)
    end

    # Проверяем детали сообщения
    assert_equal 1, send_message_calls.length
    message = send_message_calls.first[:text]
    assert_includes message, 'Test Channel'
    assert_includes message, error
    assert_equal 'Markdown', send_message_calls.first[:parse_mode]
  end

  private

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
