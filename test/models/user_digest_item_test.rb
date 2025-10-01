require "test_helper"

class UserDigestItemTest < ActiveSupport::TestCase
  test "should load fixture" do
    user_digest_item = user_digest_items(:one)
    assert_not_nil user_digest_item
  end

  test "loaded fixture should be valid" do
    user_digest_item = user_digest_items(:one)
    assert user_digest_item.valid?
  end

  test "should have user_digest association" do
    user_digest_item = user_digest_items(:one)
    assert_not_nil user_digest_item.user_digest
    assert_instance_of UserDigest, user_digest_item.user_digest
  end

  test "should have post association" do
    user_digest_item = user_digest_items(:one)
    assert_not_nil user_digest_item.post
    assert_instance_of Post, user_digest_item.post
  end
end
