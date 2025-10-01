require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "should load fixture" do
    subscription = subscriptions(:one)
    assert_not_nil subscription
  end

  test "loaded fixture should be valid" do
    subscription = subscriptions(:one)
    assert subscription.valid?
  end

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
end
