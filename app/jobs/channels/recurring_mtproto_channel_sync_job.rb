# frozen_string_literal: true

class Channels::RecurringMtprotoChannelSyncJob < ApplicationJob
  queue_as :channels
  limits_concurrency to: 1, key: ->(*) { 'recurring-mtproto-channel-sync' }, duration: 10.minutes

  def perform(limit = Channels::MtprotoChannelSync::DEFAULT_LIMIT)
    eligible_channels.find_each do |channel|
      Channels::MtprotoChannelSyncJob.perform_later(channel.id, channel.follower_user_id, bounded_limit(limit))
    end
  end

  private

  def eligible_channels
    Channel.active
           .joins(:subscriptions, :follower_user)
           .merge(Subscription.active)
           .merge(FollowerUser.authorized)
           .where.not(channels: { username: nil })
           .where.not(follower_users: { session_string_encrypted: nil })
           .distinct
  end

  def bounded_limit(limit)
    [ [ Integer(limit), 1 ].max, Channels::MtprotoChannelSync::DEFAULT_LIMIT ].min
  end
end
