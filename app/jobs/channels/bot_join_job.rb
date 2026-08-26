# Compatibility name for queued legacy jobs. Channel access is MTProto-only.
class Channels::BotJoinJob < ApplicationJob
  queue_as :channels
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(channel_id)
    Channels::MtprotoChannelSyncJob.perform_later(channel_id)
  end
end
