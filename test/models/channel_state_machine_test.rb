require 'test_helper'

class ChannelStateMachineTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.new(
      telegram_id: 12345,
      username: 'test_channel',
      title: 'Test Channel'
    )
    @channel.save!
  end

  test 'should start with not_joined status' do
    assert_equal 'not_joined', @channel.bot_join_status
    assert @channel.bot_not_joined?
  end

  test 'should transition to joining when start_joining is called' do
    result = @channel.start_joining!

    # Reload to get fresh data from database
    @channel.reload

    assert result
    assert_equal 'joining', @channel.bot_join_status
    assert @channel.bot_joining?
  end

  test 'should transition to joined when complete_join is called' do
    @channel.start_joining!
    result = @channel.mark_as_joined!

    assert result
    assert_equal 'joined', @channel.bot_join_status
    assert @channel.bot_joined?
    assert_not_nil @channel.bot_join_at
    assert_nil @channel.bot_join_error
  end

  test 'should transition to join_failed when fail_join is called' do
    @channel.start_joining!
    error_message = 'Channel not found'
    result = @channel.mark_as_join_failed!(error_message)
    assert result
    assert_equal 'join_failed', @channel.bot_join_status
    assert @channel.bot_join_failed?
    assert_equal error_message, @channel.bot_join_error
  end

  test 'should retry joining from failed state' do
    @channel.start_joining!
    @channel.mark_as_join_failed!('First error')

    result = @channel.start_joining!
    assert result
    assert_equal 'joining', @channel.bot_join_status
    assert_nil @channel.bot_join_error
  end

  test 'should not allow joining inactive channels' do
    @channel.update!(deactivated_at: 1.day.ago)
    result = @channel.start_joining!
    assert_not result
    assert_equal 'not_joined', @channel.bot_join_status
  end

  test 'should transition from joined back to joining' do
    @channel.start_joining!
    @channel.mark_as_joined!

    result = @channel.start_joining!
    assert result
    assert_equal 'joining', @channel.bot_join_status
  end

  test 'bot_can_monitor should return true only for active joined channels' do
    # Not joined channel
    assert_not @channel.bot_can_monitor?

    # Joined active channel
    @channel.start_joining!
    @channel.mark_as_joined!
    assert @channel.bot_can_monitor?

    # Joined inactive channel
    @channel.update!(deactivated_at: 1.hour.ago)
    assert_not @channel.bot_can_monitor?
  end

  test 'should work with scopes' do
    # Create channels in different states
    joining_channel = Channel.new(telegram_id: 23456, username: 'joining_channel', title: 'Joining')
    joining_channel.save!
    joined_channel = Channel.new(telegram_id: 34567, username: 'joined_channel', title: 'Joined')
    joined_channel.save!
    failed_channel = Channel.new(telegram_id: 45678, username: 'failed_channel', title: 'Failed')
    failed_channel.save!

    joining_channel.start_joining!
    joined_channel.start_joining!
    joined_channel.mark_as_joined!
    failed_channel.start_joining!
    failed_channel.mark_as_join_failed!('Error')

    assert_includes Channel.not_joined, @channel
    assert_includes Channel.joining, joining_channel
    assert_includes Channel.joined, joined_channel
    assert_includes Channel.join_failed, failed_channel
  end
end
