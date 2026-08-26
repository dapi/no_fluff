# frozen_string_literal: true

module Telegram
  class AuthorizationServiceMtproto
    include Singleton

    attr_writer :client_factory

    def initialize
      @client_factory = ->(follower_user) { UserClientMtproto.new(follower_user) }
    end

    def start_authorization(follower_user)
      return failure('Invalid user') unless follower_user
      return failure('Already authorized') if follower_user.authorized?
      return failure('Authorization already in progress') if pending?(follower_user)

      result = client_for(follower_user).send_code
      return result unless result[:success]

      follower_user.update!(auth_status: :pending, pending_phone_code_hash: result.fetch(:phone_code_hash),
                            pending_session_string: result.fetch(:session), authorization_expires_at: result.fetch(:expires_at))
      { success: true, expires_at: follower_user.authorization_expires_at }
    rescue StandardError => e
      Rails.logger.warn("Telegram authorization start failed: #{e.class}")
      failure('Telegram authorization request failed')
    end

    def confirm_authorization(follower_user, code)
      return failure('Invalid verification code') if code.blank?
      return failure('Invalid user') unless follower_user
      return failure('Authorization not started') unless pending?(follower_user)
      return expire(follower_user) if expired?(follower_user)

      result = client_for(follower_user).confirm_code(code:, phone_code_hash: follower_user.pending_phone_code_hash, session: follower_user.pending_session_string)
      return result unless result[:success]

      follower_user.update!(auth_status: :authorized, last_authorized_at: Time.current, session_string: result.fetch(:session),
                            pending_phone_code_hash: nil, pending_session_string: nil, authorization_expires_at: nil)
      { success: true, user: follower_user }
    rescue StandardError => e
      Rails.logger.warn("Telegram authorization confirmation failed: #{e.class}")
      failure('Telegram authorization request failed')
    end

    def authorization_status(follower_user)
      return nil unless follower_user && pending?(follower_user)
      return expire(follower_user) && nil if expired?(follower_user)

      { in_progress: true, expires_at: follower_user.authorization_expires_at }
    end

    def cleanup_authorization(follower_user)
      return unless follower_user
      return unless pending?(follower_user)

      follower_user.update!(pending_phone_code_hash: nil, pending_session_string: nil, authorization_expires_at: nil, auth_status: :failed)
    end

    private

    def client_for(follower_user) = @client_factory.call(follower_user)
    def pending?(follower_user) = follower_user.pending_phone_code_hash.present? && follower_user.pending_session_string.present?
    def expired?(follower_user) = follower_user.authorization_expires_at.blank? || follower_user.authorization_expires_at.past?
    def failure(message) = { success: false, error: message }

    def expire(follower_user)
      cleanup_authorization(follower_user)
      failure('Authorization expired')
    end
  end
end
