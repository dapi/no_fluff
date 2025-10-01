require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  test "should load fixture" do
    channel = channels(:one)
    assert_not_nil channel
  end

  test "loaded fixture should be valid" do
    channel = channels(:one)
    assert channel.valid?
  end
end
