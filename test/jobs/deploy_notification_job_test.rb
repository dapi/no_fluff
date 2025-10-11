require "test_helper"

class DeployNotificationJobTest < ActiveJob::TestCase
  setup do
    @admin = TelegramUser.create!(
      username: "admin_user",
      first_name: "Admin",
      language_code: "ru",
      timezone: "UTC",
      is_admin: true
    )

    @version = "1.0.0"
    @created_at = Time.current
    @metadata = { environment: "test", git_commit: "abc123" }
  end

  test "should send notification to admin users" do
    # Mock the Telegram bot API
    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new

    Telegram.stub :bot, mock_bot do
      mock_bot.expect :api, mock_api
      mock_api.expect(:send_message, nil, [
        {
          chat_id: @admin.telegram_id,
          text: String, # We'll test the message format separately
          parse_mode: 'HTML'
        }
      ])
    end

    DeployNotificationJob.perform_now(@version, @created_at, @metadata)

    assert_mock mock_bot
    assert_mock mock_api
  end

  test "should send notification to multiple admins" do
    admin2 = TelegramUser.create!(
      username: "admin_user2",
      first_name: "Admin2",
      language_code: "ru",
      timezone: "UTC",
      is_admin: true
    )

    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new

    Telegram.stub :bot, mock_bot do
      mock_bot.expect :api, mock_api
      mock_api.expect(:send_message, nil, [{ chat_id: @admin.telegram_id, text: String, parse_mode: 'HTML' }])
      mock_api.expect(:send_message, nil, [{ chat_id: admin2.telegram_id, text: String, parse_mode: 'HTML' }])
    end

    DeployNotificationJob.perform_now(@version, @created_at, @metadata)

    assert_mock mock_bot
    assert_mock mock_api
  end

  test "should not send notification to non-admin users" do
    user = TelegramUser.create!(
      username: "regular_user",
      first_name: "User",
      language_code: "ru",
      timezone: "UTC",
      is_admin: false
    )

    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new

    Telegram.stub :bot, mock_bot do
      mock_bot.expect :api, mock_api
      mock_api.expect(:send_message, nil, [{ chat_id: @admin.telegram_id, text: String, parse_mode: 'HTML' }])
    end

    DeployNotificationJob.perform_now(@version, @created_at, @metadata)

    assert_mock mock_bot
    assert_mock mock_api
  end

  test "should handle Telegram API errors gracefully" do
    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new

    Telegram.stub :bot, mock_bot do
      mock_bot.expect :api, mock_api
      mock_api.expect(:send_message, nil) do
        raise Telegram::Bot::Exceptions::BaseError.new("API Error")
      end
    end

    # Should not raise an exception, but should notify Bugsnag
    Bugsnag.stub(:notify, nil) do
      assert_nothing_raised do
        DeployNotificationJob.perform_now(@version, @created_at, @metadata)
      end
    end

    assert_mock mock_bot
    assert_mock mock_api
  end

  test "should build correct notification message" do
    job = DeployNotificationJob.new
    message = job.send(:build_notification_message, @version, @created_at, @metadata)

    assert_includes message, "🚀 <b>Новая версия развернута</b>"
    assert_includes message, "<code>#{@version}</code>"
    assert_includes message, @created_at.strftime('%Y-%m-%d %H:%M:%S UTC')
    assert_includes message, "Environment: test"
    assert_includes message, "Git commit: abc123"
    assert_includes message, "✅ Деплой успешно завершен!"
  end

  test "should handle empty metadata" do
    job = DeployNotificationJob.new
    message = job.send(:build_notification_message, @version, @created_at, {})

    assert_includes message, "🚀 <b>Новая версия развернута</b>"
    assert_includes message, "<code>#{@version}</code>"
    assert_includes message, @created_at.strftime('%Y-%m-%d %H:%M:%S UTC')
    assert_not_includes message, "📋 <b>Детали:</b>"
  end

  test "should not send notification when no admins exist" do
    @admin.update!(is_admin: false)

    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new

    Telegram.stub :bot, mock_bot do
      mock_bot.expect :api, mock_api
      # send_message should not be called since there are no admins
    end

    DeployNotificationJob.perform_now(@version, @created_at, @metadata)

    # Verify that send_message was not called
    assert_mock mock_bot
  end
end
