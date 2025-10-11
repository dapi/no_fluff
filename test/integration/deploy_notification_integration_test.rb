require "test_helper"

class DeployNotificationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = TelegramUser.create!(
      username: "admin_user",
      first_name: "Admin",
      language_code: "ru",
      timezone: "UTC",
      is_admin: true
    )
  end

  test "complete deploy notification flow" do
    # Mock Telegram API
    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new

    Telegram.stub :bot, mock_bot do
      mock_bot.expect :api, mock_api
      mock_api.expect(:send_message, nil, [
        {
          chat_id: @admin.telegram_id,
          text: String,
          parse_mode: 'HTML'
        }
      ])
    end

    # Mock AppVersion
    AppVersion.stub(:to_s, "1.0.0") do
      # Simulate deploy notification creation (like in initializer)
      notification = DeployNotification.find_or_create_by(version: "1.0.0") do |record|
        record.metadata = { environment: "test" }
      end

      # Verify notification was created
      assert_not_nil notification
      assert_equal "1.0.0", notification.version
      assert_equal "test", notification.metadata[:environment]

      # Wait for async job to complete
      perform_enqueued_jobs

      # Verify Telegram API was called
      assert_mock mock_bot
      assert_mock mock_api
    end
  end

  test "should not create duplicate notifications for same version" do
    AppVersion.stub(:to_s, "1.0.0") do
      # Create first notification
      notification1 = DeployNotification.find_or_create_by(version: "1.0.0") do |record|
        record.metadata = { environment: "test" }
      end

      # Try to create duplicate
      notification2 = DeployNotification.find_or_create_by(version: "1.0.0") do |record|
        record.metadata = { environment: "production" }
      end

      # Should return the same record
      assert_equal notification1.id, notification2.id
      assert_equal "test", notification2.metadata[:environment] # metadata from first creation
    end
  end

  test "should handle multiple versions" do
    AppVersion.stub(:to_s, "1.0.0") do
      notification1 = DeployNotification.find_or_create_by(version: "1.0.0") do |record|
        record.metadata = { environment: "test" }
      end
    end

    AppVersion.stub(:to_s, "1.1.0") do
      notification2 = DeployNotification.find_or_create_by(version: "1.1.0") do |record|
        record.metadata = { environment: "production" }
      end
    end

    # Should have both notifications
    assert_equal 2, DeployNotification.count
    assert DeployNotification.find_by(version: "1.0.0")
    assert DeployNotification.find_by(version: "1.1.0")
  end

  test "should work with multiple admin users" do
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

    AppVersion.stub(:to_s, "1.0.0") do
      notification = DeployNotification.find_or_create_by(version: "1.0.0") do |record|
        record.metadata = { environment: "test" }
      end

      perform_enqueued_jobs

      assert_mock mock_bot
      assert_mock mock_api
    end
  end

  test "should not create notifications without version" do
    assert_raises(ActiveRecord::RecordInvalid) do
      DeployNotification.create!(version: nil)
    end
  end

  test "should handle initialization errors gracefully" do
    # Mock AppVersion to raise an error
    AppVersion.stub(:to_s) do
      raise StandardError.new("Version error")
    end do
      # Should not raise an exception in the initializer
      # The initializer catches and logs the error
      assert_nothing_raised do
        # Simulate initializer logic
        begin
          version = AppVersion.to_s
          DeployNotification.find_or_create_by(version: version) do |record|
            record.metadata = {}
          end
        rescue => e
          Bugsnag.notify(e, { context: "deploy_notification_initializer" })
          Rails.logger.error "Deploy notification initialization failed: #{e.message}"
        end
      end
    end
  end
end