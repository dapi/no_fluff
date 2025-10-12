class Channel < ApplicationRecord
  include ChannelUpdatable
  # Associations
  has_many :subscriptions, dependent: :destroy
  has_many :telegram_users, through: :subscriptions
  has_many :posts, dependent: :destroy

  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  # Enums
  enum bot_join_status: {
    not_joined: 0,
    joining: 1,
    joined: 2,
    join_failed: 3
  }

  # Scopes
  scope :active, -> { where(deactivated_at: nil) }
  scope :inactive, -> { where.not(deactivated_at: nil) }
  scope :verified, -> { where(is_verified: true) }
  scope :by_subscribers, -> { order(subscribers_count: :desc) }
  scope :recently_updated, -> { where('last_post_at > ?', 24.hours.ago) }
  scope :needs_monitoring, -> { where('monitored_at IS NULL OR monitored_at < ?', 10.minutes.ago) }

  # Bot join status scopes
  scope :joined, -> { where(bot_join_status: 'joined') }
  scope :not_joined, -> { where(bot_join_status: 'not_joined') }
  scope :joining, -> { where(bot_join_status: 'joining') }
  scope :join_failed, -> { where(bot_join_status: 'join_failed') }

  # Methods
  def mark_as_monitored!
    touch(:monitored_at)
  end

  def update_last_post!
    update(last_post_at: Time.current)
  end

  def deactivate!
    update(deactivated_at: Time.current, deactivation_reason: 'manual_deactivation')
  end

  def activate!
    update(deactivated_at: nil, deactivation_reason: nil)
  end

  def active?
    deactivated_at.nil?
  end

  # Bot join status methods
  def start_joining!
    update!(bot_join_status: 'joining')
  end

  def mark_as_joined!
    update!(bot_join_status: 'joined', bot_join_at: Time.current, bot_join_error: nil)
  end

  def mark_as_join_failed!(error_message)
    update!(bot_join_status: 'join_failed', bot_join_error: error_message)
  end

  def bot_can_monitor?
    active? && joined?
  end
end
