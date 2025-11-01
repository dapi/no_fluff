class FollowerUser < ApplicationRecord
  # Encryption for sensitive data using Rails built-in encrypts
  # Uses ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY from environment
  encrypts :session_string_encrypted
  encrypts :api_credentials_encrypted

  # Include Telegram credentials functionality
  include TelegramCredentials

  # Associations
  has_many :channels, dependent: :nullify

  # Validations
  validates :phone_number, presence: true, uniqueness: true

  # Enums
  enum :auth_status, pending: 0, authorized: 1, failed: 2, banned: 3, revoked: 4

  # Scopes
  scope :authorized, -> { where(auth_status: :authorized) }
  scope :healthy, -> { where('health_score >= ?', 70.0) }
  scope :available_for_join, -> { authorized.healthy.where('channels_count < max_channels') }
  scope :by_priority, -> { order(priority: :desc, health_score: :desc) }
  scope :by_workload, -> { order(workload_score: :asc) }
  scope :active_recently, -> { where('last_activity_at > ?', 1.hour.ago) }

  # Callbacks
  before_save :update_workload_score, if: :channels_count_changed?
  before_save :reset_daily_counter_if_needed, if: :daily_joins_count_changed?

  # Public interface methods
  def needs_reauthorization?
    !session_active? || auth_status.in?(%w[failed banned revoked])
  end

  def session_active?
    last_authorized_at && last_authorized_at > 24.hours.ago
  end

  # Authorization methods
  def start_authorization!
    return false unless phone_number.present?
    return false if authorized? # Already authorized

    Telegram::AuthorizationService.instance.start_authorization(self)
  end

  def confirm_authorization!(code)
    return false if code.blank?

    result = Telegram::AuthorizationService.instance.confirm_authorization(self, code)
    return result unless result[:success]

    # Auto-assign channels after successful authorization
    auto_assign_channels
    result
  end

  def authorization_status
    return { status: :not_started } unless pending?

    Telegram::AuthorizationService.instance.authorization_status(self)
  end

  def needs_authorization?
    !authorized? && phone_number.present?
  end

  def can_start_authorization?
    needs_authorization? && !authorization_status&.dig(:in_progress)
  end

  def revoke_authorization!
    # Clean up session and update status
    clear_tdlib_session
    update!(
      auth_status: :revoked,
      last_authorized_at: nil,
      api_credentials: {},
      session_string: nil
    )

    # Remove from all channels
    channels.each do |channel|
      channel.unassign_from_follower_user
    end

    Rails.logger.info "Revoked authorization for #{phone_number}"
    true
  end

  # Helper methods for auth_status
  def pending?
    auth_status == 'pending'
  end

  def authorized?
    auth_status == 'authorized'
  end

  def failed?
    auth_status == 'failed'
  end

  def banned?
    auth_status == 'banned'
  end

  def revoked?
    auth_status == 'revoked'
  end

  # Instance methods

  def can_join_channel?
    authorized? &&
    healthy? &&
    channels_count < max_channels &&
    daily_joins_count < daily_joins_limit
  end

  def join_channel!
    return false unless can_join_channel?

    increment!(:daily_joins_count)
    increment!(:channels_count)
    touch(:last_activity_at)
  end

  def leave_channel!
    decrement!(:channels_count)
    touch(:last_activity_at)
  end

  def record_successful_join
    touch(:last_successful_join)
    decrement!(:consecutive_errors)
    update_health_score(5.0) # Improve health score
  end

  def record_failed_join(error_message = nil)
    increment!(:consecutive_errors)
    update_health_score(-2.0) # Decrease health score
    touch(:last_activity_at)

    # Update auth status if too many consecutive errors
    if consecutive_errors >= 5
      update!(auth_status: :failed)
    end
  end

  def healthy?
    health_score >= 50.0
  end

  def overloaded?
    workload_score >= 0.8
  end

  def reset_daily_counter
    update!(
      daily_joins_count: 0,
      last_reset_date: Date.current
    )
  end

  def device_info=(info)
    super(info || {})
  end

  def specialization_list
    specialization.to_s.split(',').map(&:strip).reject(&:blank?)
  end

  def update_health_score(delta)
    new_score = [ health_score + delta, 0.0, 100.0 ].sort[1]
    update!(health_score: new_score)
  end

  # Class methods
  def self.next_available
    available_for_join.by_priority.first
  end

  def self.reset_daily_counters_for_all
    where.not(last_reset_date: Date.current).update_all(
      daily_joins_count: 0,
      last_reset_date: Date.current
    )
  end

  private

  def auto_assign_channels
    # Find channels that need assignment and assign to this user
    channels_needing_assignment = Channel.needing_assignment.limit(5)

    channels_needing_assignment.each do |channel|
      if channel.assign_to_follower_user(self)
        Rails.logger.info "Auto-assigned channel #{channel.username} to authorized user #{phone_number}"
      end
    end
  end

  def update_workload_score
    return unless max_channels&.positive?

    # Calculate workload as ratio of current channels to max channels
    # Add daily join ratio consideration
    channel_ratio = channels_count.to_f / max_channels
    daily_ratio = daily_joins_count.to_f / daily_joins_limit

    # Weighted combination: 70% channel ratio, 30% daily ratio
    self.workload_score = (channel_ratio * 0.7) + (daily_ratio * 0.3)
  end

  def reset_daily_counter_if_needed
    return unless daily_joins_count_changed?

    if last_reset_date != Date.current
      self.daily_joins_count = 0
      self.last_reset_date = Date.current
    end
  end
end
