# frozen_string_literal: true

# Mock module for telegram-mtproto-ruby gem testing
# This module provides mock classes to test MTProto functionality without real API calls
module TelegramMtproto
  class Client
    attr_reader :api_id, :api_hash, :phone_number

    def initialize(api_id:, api_hash:, phone_number:, session_string: nil)
      @api_id = api_id
      @api_hash = api_hash
      @phone_number = phone_number
      @session_string = session_string
      @connected = false
    end

    def connect
      @connected = true
    end

    def disconnect
      @connected = false
    end

    def restore_session(session_string)
      return false unless session_string
      @session_string = session_string
      true
    end

    def get_session_string
      @session_string
    end

    def send_code
      {
        success: true,
        phone_code_hash: "mock_phone_code_hash_#{rand(1000..9999)}"
      }
    end

    def sign_in(code:)
      if code == '12345' || code == '54321'
        {
          success: true,
          user: {
            id: rand(10000..99999),
            username: "mock_user_#{rand(100..999)}",
            first_name: 'Mock',
            last_name: 'User'
          }
        }
      else
        {
          success: false,
          error: 'PHONE_CODE_INVALID'
        }
      end
    end

    def get_me
      {
        success: true,
        user: {
          id: rand(10000..99999),
          username: "mock_user_#{rand(100..999)}",
          first_name: 'Mock',
          last_name: 'User'
        }
      }
    end

    def test_connection
      get_me
    end

    def join_chat(username)
      if username == 'privatechannel'
        {
          success: false,
          error: 'CHANNEL_PRIVATE'
        }
      else
        {
          success: true,
          chat: {
            id: rand(100000..999999),
            username: username,
            title: "Test #{username.titleize}",
            description: 'Test channel',
            participant_count: rand(100..1000),
            verified: true,
            access_hash: "mock_hash_#{rand(1000..9999)}"
          }
        }
      end
    end

    def leave_chat(username)
      {
        success: true
      }
    end

    def get_chat_info(username)
      if username == 'nonexistent'
        {
          success: false,
          error: 'USERNAME_NOT_OCCUPIED'
        }
      else
        {
          success: true,
          chat: {
            id: rand(100000..999999),
            username: username,
            title: "Test #{username.titleize}",
            description: 'Test channel',
            participant_count: rand(100..1000),
            verified: true,
            access_hash: "mock_hash_#{rand(1000..9999)}"
          }
        }
      end
    end

    def send_message(chat_id:, text:)
      {
        success: true,
        message_id: rand(100000..999999)
      }
    end
  end
end
