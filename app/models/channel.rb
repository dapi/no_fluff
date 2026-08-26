class Channel < ApplicationRecord
  include ChannelUpdatable
  include ChannelAccess

  # Associations
  has_many :subscriptions, dependent: :destroy
  has_many :telegram_users, through: :subscriptions
  has_many :posts, dependent: :destroy
  belongs_to :follower_user, optional: true

  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  # State Machine для управления процессом вступления бота в канал
  state_machine :bot_join_status, initial: :bot_not_joined do
    # Состояния (используем префикс bot_ чтобы избежать конфликтов с enum)
    state :bot_not_joined, value: 'not_joined'
    state :bot_joining, value: 'joining'
    state :bot_joined, value: 'joined'
    state :bot_join_failed, value: 'join_failed'

    # Переходы
    event :start_joining do
      transition bot_not_joined: :bot_joining
      transition bot_join_failed: :bot_joining
      transition bot_joined: :bot_joining
    end

    event :complete_join do
      transition bot_joining: :bot_joined
      transition joining: :bot_joined
    end

    event :fail_join do
      transition bot_joining: :bot_join_failed
      transition bot_not_joined: :bot_join_failed
      transition joining: :bot_join_failed
    end

    # Callbacks
    before_transition on: :start_joining, do: :clear_join_errors
    after_transition on: :complete_join, do: :record_join_success
    after_transition on: :fail_join, do: :record_join_failure

    # Guards
    before_transition any => :joining, do: :ensure_channel_active
    before_transition on: :start_joining, do: :ensure_channel_active
  end

  # Enums
  enum :user_access_status, not_joined: 0, joining: 1, joined: 2, join_failed: 3, left: 4, access_lost: 5

  enum :assignment_status, unassigned: 0, assigned: 1, reassigning: 2, assignment_failed: 3

  # Scopes
  scope :active, -> { where(deactivated_at: nil) }
  scope :inactive, -> { where.not(deactivated_at: nil) }
  scope :verified, -> { where(is_verified: true) }
  scope :by_subscribers, -> { order(subscribers_count: :desc) }
  scope :recently_updated, -> { where('last_post_at > ?', 24.hours.ago) }
  scope :needs_monitoring, -> { where('monitored_at IS NULL OR monitored_at < ?', 10.minutes.ago) }

  # User access status scopes
  scope :joined_by_user, -> { where(user_access_status: :joined) }
  scope :not_joined_by_user, -> { where(user_access_status: :not_joined) }
  scope :user_join_failed, -> { where(user_access_status: :join_failed) }
  scope :assigned_to_user, -> { where.not(follower_user_id: nil) }
  scope :unassigned, -> { where(follower_user_id: nil) }

  # Bot join status scopes (сохраняем для совместимости)
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

  # Bot join status методы с использованием state machine
  def start_joining!
    if start_joining
      Rails.logger.info "Started joining process for channel #{username} (#{id})"
      true
    else
      Rails.logger.warn "Failed to start joining process for channel #{username} (#{id})"
      false
    end
  end

  def mark_as_joined!
    if complete_join
      Rails.logger.info "Bot successfully joined channel #{username} (#{id})"
      true
    else
      Rails.logger.warn "Failed to mark channel #{username} (#{id}) as joined"
      false
    end
  end

  def mark_as_join_failed!(error_message)
    @join_error_message = error_message
    if fail_join
      Rails.logger.error "Bot failed to join channel #{username} (#{id}): #{error_message}"
      true
    else
      Rails.logger.warn "Failed to mark channel #{username} (#{id}) as join failed"
      false
    end
  end

  def bot_can_monitor?
    active? && bot_joined?
  end

  # Follower user access methods (delegates to ChannelAccess concern)
  def user_can_monitor?
    active? && user_access_status == 'joined'
  end

  def calculate_activity_score
    return 0.0 if last_post_at.blank?

    # Calculate based on posting frequency and recency
    days_since_last_post = (Time.current - last_post_at) / 1.day
    recency_score = [ 100 - (days_since_last_post * 5), 0 ].max

    # Factor in subscriber count (normalized)
    subscribers_score = [ subscribers_count.to_f / 10000, 1.0 ].min * 30

    # Final weighted score
    (recency_score * 0.7) + subscribers_score
  end

  def can_be_monitored_by_user?
    user_can_monitor? && follower_user&.healthy?
  end

  def update_activity_score!
    update!(activity_score: calculate_activity_score)
  end

  # Callback методы для state machine
  private

  def clear_join_errors(transition)
    update!(bot_join_error: nil, bot_join_at: nil)
  end

  def record_join_success(transition)
    update!(bot_join_at: Time.current, bot_join_error: nil)
    Rails.logger.info "Bot join completed successfully for channel #{username} (#{id})"
  end

  def record_join_failure(transition)
    update!(bot_join_error: @join_error_message || 'Unknown error')
    Rails.logger.error "Bot join failed for channel #{username} (#{id}): #{self.bot_join_error}"
  end

  def ensure_channel_active(transition)
    if active?
      true
    else
      Rails.logger.warn "Cannot join inactive channel #{username} (#{id})"
      false
    end
  end
end
