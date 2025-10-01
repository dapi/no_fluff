class UserDigest < ApplicationRecord
  # Associations
  belongs_to :telegram_user
  has_many :user_digest_items, dependent: :destroy
  has_many :posts, through: :user_digest_items

  # Enums
  enum :status, {
    pending: 0,
    building: 1,
    ready: 2,
    sending: 3,
    sent: 4,
    failed: 5
  }, prefix: true

  # Validations
  validates :telegram_user, presence: true
  validates :posts_analyzed_count, numericality: { greater_than_or_equal_to: 0 }
  validates :posts_included_count, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :pending, -> { where(status: :pending) }
  scope :building, -> { where(status: :building) }
  scope :ready, -> { where(status: :ready) }
  scope :sent, -> { where(status: :sent) }
  scope :failed, -> { where(status: :failed) }
  scope :scheduled_for_now, -> { where("scheduled_for <= ?", Time.current) }
  scope :for_user, ->(user) { where(telegram_user: user) }
  scope :recent, -> { where("created_at > ?", 30.days.ago) }

  # Methods
  def mark_as_building!
    update(status: :building)
  end

  def mark_as_ready!
    update(status: :ready)
  end

  def mark_as_sending!
    update(status: :sending)
  end

  def mark_as_sent!
    update(status: :sent, sent_at: Time.current)
  end

  def mark_as_failed!(error)
    update(status: :failed, error_message: error)
  end

  def has_posts?
    posts_included_count > 0
  end
end
