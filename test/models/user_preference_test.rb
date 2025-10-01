require "test_helper"

class UserPreferenceTest < ActiveSupport::TestCase
  test "should load fixture" do
    user_preference = user_preferences(:one)
    assert_not_nil user_preference
  end

  test "loaded fixture should be valid" do
    user_preference = user_preferences(:one)
    assert user_preference.valid?
  end

  test "should have telegram_user association" do
    user_preference = user_preferences(:one)
    assert_not_nil user_preference.telegram_user
    assert_instance_of TelegramUser, user_preference.telegram_user
  end
end
