# frozen_string_literal: true

require 'test_helper'

class Channels::RecurringMtprotoChannelSyncJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test 'enqueues one bounded MTProto sync per active subscribed public channel' do
    channel = channels(:one)
    follower = follower_users(:one)
    follower.update!(auth_status: :authorized, session_string: 'session', health_score: 90)
    channel.update!(follower_user: follower, user_access_status: :joined)
    Subscription.create!(telegram_user: telegram_users(:two), channel: channel)

    inactive_channel = channels(:two)
    inactive_channel.update!(follower_user: follower, user_access_status: :joined, deactivated_at: Time.current)

    assert_enqueued_jobs 1, only: Channels::MtprotoChannelSyncJob do
      Channels::RecurringMtprotoChannelSyncJob.perform_now(1_000)
    end

    job = enqueued_jobs.last
    assert_equal [ channel.id, follower.id, Channels::MtprotoChannelSync::DEFAULT_LIMIT ], job[:args]
  end

  test 'does not enqueue sync jobs without an authorized persisted follower session' do
    channel = channels(:one)
    channel.update!(follower_user: follower_users(:one), user_access_status: :joined)

    assert_no_enqueued_jobs only: Channels::MtprotoChannelSyncJob do
      Channels::RecurringMtprotoChannelSyncJob.perform_now
    end
  end
end
