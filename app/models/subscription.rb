class Subscription < ApplicationRecord
  # Associations
  belongs_to :telegram_user
  belongs_to :channel

  # Validations
  validates :telegram_user_id, uniqueness: { scope: :channel_id }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_created_at, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(telegram_user: user) }
  scope :for_channel, ->(channel) { where(channel: channel) }

  # Methods
  def deactivate!
    update(active: false)
  end

  def activate!
    update(active: true)
  end

  def update_last_digest_sent!
    touch(:last_digest_sent_at)
  end
end
