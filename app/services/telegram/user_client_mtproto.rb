# frozen_string_literal: true

module Telegram
  # TelegramUserClientMtproto - MTProto 2.0 implementation
  # Real Telegram API integration using telegram-mtproto-ruby gem
  #
  # Replaces the mock implementation with actual MTProto functionality
  class UserClientMtproto
    include TelegramCredentials

    attr_reader :follower_user, :client, :api_credentials

    def initialize(follower_user)
      @follower_user = follower_user
      @api_credentials = @follower_user.api_credentials
      @client = nil
      @connected = false
      @authorized = false
    end

    def telegram_api_configured?
      ApplicationConfig.telegram_api_configured?
    end

    def create_client
      return false unless telegram_api_configured?

      begin
        @client = TelegramMtproto::Client.new(
          api_id: @api_credentials[:api_id],
          api_hash: @api_credentials[:api_hash],
          phone_number: @follower_user.phone_number,
          session_string: @follower_user.session_string
        )
        true
      rescue StandardError => e
        Rails.logger.error "Failed to create MTProto client: #{e.message}"
        false
      end
    end

    def connect
      return false unless create_client
      return true if @connected

      begin
        Rails.logger.info "Connecting MTProto client for #{@follower_user.phone_number}"

        # Initialize connection
        @client.connect

        # Check if we have existing session
        if @follower_user.has_session? && @client.restore_session(@follower_user.session_string)
          @authorized = true
          Rails.logger.info "Restored existing session for #{@follower_user.phone_number}"
        else
          Rails.logger.info "New session created for #{@follower_user.phone_number}"
        end

        @connected = true
        true
      rescue StandardError => e
        Rails.logger.error "Failed to connect MTProto client: #{e.message}"
        false
      end
    end

    def disconnect
      return true unless @client
      return true unless @connected

      begin
        Rails.logger.info "Disconnecting MTProto client for #{@follower_user.phone_number}"

        # Save session before disconnecting
        if @authorized
          session_data = @client.get_session_string
          @follower_user.session_string = session_data if session_data
        end

        @client.disconnect
        @connected = false
        @authorized = false
        @client = nil
        true
      rescue StandardError => e
        Rails.logger.error "Failed to disconnect MTProto client: #{e.message}"
        false
      end
    end

    # Authorization methods
    def send_code
      return { success: false, error: 'Connection failed' } unless connect
      return { success: false, error: 'Already authorized' } if @authorized

      begin
        result = @client.send_code

        if result[:success]
          {
            success: true,
            phone_code_hash: result[:phone_code_hash],
            expires_at: 10.minutes.from_now
          }
        else
          { success: false, error: result[:error] || 'Failed to send code' }
        end
      rescue StandardError => e
        Rails.logger.error "Failed to send verification code: #{e.message}"
        { success: false, error: e.message }
      end
    end

    def sign_in(code)
      return { success: false, error: 'Connection failed' } unless connect
      return { success: false, error: 'Already authorized' } if @authorized

      begin
        result = @client.sign_in(code: code)

        if result[:success]
          @authorized = true

          # Update follower user status
          @follower_user.update!(
            auth_status: 'authorized',
            last_authorized_at: Time.current,
            session_string: @client.get_session_string
          )

          {
            success: true,
            user: result[:user] || extract_user_info
          }
        else
          { success: false, error: result[:error] || 'Invalid verification code' }
        end
      rescue StandardError => e
        Rails.logger.error "Failed to sign in: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # Channel operations
    def join_channel(username)
      return { success: false, error: 'Username cannot be blank' } if username.blank?
      return { success: false, error: 'Client not connected' } unless client_connected?

      begin
        Rails.logger.info "Joining channel: #{username}"

        result = @client.join_chat(username)

        if result[:success]
          Rails.logger.info "Successfully joined channel: #{username}"
          {
            success: true,
            channel_info: extract_channel_info(result)
          }
        else
          error_message = "Failed to join channel: #{username}"
          Rails.logger.error error_message
          { success: false, error: result[:error] || error_message }
        end
      rescue StandardError => e
        Rails.logger.error "Error joining channel #{username}: #{e.message}"
        { success: false, error: e.message }
      end
    end

    def leave_channel(username)
      return { success: false, error: 'Username cannot be blank' } if username.blank?
      return { success: false, error: 'Client not connected' } unless client_connected?

      begin
        Rails.logger.info "Leaving channel: #{username}"

        result = @client.leave_chat(username)

        if result[:success]
          Rails.logger.info "Successfully left channel: #{username}"
          { success: true }
        else
          error_message = "Failed to leave channel: #{username}"
          Rails.logger.error error_message
          { success: false, error: result[:error] || error_message }
        end
      rescue StandardError => e
        Rails.logger.error "Error leaving channel #{username}: #{e.message}"
        { success: false, error: e.message }
      end
    end

    def get_channel_info(username)
      return nil unless client_connected?
      return nil if username.blank?

      begin
        Rails.logger.info "Getting channel info for: #{username}"

        result = @client.get_chat_info(username)

        if result[:success]
          extract_channel_info(result)
        else
          Rails.logger.error "Failed to get channel info: #{result[:error]}"
          nil
        end
      rescue StandardError => e
        Rails.logger.error "Error getting channel info for #{username}: #{e.message}"
        nil
      end
    end

    # Messaging
    def send_message(chat_id, text)
      return { success: false, error: 'Text cannot be blank' } if text.blank?
      return { success: false, error: 'Client not connected' } unless client_connected?

      begin
        result = @client.send_message(
          chat_id: chat_id,
          text: text
        )

        if result[:success]
          Rails.logger.info "Message sent successfully to #{chat_id}"
          { success: true, message_id: result[:message_id] }
        else
          Rails.logger.error "Failed to send message: #{result[:error]}"
          { success: false, error: result[:error] }
        end
      rescue StandardError => e
        Rails.logger.error "Error sending message: #{e.message}"
        { success: false, error: e.message }
      end
    end

    # Connection status
    def authorized?
      @authorized || @follower_user.authorized?
    end

    def connected?
      @connected && @client.present?
    end

    def test_connection
      return { success: false, error: 'Connection failed' } unless connect

      begin
        # Test by getting self info
        result = @client.get_me

        if result[:success]
          Rails.logger.info "Connection test successful for #{@follower_user.phone_number}"
          {
            success: true,
            user_info: {
              id: result[:user][:id],
              phone: @follower_user.phone_number,
              username: result[:user][:username],
              first_name: result[:user][:first_name],
              last_name: result[:user][:last_name]
            }
          }
        else
          Rails.logger.error "Connection test failed: #{result[:error]}"
          { success: false, error: result[:error] }
        end
      rescue StandardError => e
        Rails.logger.error "Connection test failed: #{e.message}"
        { success: false, error: e.message }
      end
    ensure
      disconnect unless authorized?
    end

    private

    def client_connected?
      connected? && @client.present?
    end

    def extract_user_info
      {
        id: @follower_user.id,
        phone: @follower_user.phone_number,
        username: @follower_user.username,
        first_name: @follower_user.first_name,
        last_name: @follower_user.last_name
      }
    end

    def extract_channel_info(result)
      channel = result[:chat] || result[:channel]
      return nil unless channel

      {
        id: channel[:id],
        username: channel[:username],
        title: channel[:title],
        description: channel[:description],
        member_count: channel[:participant_count] || channel[:member_count],
        type: channel[:type] || 'channel',
        verified: channel[:verified] || false,
        active: true,
        access_hash: channel[:access_hash]
      }
    end

    def handle_result(result)
      case result[:success]
      when true
        result
      when false
        handle_error(result[:error])
      end
    end

    def handle_error(error)
      Rails.logger.error "MTProto API error: #{error}"

      case error.to_s
      when /FLOOD_WAIT_(\d+)/
        wait_time = $1.to_i
        { success: false, error: 'Rate limit exceeded', retry_after: wait_time }
      when /CHANNEL_PRIVATE/
        { success: false, error: 'Channel is private or you were banned' }
      when /USERNAME_NOT_OCCUPIED/
        { success: false, error: 'Channel does not exist' }
      when /PHONE_CODE_INVALID/
        { success: false, error: 'Invalid verification code' }
      when /PHONE_NUMBER_INVALID/
        { success: false, error: 'Invalid phone number' }
      when /SESSION_PASSWORD_NEEDED/
        { success: false, error: 'Two-factor authentication required' }
      else
        { success: false, error: error.to_s }
      end
    end
  end
end
