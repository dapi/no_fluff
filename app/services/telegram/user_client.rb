# frozen_string_literal: true

module Telegram
  # TelegramUserClient - wrapper for telegram-mtproto-ruby functionality
  # Provides unified interface for Telegram user operations
  #
  # Uses telegram-mtproto-ruby for MTProto 2.0 protocol implementation
  class UserClient
    include TelegramCredentials

    attr_reader :follower_user, :client, :api_credentials

    def initialize(follower_user)
      @follower_user = follower_user
      @api_credentials = @follower_user.api_credentials
      @client = nil
    end

    def create_client
      # Ensure API is configured before proceeding
      raise 'Telegram API not configured. Please set api_id and api_hash in ApplicationConfig.' unless telegram_api_configured?

      @client = TelegramMtproto::Client.new(
        api_id: @api_credentials[:api_id],
        api_hash: @api_credentials[:api_hash],
        phone_number: @follower_user.phone_number,
        session_string: @follower_user.session_string
      )
      true
    end

    def connect
      return false unless create_client

      Rails.logger.info "Connecting Telegram client for #{@follower_user.phone_number}"

      # Connect to Telegram servers
      @client.connect
      true
    rescue StandardError => e
      Rails.logger.error "Failed to connect Telegram client: #{e.message}"
      false
    end

    def disconnect
      return true unless @client

      Rails.logger.info "Disconnecting Telegram client for #{@follower_user.phone_number}"

      # Disconnect from Telegram servers and save session
      @client.disconnect
      @client = nil
      true
    rescue StandardError => e
      Rails.logger.error "Failed to disconnect Telegram client: #{e.message}"
      @client = nil
      true
    end

    def join_channel(username)
      return false unless client_connected?
      return false if username.blank?

      Rails.logger.info "Attempting to join channel: #{username}"

      # Rate limiting
      rate_limit_delay

      # Join channel using MTProto API
      result = @client.join_chat(username)

      if result[:success]
        Rails.logger.info "Successfully joined channel: #{username}"
        { success: true, channel_info: result[:chat] }
      else
        error_message = result[:error] || "Failed to join channel: #{username}"
        Rails.logger.error error_message
        { success: false, error: error_message }
      end
    rescue StandardError => e
      Rails.logger.error "Error joining channel #{username}: #{e.message}"
      { success: false, error: e.message }
    end

    def leave_channel(username)
      return false unless client_connected?
      return false if username.blank?

      Rails.logger.info "Attempting to leave channel: #{username}"

      rate_limit_delay

      # Leave channel using MTProto API
      result = @client.leave_chat(username)

      if result[:success]
        Rails.logger.info "Successfully left channel: #{username}"
        { success: true }
      else
        error_message = result[:error] || "Failed to leave channel: #{username}"
        Rails.logger.error error_message
        { success: false, error: error_message }
      end
    rescue StandardError => e
      Rails.logger.error "Error leaving channel #{username}: #{e.message}"
      { success: false, error: e.message }
    end

    def test_connection
      return false unless connect

      # Test connection by getting self info
      result = @client.get_me

      if result[:success]
        Rails.logger.info "Connection test successful for #{@follower_user.phone_number}"
        {
          success: true,
          user_info: result[:user]
        }
      else
        error_message = result[:error] || 'Connection test failed'
        Rails.logger.error error_message
        { success: false, error: error_message }
      end
    rescue StandardError => e
      Rails.logger.error "Connection test failed: #{e.message}"
      { success: false, error: e.message }
    ensure
      disconnect
    end

    def get_channel_info(username)
      return nil unless client_connected?
      return nil if username.blank?

      Rails.logger.info "Getting channel info for: #{username}"

      rate_limit_delay

      # Get channel info using MTProto API
      result = @client.get_chat(username)

      if result[:success]
        result[:chat]
      else
        Rails.logger.error "Failed to get channel info for #{username}: #{result[:error]}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Error getting channel info for #{username}: #{e.message}"
      nil
    end

    def authorized?
      @client&.authorized? || @follower_user.authorized?
    end

    def connected?
      @client&.connected? || false
    end

    private

    def client_connected?
      @client.present? && (connected? || authorized?)
    end

    def rate_limit_delay
      delay = ApplicationConfig.rate_limit_delay
      sleep(delay) if delay > 0
    end

    def telegram_api_configured?
      ApplicationConfig.telegram_api_configured?
    end

    def handle_error(error)
      Rails.logger.error "Telegram MTProto API error: #{error}"

      case error.to_s
      when /FLOOD_WAIT/
        { success: false, error: 'Rate limit exceeded, please try again later', retry_after: 60 }
      when /CHANNEL_PRIVATE/
        { success: false, error: 'Channel is private or you were banned' }
      when /USERNAME_NOT_OCCUPIED/, /CHAT_ID_INVALID/
        { success: false, error: 'Channel does not exist' }
      when /PHONE_CODE_INVALID/
        { success: false, error: 'Invalid verification code' }
      when /PHONE_NUMBER_INVALID/
        { success: false, error: 'Invalid phone number' }
      when /SESSION_PASSWORD_NEEDED/
        { success: false, error: 'Two-factor authentication required' }
      when /AUTH_KEY_UNREGISTERED/
        { success: false, error: 'Session expired, please re-authorize' }
      else
        { success: false, error: error.to_s }
      end
    end
  end
end
