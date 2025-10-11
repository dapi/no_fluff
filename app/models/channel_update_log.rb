class ChannelUpdateLog < ApplicationRecord
  belongs_to :channel, optional: true

  STATUS_TYPES = %w[info success warning error].freeze

  validates :status, inclusion: { in: STATUS_TYPES }
  validates :source, presence: true
  validates :message, presence: true
  validates :status, presence: true

  scope :by_source, ->(source) { where(source: source) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, ->(hours = 24) { where('created_at > ?', hours.hours.ago) }
  scope :for_channel, ->(channel) { where(channel: channel) }
end