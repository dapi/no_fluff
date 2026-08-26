# frozen_string_literal: true

class Channels::MtprotoChannelSyncJob < ApplicationJob
  queue_as :channels

  def perform(channel_id, follower_user_id = nil, limit = Channels::MtprotoChannelSync::DEFAULT_LIMIT)
    channel = Channel.find(channel_id)
    follower_user = FollowerUser.find(follower_user_id) if follower_user_id
    Channels::MtprotoChannelSync.new(channel:, follower_user:, limit:).call
  end
end
