require 'test_helper'

class DeployNotificationJobTest < ActiveJob::TestCase
  test 'should send notification to admins' do
    # Используем существующего админа из фикстур вместо создания нового
    admin = telegram_users(:admin_user)

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

    # Проверяем что send_message был вызван для каждого админа
    admin_count = TelegramUser.admins.count
    assert_equal admin_count, send_message_calls.length

    # Находим вызов для нашего админа
    admin_call = send_message_calls.find { |call| call[:chat_id] == admin.telegram_id }
    assert_not_nil admin_call
    assert_includes admin_call[:text], '1.0.0'
    assert_includes admin_call[:text], '🚀'
    assert_equal 'HTML', admin_call[:parse_mode]
  end

  test 'should build notification message' do
    job = DeployNotificationJob.new
    message = job.send(:build_notification_message, '1.0.0', Time.current, {})

    assert_includes message, '🚀 <b>Новая версия развернута</b>'
    assert_includes message, '<code>1.0.0</code>'
    assert_includes message, '✅ Деплой успешно завершен!'
  end
end
