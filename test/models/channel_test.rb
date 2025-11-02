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
    channel2.update(subscribers_count: 300)  # Уникальное значение

    ordered_channels = Channel.by_subscribers
    # large_channel (50000) > premium_channel (5000) > inactive_channel (500) > channel2 (300) > channel1 (100)
    assert_equal channels(:large_channel), ordered_channels.first
    assert_equal channels(:premium_channel), ordered_channels.second
    assert_equal channels(:inactive_channel), ordered_channels.third
    assert_equal channel2, ordered_channels.fourth
    assert_equal channel1, ordered_channels.fifth
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


  # Edge case tests
  test 'should handle nil values for optional fields' do
    channel = Channel.new(
      telegram_id: '1234567890',
      username: 'test_channel',
      title: nil,
      description: nil,
      subscribers_count: nil,
      is_verified: nil,
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

  # Bot join status tests
  test 'should have default bot_join_status as not_joined' do
    channel = Channel.create!(
      telegram_id: '1234567899',
      username: 'new_channel'
    )
    assert_equal 'not_joined', channel.bot_join_status
  end

  test 'bot_join_status enum should accept all valid values' do
    channel = channels(:one)

    valid_statuses = %w[not_joined joining joined join_failed]
    valid_statuses.each do |status|
      channel.bot_join_status = status
      assert channel.valid?, "Channel should be valid with bot_join_status=#{status}"
    end
  end

  test 'bot_join_status enum should reject invalid values' do
    channel = channels(:one)
    channel.bot_join_status = 'invalid_status'
    assert_not channel.valid?
    assert channel.errors[:bot_join_status].present?
  end

  # Bot join status scope tests
  test 'joined scope should return only joined channels' do
    channel1 = channels(:one)
    channel1.update!(bot_join_status: 'joined')

    channel2 = channels(:two)
    channel2.update!(bot_join_status: 'not_joined')

    joined_channels = Channel.joined
    assert_includes joined_channels, channel1
    assert_not_includes joined_channels, channel2
  end

  test 'not_joined scope should return only not_joined channels' do
    channel1 = channels(:one)
    channel1.update!(bot_join_status: 'not_joined')

    channel2 = channels(:two)
    channel2.update!(bot_join_status: 'joined')

    not_joined_channels = Channel.not_joined
    assert_includes not_joined_channels, channel1
    assert_not_includes not_joined_channels, channel2
  end

  test 'joining scope should return only joining channels' do
    channel1 = channels(:one)
    channel1.update!(bot_join_status: 'joining')

    channel2 = channels(:two)
    channel2.update!(bot_join_status: 'joined')

    joining_channels = Channel.joining
    assert_includes joining_channels, channel1
    assert_not_includes joining_channels, channel2
  end

  test 'join_failed scope should return only join_failed channels' do
    channel1 = channels(:one)
    channel1.update!(bot_join_status: 'join_failed')

    channel2 = channels(:two)
    channel2.update!(bot_join_status: 'joined')

    join_failed_channels = Channel.join_failed
    assert_includes join_failed_channels, channel1
    assert_not_includes join_failed_channels, channel2
  end

  # Bot join status method tests
  test 'start_joining! should update status to joining' do
    channel = channels(:one)
    channel.start_joining!

    assert_equal 'joining', channel.bot_join_status
  end

  test 'mark_as_joined! should update status to joined and set timestamp' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'joining')

    freeze_time do
      channel.mark_as_joined!

      assert_equal 'joined', channel.bot_join_status
      assert_in_delta Time.current, channel.bot_join_at, 1.second
      assert_nil channel.bot_join_error
    end
  end

  test 'mark_as_join_failed! should update status to join_failed and set error' do
    channel = channels(:one)
    error_message = 'Channel is private'

    channel.mark_as_join_failed!(error_message)

    assert_equal 'join_failed', channel.bot_join_status
    assert_equal error_message, channel.bot_join_error
  end

  test 'bot_can_monitor? should return true for active and joined channels' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'joined', deactivated_at: nil)

    assert channel.bot_can_monitor?
  end

  test 'bot_can_monitor? should return false for inactive channels' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'joined', deactivated_at: 1.hour.ago)

    assert_not channel.bot_can_monitor?
  end

  test 'bot_can_monitor? should return false for not joined channels' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined', deactivated_at: nil)

    assert_not channel.bot_can_monitor?
  end

  test 'bot_can_monitor? should return false for failed join channels' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'join_failed', deactivated_at: nil)

    assert_not channel.bot_can_monitor?
  end
end
