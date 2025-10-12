require 'test_helper'

class ChannelMessageTest < ActiveSupport::TestCase
  def setup
    @channel_message = ChannelMessage.new(
      message_id: 123,
      channel_id: -1001234567890,
      channel_username: 'testchannel',
      channel_title: 'Test Channel',
      sender_id: 987654321,
      sender_username: 'testuser',
      sender_first_name: 'Test',
      sender_last_name: 'User',
      content: 'Test message from channel',
      message_type: 'text',
      raw_data: { test: 'data' }
    )
  end

  test 'should be valid with all attributes' do
    assert @channel_message.valid?
  end

  test 'should be invalid without message_id' do
    @channel_message.message_id = nil
    assert_not @channel_message.valid?
    assert_not_empty @channel_message.errors[:message_id]
  end

  test 'should be invalid without channel_id' do
    @channel_message.channel_id = nil
    assert_not @channel_message.valid?
    assert_not_empty @channel_message.errors[:channel_id]
  end

  test 'should be invalid without content' do
    @channel_message.content = nil
    assert_not @channel_message.valid?
    assert_not_empty @channel_message.errors[:content]
  end

  test 'should be valid without optional fields' do
    channel_message = ChannelMessage.new(
      message_id: 124,
      channel_id: -1001234567891,
      content: 'Simple message'
    )
    assert channel_message.valid?
  end

  test 'should save successfully with valid data' do
    assert_difference('ChannelMessage.count') do
      @channel_message.save!
    end
  end

  test 'should enforce uniqueness of message_id and channel_id combination' do
    @channel_message.save!

    duplicate_message = ChannelMessage.new(
      message_id: 123,
      channel_id: -1001234567890,
      content: 'Another message'
    )

    assert_not duplicate_message.valid?
    # The unique constraint is enforced at database level
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate_message.save!(validate: false)
    end
  end

  test 'should allow same message_id for different channels' do
    @channel_message.save!

    different_channel = ChannelMessage.new(
      message_id: 123,
      channel_id: -1001234567891,
      content: 'Message in different channel'
    )

    assert different_channel.valid?
    assert_nothing_raised do
      different_channel.save!
    end
  end

  test 'scope from_channel should filter by channel_id' do
    channel1_message = ChannelMessage.create!(
      message_id: 125,
      channel_id: -1001111111111,
      content: 'Channel 1 message'
    )
    channel2_message = ChannelMessage.create!(
      message_id: 126,
      channel_id: -1002222222222,
      content: 'Channel 2 message'
    )

    results = ChannelMessage.from_channel(-1001111111111)
    assert_includes results, channel1_message
    assert_not_includes results, channel2_message
  end

  test 'scope recent should order by created_at desc' do
    older_message = ChannelMessage.create!(
      message_id: 127,
      channel_id: -1001111111111,
      content: 'Older message',
      created_at: 1.hour.ago
    )
    newer_message = ChannelMessage.create!(
      message_id: 128,
      channel_id: -1001111111111,
      content: 'Newer message',
      created_at: Time.current
    )

    results = ChannelMessage.recent
    assert_equal newer_message, results.first
    assert_equal older_message, results.second
  end

  test 'should handle different message types' do
    message_types = %w[text photo video document audio voice sticker animation]

    message_types.each do |type|
      message = ChannelMessage.new(
        message_id: 1000 + message_types.index(type),
        channel_id: -1001234567890,
        content: "Content with #{type}",
        message_type: type
      )
      assert message.valid?, "Should be valid with message_type: #{type}"
    end
  end

  test 'should store raw_data as jsonb' do
    raw_data = {
      'message_id' => 123,
      'chat' => { 'id' => -1001234567890, 'type' => 'channel' },
      'from' => { 'id' => 987654321, 'first_name' => 'Test' },
      'text' => 'Test message'
    }

    @channel_message.raw_data = raw_data
    @channel_message.save!

    saved_message = ChannelMessage.find(@channel_message.id)
    assert_equal raw_data['message_id'], saved_message.raw_data['message_id']
    assert_equal raw_data['chat']['id'], saved_message.raw_data['chat']['id']
    assert_equal raw_data['text'], saved_message.raw_data['text']
  end
end
