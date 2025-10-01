require "test_helper"

class TelegramUserTest < ActiveSupport::TestCase
  test "should load fixture" do
    telegram_user = telegram_users(:one)
    assert_not_nil telegram_user
  end

  test "loaded fixture should be valid" do
    telegram_user = telegram_users(:one)
    assert telegram_user.valid?
  end
end
