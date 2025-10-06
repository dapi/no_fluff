require 'test_helper'

class ChannelTest < ActiveSupport::TestCase
  # Fixture tests
  test 'should load fixture' do
    channel = channels(:one)
    assert_not_nil channel
  end

  test 'loaded fixture should be valid' do
    channel = channels(:one)
    assert channel.valid?
  end

  # Validation tests
  test 'should be valid with valid attributes' do
    channel = Channel.new(
      telegram_id: '1234567890',
      username: 'test_channel'
    )
    assert channel.valid?
  end

  test 'should require telegram_id' do
    channel = Channel.new(username: 'test_channel')
    assert_not channel.valid?
    assert channel.errors[:telegram_id].present?
  end

  test 'should require unique telegram_id' do
    existing_channel = channels(:one)
    channel = Channel.new(
      telegram_id: existing_channel.telegram_id,
      username: 'another_channel'
    )
    assert_not channel.valid?
    assert channel.errors[:telegram_id].present?
  end

  test 'should require username' do
    channel = Channel.new(telegram_id: '1234567890')
    assert_not channel.valid?
    assert channel.errors[:username].present?
  end

  test 'should require unique username' do
    existing_channel = channels(:one)
    channel = Channel.new(
      telegram_id: '9876543210',
      username: existing_channel.username
    )
    assert_not channel.valid?
    assert channel.errors[:username].present?
  end

  # Association tests
  test 'should have many subscriptions' do
    channel = channels(:one)
    assert_respond_to channel, :subscriptions
  end

  test 'should have many telegram_users through subscriptions' do
    channel = channels(:one)
    assert_respond_to channel, :telegram_users
  end

  test 'should have many posts' do
    channel = channels(:one)
    assert_respond_to channel, :posts
  end

  test 'should destroy associated subscriptions when destroyed' do
    channel = Channel.create!(
      telegram_id: '9999999999',
      username: 'test_channel_destroy'
    )
    subscription = channel.subscriptions.create!(
      telegram_user: telegram_users(:one)
    )
    assert_difference 'Subscription.count', -1 do
      channel.destroy
    end
  end

  test 'should destroy associated posts when destroyed' do
    channel = Channel.create!(
      telegram_id: '9999999998',
      username: 'test_channel_destroy2'
    )
    post = channel.posts.create!(
      telegram_message_id: 88888,
      published_at: Time.current
    )
    assert_difference 'Post.count', -1 do
      channel.destroy
    end
  end

  # Scope tests
  test 'active scope should return only active channels' do
    channel = channels(:one)
    channel.update(active: true)

    active_channels = Channel.active
    assert_includes active_channels, channel
  end

  test 'active scope should not return inactive channels' do
    channel = channels(:one)
    channel.update(active: false)

    active_channels = Channel.active
    assert_not_includes active_channels, channel
  end

  test 'inactive scope should return only inactive channels' do
    channel = channels(:one)
    channel.update(active: false)

    inactive_channels = Channel.inactive
    assert_includes inactive_channels, channel
  end

  test 'inactive scope should not return active channels' do
    channel = channels(:one)
    channel.update(active: true)

    inactive_channels = Channel.inactive
    assert_not_includes inactive_channels, channel
  end

  test 'verified scope should return only verified channels' do
    channel = channels(:one)
    channel.update(is_verified: true)

    verified_channels = Channel.verified
    assert_includes verified_channels, channel
  end

  test 'verified scope should not return unverified channels' do
    channel = channels(:one)
    channel.update(is_verified: false)

    verified_channels = Channel.verified
    assert_not_includes verified_channels, channel
  end

  test 'by_subscribers scope should order channels by subscribers count descending' do
    channel1 = channels(:one)
    channel1.update(subscribers_count: 100)

    channel2 = channels(:two)
    channel2.update(subscribers_count: 500)

    ordered_channels = Channel.by_subscribers
    assert_equal channel2, ordered_channels.first
    assert_equal channel1, ordered_channels.second
  end

  test 'recently_updated scope should return channels updated in last 24 hours' do
    channel = channels(:one)
    channel.update(last_post_at: 12.hours.ago)

    recent_channels = Channel.recently_updated
    assert_includes recent_channels, channel
  end

  test 'recently_updated scope should not return channels updated more than 24 hours ago' do
    channel = channels(:one)
    channel.update(last_post_at: 25.hours.ago)

    recent_channels = Channel.recently_updated
    assert_not_includes recent_channels, channel
  end

  test 'needs_monitoring scope should return channels never monitored' do
    channel = channels(:one)
    channel.update(monitored_at: nil)

    channels_needing_monitoring = Channel.needs_monitoring
    assert_includes channels_needing_monitoring, channel
  end

  test 'needs_monitoring scope should return channels not monitored in last 10 minutes' do
    channel = channels(:one)
    channel.update(monitored_at: 11.minutes.ago)

    channels_needing_monitoring = Channel.needs_monitoring
    assert_includes channels_needing_monitoring, channel
  end

  test 'needs_monitoring scope should not return recently monitored channels' do
    channel = channels(:one)
    channel.update(monitored_at: 5.minutes.ago)

    channels_needing_monitoring = Channel.needs_monitoring
    assert_not_includes channels_needing_monitoring, channel
  end

  # Method tests
  test 'mark_as_monitored! should update monitored_at timestamp' do
    channel = channels(:one)
    original_monitored_at = channel.monitored_at

    travel_to 1.hour.from_now do
      channel.mark_as_monitored!
      channel.reload
      assert channel.monitored_at > original_monitored_at
    end
  end

  test 'update_last_post! should update last_post_at to current time' do
    channel = channels(:one)
    channel.update(last_post_at: 1.day.ago)

    freeze_time do
      channel.update_last_post!
      channel.reload
      assert_in_delta Time.current, channel.last_post_at, 1.second
    end
  end

  test 'deactivate! should set active to false' do
    channel = channels(:one)
    channel.update(active: true)

    channel.deactivate!
    channel.reload
    assert_not channel.active
  end

  test 'activate! should set active to true' do
    channel = channels(:one)
    channel.update(active: false)

    channel.activate!
    channel.reload
    assert channel.active
  end

  # Edge case tests
  test 'should handle nil values for optional fields' do
    channel = Channel.new(
      telegram_id: '1234567890',
      username: 'test_channel',
      title: nil,
      description: nil,
      subscribers_count: nil,
      is_verified: nil,
      active: nil,
      last_post_at: nil,
      monitored_at: nil
    )
    assert channel.valid?
  end

  test 'should handle zero subscribers count' do
    channel = Channel.new(
      telegram_id: '1234567890',
      username: 'test_channel',
      subscribers_count: 0
    )
    assert channel.valid?
  end

  test 'should handle large subscribers count' do
    channel = Channel.new(
      telegram_id: '1234567890',
      username: 'test_channel',
      subscribers_count: 1_000_000
    )
    assert channel.valid?
  end

  test 'should handle username with underscores' do
    channel = Channel.new(
      telegram_id: '1234567890',
      username: 'test_channel_name'
    )
    assert channel.valid?
  end

  test 'should handle long descriptions' do
    channel = Channel.new(
      telegram_id: '1234567890',
      username: 'test_channel',
      description: 'A' * 1000
    )
    assert channel.valid?
  end
end
