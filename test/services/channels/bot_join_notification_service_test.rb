require 'test_helper'

class Channels::BotJoinNotificationServiceTest < ActiveSupport::TestCase
  include TelegramHelper
  include MocksHelper

  def setup
    # Используем существующего админа из фикстур
    @admin_user = telegram_users(:admin_user)
    @channel = channels(:one)
    @channel.update!(bot_join_at: Time.current) # Set timestamp for I18n
  end

  test 'should send success notifications to all admins' do
    # Создаем второго администратора
    admin2 = create_admin_with_params(
      username: 'admin2',
      telegram_id: 999999
    )

    # Используем helper для создания мока бота с отслеживанием
    send_message_calls, mock_bot = mock_bot_with_message_tracking

    setup_telegram_bots_mock(mock_bot) do
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

    # Используем helper для создания мока бота с отслеживанием
    send_message_calls, mock_bot = mock_bot_with_message_tracking

    setup_telegram_bots_mock(mock_bot) do
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

    # Используем helper для создания мока бота с отслеживанием
    send_message_calls, mock_bot = mock_bot_with_message_tracking

    setup_telegram_bots_mock(mock_bot) do
      service = Channels::BotJoinNotificationService.new
      service.notify_success(@channel)
      service.notify_failure(@channel, 'Test error')
    end

    # Проверяем что уведомления не были отправлены
    assert_empty send_message_calls
  end

  test 'should handle Telegram API errors gracefully' do
    # Используем helper для создания мока бота с ошибкой
    mock_bot = mock_bot_with_error('Invalid token')

    # Не должно вызывать исключение
    assert_nothing_raised do
      setup_telegram_bots_mock(mock_bot) do
        service = Channels::BotJoinNotificationService.new
        service.notify_success(@channel)
      end
    end
  end

  test 'should log notification sending' do
    # Используем helper для создания мока бота с отслеживанием
    send_message_calls, mock_bot = mock_bot_with_message_tracking

    setup_telegram_bots_mock(mock_bot) do
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

    # Используем helper для создания мока бота с отслеживанием
    send_message_calls, mock_bot = mock_bot_with_message_tracking

    setup_telegram_bots_mock(mock_bot) do
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

    # Используем helper для создания мока бота с отслеживанием
    send_message_calls, mock_bot = mock_bot_with_message_tracking

    setup_telegram_bots_mock(mock_bot) do
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
end
