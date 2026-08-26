# frozen_string_literal: true

module Telegram
  # AuthorizationService - handles MTProto authorization for follower users
  # Manages authorization flow, code verification, and session management
  # Legacy compatibility service. New authorization uses AuthorizationServiceMtproto.
  class AuthorizationService
    include Singleton

    attr_reader :pending_authorizations

    def initialize
      @pending_authorizations = {}
    end

    # Start authorization process for follower user
    def start_authorization(follower_user)
      return { success: false, error: 'Invalid user' } unless follower_user.present?
      return { success: false, error: 'Already authorized' } if follower_user.authorized?

      auth_key = "auth_#{follower_user.id}"

      # Check if authorization already in progress
      return { success: false, error: 'Authorization already in progress' } if @pending_authorizations.key?(auth_key)

      # Create MTProto client and send code
      client = Telegram::UserClientMtproto.new(follower_user)

      result = client.send_code

      if result[:success]
        # Create new authorization session
        authorization = FollowerUserAuthorization.new(follower_user, result[:phone_code_hash])
        authorization.start! # Mark as in progress
        @pending_authorizations[auth_key] = authorization

        {
          success: true,
          phone_code_hash: result[:phone_code_hash],
          expires_at: authorization.expires_at
        }
      else
        result
      end
    rescue StandardError => e
      Rails.logger.error "Failed to start authorization: #{e.message}"
      { success: false, error: e.message }
    end

    # Confirm authorization with verification code
    def confirm_authorization(follower_user, code)
      return { success: false, error: 'Invalid verification code' } if code.blank?
      return { success: false, error: 'Invalid user' } unless follower_user.present?

      auth_key = "auth_#{follower_user.id}"
      authorization = @pending_authorizations[auth_key]

      return { success: false, error: 'Authorization not started' } unless authorization
      return { success: false, error: 'Authorization expired' } if authorization.expired?

      # Real MTProto verification
      client = Telegram::UserClientMtproto.new(follower_user)

      result = client.sign_in(code)

      if result[:success]
        # Clean up authorization
        @pending_authorizations.delete(auth_key)

        {
          success: true,
          user: follower_user
        }
      else
        {
          success: false,
          error: result[:error] || 'Invalid verification code'
        }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to confirm authorization: #{e.message}"
      { success: false, error: e.message }
    end

    # Get authorization status for follower user
    def authorization_status(follower_user)
      return nil unless follower_user.present?

      auth_key = "auth_#{follower_user.id}"
      authorization = @pending_authorizations[auth_key]

      return nil unless authorization

      if authorization.expired?
        @pending_authorizations.delete(auth_key)
        return nil
      end

      {
        in_progress: authorization.in_progress?,
        expires_at: authorization.expires_at,
        phone_code_hash: authorization.phone_code_hash
      }
    rescue StandardError => e
      Rails.logger.error "Failed to get authorization status: #{e.message}"
      nil
    end

    # Clean up authorization for follower user
    def cleanup_authorization(follower_user)
      return unless follower_user.present?

      auth_key = "auth_#{follower_user.id}"
      @pending_authorizations.delete(auth_key)

      # Reset follower user status if needed
      if follower_user.pending?
        follower_user.update(auth_status: 'failed')
      end
    end

    # Clean up all expired authorizations
    def cleanup_expired_authorizations
      expired_keys = []

      @pending_authorizations.each do |key, authorization|
        if authorization.expired?
          expired_keys << key
          # Update follower user status
          follower_user = authorization.follower_user
          follower_user.update(auth_status: 'failed') if follower_user.pending?
        end
      end

      expired_keys.each { |key| @pending_authorizations.delete(key) }
    end

    # Get authorization statistics
    def authorization_stats
      expired_count = 0
      in_progress_count = 0

      @pending_authorizations.each do |_, authorization|
        if authorization.expired?
          expired_count += 1
        elsif authorization.in_progress?
          in_progress_count += 1
        end
      end

      {
        pending: @pending_authorizations.size,
        in_progress: in_progress_count,
        expired: expired_count
      }
    end

    # Get all pending authorizations
    def pending_authorizations
      @pending_authorizations.dup
    end

    # Test authorization flow with real Telegram API
    def test_authorization(follower_user)
      return { success: false, error: 'Invalid user' } unless follower_user.present?

      client = Telegram::UserClientMtproto.new(follower_user)
      client.test_connection
    rescue StandardError => e
      Rails.logger.error "Authorization test failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # FollowerUserAuthorization - represents an authorization session
  class FollowerUserAuthorization
    attr_reader :follower_user, :created_at, :expires_at, :phone_code_hash

    def initialize(follower_user, phone_code_hash = nil)
      @follower_user = follower_user
      @created_at = Time.current
      @expires_at = @created_at + 10.minutes
      @phone_code_hash = phone_code_hash || "default_phone_code_hash_#{follower_user.id}"
      @in_progress = false
    end

    # Check if authorization is in progress
    def in_progress?
      @in_progress
    end

    # Mark authorization as in progress
    def start!
      @in_progress = true
    end

    # Check if authorization has expired
    def expired?
      Time.current > @expires_at
    end

    # Get time remaining until expiration (in seconds)
    def time_remaining
      remaining = @expires_at - Time.current
      remaining > 0 ? remaining.to_i : 0
    end

    # Get authorization progress percentage
    def progress_percentage
      total_time = 10.minutes
      elapsed = Time.current - @created_at
      progress = (elapsed.to_f / total_time.to_f) * 100
      [ progress, 100.0 ].min
    end
  end
end
