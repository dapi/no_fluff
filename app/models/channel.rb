class Channel < ApplicationRecord
  include ChannelUpdatable
  # Associations
  has_many :subscriptions, dependent: :destroy
  has_many :telegram_users, through: :subscriptions
  has_many :posts, dependent: :destroy

  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  # State Machine для управления процессом вступления бота в канал
  state_machine :bot_join_status, initial: :not_joined do
    # Состояния
    state :not_joined
    state :joining
    state :joined
    state :join_failed

    # Переходы
    event :start_joining do
      transition not_joined: :joining
      transition join_failed: :joining
      transition joined: :joining
    end

    event :complete_join do
      transition joining: :joined
    end

    event :fail_join do
      transition joining: :join_failed
      transition not_joined: :join_failed
    end

    # Callbacks
    before_transition on: :start_joining, do: :clear_join_errors
    after_transition on: :complete_join, do: :record_join_success
    after_transition on: :fail_join, do: :record_join_failure

    # Guards
    before_transition any => :joining, do: :ensure_channel_active
  end

  # Scopes
  scope :active, -> { where(deactivated_at: nil) }
  scope :inactive, -> { where.not(deactivated_at: nil) }
  scope :verified, -> { where(is_verified: true) }
  scope :by_subscribers, -> { order(subscribers_count: :desc) }
  scope :recently_updated, -> { where('last_post_at > ?', 24.hours.ago) }
  scope :needs_monitoring, -> { where('monitored_at IS NULL OR monitored_at < ?', 10.minutes.ago) }

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
    active? && joined?
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
