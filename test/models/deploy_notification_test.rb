require "test_helper"

class DeployNotificationTest < ActiveSupport::TestCase
  def setup
    @deploy_notification = DeployNotification.new(
      version: "1.0.0",
      metadata: { environment: "test" }
    )
  end

  test "should be valid with all attributes" do
    assert @deploy_notification.valid?
  end

  test "should be invalid without version" do
    @deploy_notification.version = nil
    assert_not @deploy_notification.valid?
  end

  test "should save metadata as hash" do
    @deploy_notification.save!
    @deploy_notification.reload
    assert_equal Hash, @deploy_notification.metadata.class
    assert_equal "test", @deploy_notification.metadata["environment"]
  end

  test "should handle empty metadata" do
    @deploy_notification.metadata = {}
    assert @deploy_notification.valid?
  end

  test "should have default metadata" do
    notification = DeployNotification.new(version: "1.0.0")
    assert_equal Hash, notification.metadata.class
  end

  test "scope recent should order by created_at desc" do
    # Use unique versions to avoid conflicts
    old_notification = DeployNotification.create!(
      version: "0.9.0",
      metadata: { environment: "test" }
    )
    travel_to 1.hour.from_now
    new_notification = DeployNotification.create!(
      version: "1.0.1",
      metadata: { environment: "test" }
    )

    notifications = DeployNotification.recent
    assert_equal new_notification.id, notifications.first.id
    assert_equal old_notification.id, notifications.last.id

    travel_back
  end

  test "scope by_version should find by version" do
    @deploy_notification.save!
    found = DeployNotification.by_version("1.0.0")
    assert_equal @deploy_notification.id, found.id
  end

  test "scope by_version should return nil for non-existent version" do
    found = DeployNotification.by_version("non-existent")
    assert_nil found
  end
end
