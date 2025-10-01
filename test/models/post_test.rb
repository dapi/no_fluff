require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "should load fixture" do
    post = posts(:one)
    assert_not_nil post
  end

  test "loaded fixture should be valid" do
    post = posts(:one)
    assert post.valid?
  end

  test "should have channel association" do
    post = posts(:one)
    assert_not_nil post.channel
    assert_instance_of Channel, post.channel
  end
end
