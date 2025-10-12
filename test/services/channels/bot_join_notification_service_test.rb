require 'test_helper'

class Channels::BotJoinNotificationServiceTest < ActiveSupport::TestCase
  def setup
    @service = Channels::BotJoinNotificationService.new
    @admin_user = telegram_users(:one)
    @admin_user.update!(is_admin: true)
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
    mock_bot = Minitest::Mock.new
    success_message = I18n.t(
      'telegram_bot.bot_join.success',
      channel_title: @channel.title,
      channel_username: @channel.username,
      channel_id: @channel.telegram_id,
      subscribers_count: @channel.subscribers_count || 0,
      joined_at: I18n.l(Time.current, format: :short)
    )

    # Ожидаем два вызова для двух администраторов
    mock_bot.expect(:send_message, nil, [ { chat_id: @admin_user.telegram_id, text: success_message, parse_mode: 'Markdown' } ])
    mock_bot.expect(:send_message, nil, [ { chat_id: admin2.telegram_id, text: success_message, parse_mode: 'Markdown' } ])

    Telegram.stub(:bots, { default: mock_bot }) do
      @service.notify_success(@channel)
    end

    mock_bot.verify
  end

  test 'should send failure notifications to all admins' do
    error_message = 'Channel not found'
    failure_message = I18n.t(
      'telegram_bot.bot_join.failure',
      channel_title: @channel.title,
      channel_username: @channel.username,
      channel_id: @channel.telegram_id,
      error_message: error_message,
      failed_at: I18n.l(Time.current, format: :short)
    )

    mock_bot = Minitest::Mock.new
    mock_bot.expect(:send_message, nil, [ { chat_id: @admin_user.telegram_id, text: failure_message, parse_mode: 'Markdown' } ])

    Telegram.stub(:bots, { default: mock_bot }) do
      @service.notify_failure(@channel, error_message)
    end

    mock_bot.verify
  end

  test 'should not send notifications when no admins exist' do
    # Убираем права администратора у всех
    TelegramUser.where(is_admin: true).update_all(is_admin: false)

    mock_bot = Minitest::Mock.new
    # Не ожидаем никаких вызовов
    mock_bot.expect(:send_message, nil, []) { raise 'Should not be called' }

    Telegram.stub(:bots, { default: mock_bot }) do
      @service.notify_success(@channel)
      @service.notify_failure(@channel, 'Test error')
    end
  end

  test 'should handle Telegram API errors gracefully' do
    mock_bot = Minitest::Mock.new
    success_message = anything

    # Симулируем ошибку API
    mock_bot.expect(:send_message, nil) do
      raise Telegram::Bot::Error.new('Invalid token')
    end

    # Не должно вызывать исключение
    assert_nothing_raised do
      Telegram.stub(:bots, { default: mock_bot }) do
        @service.notify_success(@channel)
      end
    end

    mock_bot.verify
  end

  test 'should log notification sending' do
    mock_bot = Minitest::Mock.new
    mock_bot.expect(:send_message, nil, [ anything ])

    Telegram.stub(:bots, { default: mock_bot }) do
      assert_logs('Sent bot join success notifications') do
        @service.notify_success(@channel)
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

    mock_bot = Minitest::Mock.new
    mock_bot.expect(:send_message, nil) do |args|
      message = args[0][:text]
      assert_includes message, 'Test Channel Title'
      assert_includes message, '@testchannel'
      assert_includes message, '-1001234567890'
      assert_includes message, '5000'
      true # Return true to satisfy the mock expectation
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      @service.notify_success(@channel)
    end

    mock_bot.verify
  end

  test 'should include error details in failure message' do
    error = 'Forbidden: bot was kicked from the channel'

    mock_bot = Minitest::Mock.new
    mock_bot.expect(:send_message, nil) do |args|
      message = args[0][:text]
      assert_includes message, 'Test Channel'
      assert_includes message, error
      true # Return true to satisfy the mock expectation
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      @service.notify_failure(@channel, error)
    end

    mock_bot.verify
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
