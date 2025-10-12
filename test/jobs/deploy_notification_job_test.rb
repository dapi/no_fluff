require 'test_helper'

class DeployNotificationJobTest < ActiveJob::TestCase
  test 'should send notification to admins' do
    admin = TelegramUser.create!(
      username: 'admin',
      first_name: 'Admin',
      language_code: 'ru',
      timezone: 'UTC',
      is_admin: true
    )

    # Проверяем что админ находится в скоупе
    assert_includes TelegramUser.admins, admin

    # Отслеживаем вызовы send_message
    send_message_calls = []

    # Создаем mock API
    mock_api = Object.new
    mock_api.define_singleton_method(:send_message) do |chat_id:, text:, parse_mode:|
      send_message_calls << { chat_id: chat_id, text: text, parse_mode: parse_mode }
    end

    # Создаем mock bot
    mock_bot = Object.new
    mock_bot.define_singleton_method(:api) { mock_api }

    # Подменяем Telegram.bot
    Telegram.stub(:bot, mock_bot) do
      DeployNotificationJob.perform_now('1.0.0', Time.current, { deployed_at: Time.current.iso8601 })
    end

    # Проверяем что send_message был вызван
    assert_equal 1, send_message_calls.length
    call = send_message_calls.first
    assert_equal admin.id, call[:chat_id]
    assert_includes call[:text], '1.0.0'
    assert_includes call[:text], '🚀'
    assert_equal 'HTML', call[:parse_mode]
  end

  test 'should build notification message' do
    job = DeployNotificationJob.new
    message = job.send(:build_notification_message, '1.0.0', Time.current, {})

    assert_includes message, '🚀 <b>Новая версия развернута</b>'
    assert_includes message, '<code>1.0.0</code>'
    assert_includes message, '✅ Деплой успешно завершен!'
  end
end
