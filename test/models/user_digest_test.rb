require "test_helper"

class UserDigestTest < ActiveSupport::TestCase
  test "should load fixture" do
    user_digest = user_digests(:one)
    assert_not_nil user_digest
  end

  test "loaded fixture should be valid" do
    user_digest = user_digests(:one)
    assert user_digest.valid?
  end

  test "should have telegram_user association" do
    user_digest = user_digests(:one)
    assert_not_nil user_digest.telegram_user
    assert_instance_of TelegramUser, user_digest.telegram_user
  end
end
