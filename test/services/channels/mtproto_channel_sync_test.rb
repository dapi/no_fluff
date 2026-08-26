# frozen_string_literal: true

require 'test_helper'

class Channels::MtprotoChannelSyncTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class FakeClient
    attr_reader :resolved, :joined, :read

    def initialize(join_result:, resolve_result: nil, read_result: { success: true, messages: [] })
      @join_result = join_result
      @resolve_result = resolve_result || join_result
      @read_result = read_result
    end

    def resolve_channel(username)
      @resolved = username
      @resolve_result
    end

    def join_channel(username)
      @joined = username
      @join_result
    end

    def read_channel_messages(**arguments)
      @read = arguments
      @read_result
    end
  end

  def setup
    @channel = channels(:one)
    @follower = follower_users(:one)
    @follower.update!(auth_status: :authorized, session_string: 'session', health_score: 90, channels_count: 0, daily_joins_count: 0)
    @channel.update!(follower_user: nil, user_access_status: :not_joined, assignment_status: :unassigned)
  end

  test 'does not mark a channel joined before the live MTProto join succeeds' do
    resolved_channel = { id: @channel.telegram_id, access_hash: 'hash', username: @channel.username, title: @channel.title }
    client = FakeClient.new(
      resolve_result: { success: true, channel: resolved_channel },
      join_result: { success: false, error_type: :private_channel }
    )

    result = Channels::MtprotoChannelSync.new(channel: @channel, follower_user: @follower, client:).call

    assert_equal false, result[:success]
    assert_equal 'join_failed', @channel.reload.user_access_status
    assert_equal @follower, @channel.follower_user
    assert_equal "@#{@channel.username}", client.joined
  end

  test 'imports each Telegram message once and enqueues classification but never delivery directly' do
    messages = [
      { id: 701, date: '2026-08-26T10:00:00Z', text: 'one', views: 12, forwards: 2 },
      { id: 702, date: '2026-08-26T10:01:00Z', text: 'two', views: nil, forwards: nil }
    ]
    client = FakeClient.new(
      join_result: { success: true, channel: { id: @channel.telegram_id, access_hash: 'hash', username: @channel.username, title: 'Updated title' } },
      read_result: { success: true, messages: messages }
    )

    assert_enqueued_jobs 2, only: Content::ProcessPostJob do
      assert_no_enqueued_jobs only: Content::DeliverPostsJob do
        assert_equal true, Channels::MtprotoChannelSync.new(channel: @channel, follower_user: @follower, client:, limit: 20).call[:success]
      end
    end
    assert_equal 'joined', @channel.reload.user_access_status
    assert_equal 'Updated title', @channel.title
    assert_equal [ 701, 702 ], @channel.posts.where(telegram_message_id: [ 701, 702 ]).order(:telegram_message_id).pluck(:telegram_message_id)

    Channels::MtprotoChannelSync.new(channel: @channel, follower_user: @follower, client:, limit: 20).call
    assert_equal 2, @channel.posts.where(telegram_message_id: [ 701, 702 ]).count
  end

  test 'resolves access hash again when syncing a previously joined channel' do
    @channel.update!(follower_user: @follower, user_access_status: :joined, assignment_status: :assigned)
    resolved_channel = { id: @channel.telegram_id, access_hash: 'restored-hash', username: @channel.username, title: @channel.title }
    client = FakeClient.new(
      join_result: { success: true, channel: resolved_channel },
      resolve_result: { success: true, channel: resolved_channel }
    )

    result = Channels::MtprotoChannelSync.new(channel: @channel, follower_user: @follower, client:).call

    assert_equal true, result[:success]
    assert_equal "@#{@channel.username}", client.resolved
    assert_nil client.joined
    assert_equal 'restored-hash', client.read.dig(:channel, :access_hash)
  end
end
