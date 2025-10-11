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

    # Создаем mock API который ожидает вызов send_message
    mock_api = Minitest::Mock.new
    mock_api.expect(:send_message, nil, [{ chat_id: admin.id, text: String, parse_mode: 'HTML' }])

    # Создаем mock bot который возвращает наш API
    mock_bot = Minitest::Mock.new
    mock_bot.expect(:api, mock_api)

    # Используем правильный stub для Telegram.bot
    Telegram.stub(:bot, mock_bot) do
      DeployNotificationJob.perform_now('1.0.0', Time.current, { deployed_at: Time.current.iso8601 })
    end

    assert_mock mock_bot
    assert_mock mock_api
  end

  test 'should build notification message' do
    job = DeployNotificationJob.new
    message = job.send(:build_notification_message, '1.0.0', Time.current, {})

    assert_includes message, '🚀 <b>Новая версия развернута</b>'
    assert_includes message, '<code>1.0.0</code>'
    assert_includes message, '✅ Деплой успешно завершен!'
  end
end
