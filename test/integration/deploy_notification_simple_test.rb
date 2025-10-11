require "test_helper"

class DeployNotificationSimpleTest < ActionDispatch::IntegrationTest
  test "deploy notification system works end to end" do
    # Create admin user
    admin = TelegramUser.create!(
      username: "admin_user",
      first_name: "Admin",
      language_code: "ru",
      timezone: "UTC",
      is_admin: true
    )

    # Create deploy notification
    notification = DeployNotification.create!(
      version: "1.0.0",
      metadata: { environment: "test", git_commit: "abc123" }
    )

    # Verify notification was created
    assert_not_nil notification
    assert_equal "1.0.0", notification.version
    assert_equal "test", notification.metadata["environment"]
    assert_equal "abc123", notification.metadata["git_commit"]

    # Test job creation (without actually sending)
    job = DeployNotificationJob.new
    message = job.send(:build_notification_message, "1.0.0", Time.current, { environment: "test" })

    assert_includes message, "🚀 <b>Новая версия развернута</b>"
    assert_includes message, "1.0.0"
    assert_includes message, "Environment: test"
  end

  test "should not create duplicate notifications" do
    # Create first notification
    notification1 = DeployNotification.create!(
      version: "1.0.0",
      metadata: { environment: "test" }
    )

    # Try to create duplicate - should raise exception
    assert_raises(ActiveRecord::RecordInvalid) do
      DeployNotification.create!(
        version: "1.0.0",
        metadata: { environment: "production" }
      )
    end

    # Should still have only one notification
    assert_equal 1, DeployNotification.where(version: "1.0.0").count
  end

  test "should use find_or_create_by correctly" do
    # Create first notification
    notification1 = DeployNotification.find_or_create_by(version: "1.0.0") do |record|
      record.metadata = { environment: "test" }
    end

    # Try to create duplicate - should return existing record
    notification2 = DeployNotification.find_or_create_by(version: "1.0.0") do |record|
      record.metadata = { environment: "production" }
    end

    # Should be the same record
    assert_equal notification1.id, notification2.id
    assert_equal "test", notification2.metadata["environment"]
  end
end