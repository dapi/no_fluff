# frozen_string_literal: true

module ChannelAccess
  extend ActiveSupport::Concern

  # Provides methods for managing channel access through follower users
  # Integrates with ApplicationConfig for rate limiting and limits

  included do
    # Callbacks
    after_create :check_assignment_needed
    after_update :check_reassignment_needed, if: :saved_change_to_user_access_status?
  end

  class_methods do
    def needing_assignment
      active.where(follower_user_id: nil)
    end

    def needing_reassignment
      active.joins(:follower_user)
            .where('channels.user_access_status IN (?) OR follower_users.auth_status IN (?)',
                   [ 'join_failed', 'access_lost' ],
                   [ 'failed', 'banned', 'revoked' ])
    end

    def available_for_assignment
      active.where(user_access_status: 'not_joined')
    end
  end

  def assign_to_follower_user(follower_user = nil)
    follower_user ||= FollowerUser.next_available

    return false unless follower_user.present? && follower_user.can_join_channel?
    return false unless active?

    transaction do
      update!(
        follower_user: follower_user,
        assignment_status: 'assigned',
        assigned_at: Time.current,
        user_access_status: 'joining'
      )

      follower_user.join_channel!
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to assign channel #{username} to follower user: #{e.message}"
    false
  end

  def unassign_from_follower_user
    return unless follower_user.present?

    transaction do
      follower_user.leave_channel!

      update!(
        follower_user: nil,
        assignment_status: 'unassigned',
        user_access_status: 'not_joined',
        assigned_at: nil
      )
    end
  rescue StandardError => e
    Rails.logger.error "Failed to unassign channel #{username}: #{e.message}"
    false
  end

  def mark_user_join_success
    transaction do
      update!(
        user_access_status: 'joined',
        last_activity_at: Time.current,
        activity_score: calculate_activity_score
      )

      follower_user&.record_successful_join
    end
  end

  def mark_user_join_failed(error_message = nil)
    transaction do
      update!(
        user_access_status: 'join_failed',
        last_activity_at: Time.current
      )

      follower_user&.record_failed_join(error_message)
    end
  end

  def mark_user_access_lost
    transaction do
      update!(
        user_access_status: 'access_lost',
        assignment_status: 'reassigning',
        last_activity_at: Time.current
      )
    end
  end

  def needs_user_assignment?
    follower_user.blank? && active?
  end

  def needs_user_reassignment?
    return false unless follower_user.present?

    follower_user.needs_reauthorization? ||
    !follower_user.can_join_channel? ||
    user_access_status.in?([ 'join_failed', 'access_lost' ])
  end

  def can_be_monitored_by_user?
    user_can_monitor? && follower_user&.healthy?
  end

  delegate :rate_limit_delay, to: :ApplicationConfig

  private

  def check_assignment_needed
    # This will be handled by background jobs in Phase 1
    # For now, we just mark that assignment is needed
    Rails.logger.info "Channel #{username} created and needs follower user assignment"
  end

  def check_reassignment_needed
    if needs_user_reassignment?
      Rails.logger.info "Channel #{username} needs follower user reassignment"
      # This will trigger background job in Phase 1
    end
  end
end
