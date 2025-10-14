class ChannelMessage < ApplicationRecord
  validates :message_id, presence: true
  validates :channel_id, presence: true
  validates :content, presence: true
  validates :message_id, uniqueness: { scope: :channel_id }

  scope :from_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :recent, -> { order(created_at: :desc) }
end
