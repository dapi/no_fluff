class Channel < ApplicationRecord
  # Associations
  has_many :subscriptions, dependent: :destroy
  has_many :telegram_users, through: :subscriptions
  has_many :posts, dependent: :destroy

  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :verified, -> { where(is_verified: true) }
  scope :by_subscribers, -> { order(subscribers_count: :desc) }
  scope :recently_updated, -> { where("last_post_at > ?", 24.hours.ago) }
  scope :needs_monitoring, -> { where("monitored_at IS NULL OR monitored_at < ?", 10.minutes.ago) }

  # Methods
  def mark_as_monitored!
    touch(:monitored_at)
  end

  def update_last_post!
    update(last_post_at: Time.current)
  end

  def deactivate!
    update(active: false)
  end

  def activate!
    update(active: true)
  end
end
