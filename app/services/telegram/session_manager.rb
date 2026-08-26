# frozen_string_literal: true

module Telegram
  # SessionManager - handles Telegram session lifecycle management
  # Manages session persistence, restoration, and cleanup
  class SessionManager
    include Singleton

    attr_reader :active_sessions

    def initialize
      @active_sessions = {}
      @session_cache = {}
    end

    # Create or restore session for follower user
    def create_session(follower_user)
      return nil unless follower_user.present?

      session_key = session_key_for(follower_user)

      # Check if session already exists in cache
      if @session_cache[session_key]&.active?
        return @session_cache[session_key]
      end

      # Create new session
      session = TelegramSession.new(follower_user)
      @session_cache[session_key] = session
      @active_sessions[session_key] = session

      Rails.logger.info "Created Telegram session for #{follower_user.phone_number}"
      session
    end

    # Get active session for follower user
    def get_session(follower_user)
      return nil unless follower_user.present?

      session_key = session_key_for(follower_user)
      @session_cache[session_key]
    end

    # Remove session from active sessions
    def remove_session(follower_user)
      return unless follower_user.present?

      session_key = session_key_for(follower_user)
      session = @session_cache.delete(session_key)
      @active_sessions.delete(session_key)

      if session
        session.disconnect
        Rails.logger.info "Removed Telegram session for #{follower_user.phone_number}"
      end

      session
    end

    # Clean up inactive sessions
    def cleanup_inactive_sessions
      inactive_keys = []

      @session_cache.each do |key, session|
        unless session.active?
          inactive_keys << key
          session.disconnect
        end
      end

      inactive_keys.each do |key|
        @session_cache.delete(key)
        @active_sessions.delete(key)
      end

      Rails.logger.info "Cleaned up #{inactive_keys.size} inactive Telegram sessions" if inactive_keys.size > 0
    end

    # Get all active sessions
    def active_sessions_count
      @session_cache.values.count(&:active?)
    end

    # Check if user has active session
    def session_active?(follower_user)
      session = get_session(follower_user)
      session&.active? || false
    end

    # Get session status for user
    def session_status(follower_user)
      session = get_session(follower_user)

      if session.nil?
        :not_created
      elsif session.active?
        :active
      elsif session.connected?
        :connected
      else
        :inactive
      end
    end

    # Restore all sessions from database on startup
    def restore_persisted_sessions
      authorized_users = FollowerUser.authorized

      authorized_users.each do |user|
        if user.has_session?
          session = create_session(user)
          Rails.logger.info "Restored persisted session for #{user.phone_number}"
        end
      end

      Rails.logger.info "Restored #{authorized_users.count} persisted Telegram sessions"
    end

    # Force disconnect all sessions (for maintenance)
    def disconnect_all_sessions
      @session_cache.each_value(&:disconnect)
      Rails.logger.info 'Disconnected all Telegram sessions'
    end

    # Get session statistics
    def session_stats
      {
        total: @session_cache.size,
        active: active_sessions_count,
        connected: @session_cache.values.count(&:connected?),
        authorized: @session_cache.values.count(&:authorized?)
      }
    end

    private

    def session_key_for(follower_user)
      "telegram_session_#{follower_user.id}"
    end
  end

  # TelegramSession - represents a single Telegram user session
  class TelegramSession
    attr_reader :follower_user, :client, :created_at, :last_activity_at

    def initialize(follower_user)
      @follower_user = follower_user
      @client = nil
      @created_at = Time.current
      @last_activity_at = Time.current
      @active = false
      @authorized = false
    end

    def connect
      return false if @active

      @client = Telegram::UserClientMtproto.new(@follower_user)
      result = @client.connect

      if result
        @active = true
        @authorized = @client.authorized?
        @last_activity_at = Time.current
        Rails.logger.info "Connected Telegram session for #{@follower_user.phone_number}"
      end

      result
    rescue StandardError => e
      Rails.logger.error "Failed to connect Telegram session: #{e.message}"
      false
    end

    def disconnect
      return true unless @active

      @client&.disconnect
      @active = false
      @authorized = false
      @last_activity_at = Time.current

      Rails.logger.info "Disconnected Telegram session for #{@follower_user.phone_number}"
      true
    end

    def active?
      @active && @client&.connected?
    end

    def connected?
      @client&.connected? || false
    end

    def authorized?
      @authorized || @client&.authorized? || false
    end

    def client
      return nil unless @active

      @client
    end

    def touch
      @last_activity_at = Time.current
    end

    def idle_time
      Time.current - @last_activity_at
    end

    def expired?
      idle_time > 1.hour
    end

    # Delegate channel operations to client
    def join_channel(username)
      return false unless active?
      return false if username.blank?

      result = @client.join_channel(username)
      touch
      result
    end

    def leave_channel(username)
      return false unless active?
      return false if username.blank?

      result = @client.leave_channel(username)
      touch
      result
    end

    def get_channel_info(username)
      return nil unless active?
      return nil if username.blank?

      result = @client.get_channel_info(username)
      touch
      result
    end

    def test_connection
      return false unless connect

      result = @client.test_connection
      touch
      result
    ensure
      disconnect
    end
  end
end
