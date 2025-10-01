require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  # Fixture tests
  test "should load fixture" do
    subscription = subscriptions(:one)
    assert_not_nil subscription
  end

  test "loaded fixture should be valid" do
    subscription = subscriptions(:one)
    assert subscription.valid?
  end

  # Association tests
  test "should have telegram_user association" do
    subscription = subscriptions(:one)
    assert_not_nil subscription.telegram_user
    assert_instance_of TelegramUser, subscription.telegram_user
  end

  test "should have channel association" do
    subscription = subscriptions(:one)
    assert_not_nil subscription.channel
    assert_instance_of Channel, subscription.channel
  end

  test "should belong to telegram_user" do
    subscription = subscriptions(:one)
    assert_respond_to subscription, :telegram_user
  end

  test "should belong to channel" do
    subscription = subscriptions(:one)
    assert_respond_to subscription, :channel
  end

  # Validation tests
  test "should be valid with valid attributes" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 5
    )
    assert subscription.valid?
  end

  test "should require unique telegram_user_id scoped to channel_id" do
    existing_subscription = subscriptions(:one)
    subscription = Subscription.new(
      telegram_user: existing_subscription.telegram_user,
      channel: existing_subscription.channel,
      priority: 5
    )
    assert_not subscription.valid?
    assert subscription.errors[:telegram_user_id].present?
  end

  test "should allow same telegram_user for different channels" do
    user = telegram_users(:one)
    channel2 = channels(:two)

    # subscription for channel one already exists in fixtures

    subscription2 = Subscription.new(
      telegram_user: user,
      channel: channel2,
      priority: 5
    )
    assert subscription2.valid?
  end

  test "should allow same channel for different telegram_users" do
    user1 = telegram_users(:one)
    user2 = telegram_users(:two)
    channel = channels(:one)

    subscription1 = subscriptions(:one)

    subscription2 = Subscription.new(
      telegram_user: user2,
      channel: channel,
      priority: 5
    )
    assert subscription2.valid?
  end

  test "should require priority" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: nil
    )
    assert_not subscription.valid?
    assert subscription.errors[:priority].present?
  end

  test "should require priority to be an integer" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 5.5
    )
    assert_not subscription.valid?
    assert subscription.errors[:priority].present?
  end

  test "should require priority to be greater than or equal to 1" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 0
    )
    assert_not subscription.valid?
    assert subscription.errors[:priority].present?
  end

  test "should require priority to be less than or equal to 10" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 11
    )
    assert_not subscription.valid?
    assert subscription.errors[:priority].present?
  end

  test "should accept priority of 1" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 1
    )
    assert subscription.valid?
  end

  test "should accept priority of 10" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 10
    )
    assert subscription.valid?
  end

  # Scope tests
  test "active scope should return only active subscriptions" do
    subscription = subscriptions(:one)
    subscription.update(active: true)

    active_subscriptions = Subscription.active
    assert_includes active_subscriptions, subscription
  end

  test "active scope should not return inactive subscriptions" do
    subscription = subscriptions(:one)
    subscription.update(active: false)

    active_subscriptions = Subscription.active
    assert_not_includes active_subscriptions, subscription
  end

  test "inactive scope should return only inactive subscriptions" do
    subscription = subscriptions(:one)
    subscription.update(active: false)

    inactive_subscriptions = Subscription.inactive
    assert_includes inactive_subscriptions, subscription
  end

  test "inactive scope should not return active subscriptions" do
    subscription = subscriptions(:one)
    subscription.update(active: true)

    inactive_subscriptions = Subscription.inactive
    assert_not_includes inactive_subscriptions, subscription
  end

  test "by_priority scope should order subscriptions by priority descending" do
    subscription1 = subscriptions(:one)
    subscription1.update(priority: 3)

    subscription2 = subscriptions(:two)
    subscription2.update(priority: 8)

    ordered_subscriptions = Subscription.by_priority
    assert_equal subscription2, ordered_subscriptions.first
    assert_equal subscription1, ordered_subscriptions.second
  end

  test "for_user scope should return subscriptions for specific user" do
    user = telegram_users(:one)
    subscription = subscriptions(:one)

    user_subscriptions = Subscription.for_user(user)
    assert_includes user_subscriptions, subscription
  end

  test "for_user scope should not return subscriptions for other users" do
    user1 = telegram_users(:one)
    user2 = telegram_users(:two)
    subscription2 = subscriptions(:two)

    user1_subscriptions = Subscription.for_user(user1)
    assert_not_includes user1_subscriptions, subscription2
  end

  test "for_channel scope should return subscriptions for specific channel" do
    channel = channels(:one)
    subscription = subscriptions(:one)

    channel_subscriptions = Subscription.for_channel(channel)
    assert_includes channel_subscriptions, subscription
  end

  test "for_channel scope should not return subscriptions for other channels" do
    channel1 = channels(:one)
    channel2 = channels(:two)
    subscription2 = subscriptions(:two)

    channel1_subscriptions = Subscription.for_channel(channel1)
    assert_not_includes channel1_subscriptions, subscription2
  end

  # Method tests
  test "deactivate! should set active to false" do
    subscription = subscriptions(:one)
    subscription.update(active: true)

    subscription.deactivate!
    subscription.reload
    assert_not subscription.active
  end

  test "activate! should set active to true" do
    subscription = subscriptions(:one)
    subscription.update(active: false)

    subscription.activate!
    subscription.reload
    assert subscription.active
  end

  test "update_last_digest_sent! should update last_digest_sent_at timestamp" do
    subscription = subscriptions(:one)
    original_timestamp = subscription.last_digest_sent_at

    travel_to 1.hour.from_now do
      subscription.update_last_digest_sent!
      subscription.reload
      assert subscription.last_digest_sent_at > original_timestamp
    end
  end

  test "update_last_digest_sent! should set timestamp if nil" do
    subscription = subscriptions(:one)
    subscription.update(last_digest_sent_at: nil)

    freeze_time do
      subscription.update_last_digest_sent!
      subscription.reload
      assert_not_nil subscription.last_digest_sent_at
      assert_in_delta Time.current, subscription.last_digest_sent_at, 1.second
    end
  end

  # Edge case tests
  test "should handle nil values for optional fields" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 5,
      active: nil,
      last_digest_sent_at: nil,
      settings: nil
    )
    assert subscription.valid?
  end

  test "should handle settings as jsonb field" do
    subscription = subscriptions(:one)
    subscription.settings = { notifications: true, frequency: "daily" }
    assert subscription.save
    subscription.reload
    assert_equal true, subscription.settings["notifications"]
    assert_equal "daily", subscription.settings["frequency"]
  end

  test "should allow nil settings" do
    subscription = Subscription.new(
      telegram_user: telegram_users(:one),
      channel: channels(:two),
      priority: 5,
      settings: nil
    )
    assert subscription.valid?
  end

  test "should handle empty settings hash" do
    subscription = subscriptions(:one)
    subscription.settings = {}
    assert subscription.save
    subscription.reload
    assert_equal({}, subscription.settings)
  end
end
