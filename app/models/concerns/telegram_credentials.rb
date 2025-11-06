# frozen_string_literal: true

module TelegramCredentials
  extend ActiveSupport::Concern

  # Provides methods to work with Telegram API credentials
  # Uses ApplicationConfig for default values and fallbacks

  class_methods do
    def default_api_credentials
      ApplicationConfig.telegram_api_credentials
    end

    delegate :telegram_api_configured?, to: :ApplicationConfig
  end

  def api_credentials
    return default_api_credentials unless respond_to?(:api_credentials_encrypted) && api_credentials_encrypted.present?

    begin
      # Rails automatically decrypts this field due to encrypts
      JSON.parse(api_credentials_encrypted)
    rescue JSON::ParserError
      default_api_credentials
    end
  end

  def api_credentials=(credentials)
    return unless respond_to?(:api_credentials_encrypted=)

    # Rails automatically encrypts this field
    self.api_credentials_encrypted = credentials.to_json
  end

  def session_string
    return nil unless respond_to?(:session_string_encrypted)

    # Rails automatically decrypts this field
    session_string_encrypted
  end

  def session_string=(session)
    return unless respond_to?(:session_string_encrypted=)

    # Rails automatically encrypts this field
    self.session_string_encrypted = session
  end

  def has_custom_credentials?
    respond_to?(:api_credentials_encrypted) && api_credentials_encrypted.present?
  end

  def has_session?
    respond_to?(:session_string_encrypted) && session_string_encrypted.present?
  end

  def has_valid_mtproto_session?
    return false unless has_session?

    begin
      session_data = JSON.parse(session_string)
      # Check if session has required fields for MTProto
      session_data.is_a?(Hash) &&
      (session_data.key?(:api_id) || session_data.key?('api_id')) &&
      (session_data.key?(:api_hash) || session_data.key?('api_hash')) &&
      (session_data.key?(:phone_number) || session_data.key?('phone_number'))
    rescue JSON::ParserError
      false
    end
  end

  def session_created_at
    return nil unless has_session?

    begin
      session_data = JSON.parse(session_string)
      created_at_value = session_data['created_at'] || session_data[:created_at]
      created_at_value ? Time.parse(created_at_value) : nil
    rescue JSON::ParserError, ArgumentError
      nil
    end
  end

  def session_expired?
    return true unless has_session?

    created_at = session_created_at
    return true unless created_at

    # Sessions expire after 24 hours
    created_at < 24.hours.ago
  end

  def refresh_session_if_needed
    if session_expired? || !has_valid_mtproto_session?
      clear_mtproto_session
      create_mtproto_session
    else
      restore_mtproto_session
    end
  end

  # MTProto session management methods
  def create_mtproto_session
    return nil unless self.class.telegram_api_configured?

    session_data = {
      api_id: api_credentials[:api_id],
      api_hash: api_credentials[:api_hash],
      phone_number: phone_number,
      created_at: Time.current
    }

    Rails.logger.info "Creating MTProto session for #{phone_number rescue 'unknown user'}"
    self.session_string = session_data.to_json
    session_data
  end

  def restore_mtproto_session
    return nil unless has_session?

    begin
      session_data = JSON.parse(session_string)
      Rails.logger.info "Restoring MTProto session for #{phone_number rescue 'unknown user'}"
      session_data
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse MTProto session data: #{e.message}"
      nil
    end
  end

  def save_mtproto_session(session_data)
    return false unless session_data.present?

    begin
      Rails.logger.info "Saving MTProto session for #{phone_number rescue 'unknown user'}"

      # If session_data is already a JSON string (from MTProto client), save it directly
      if session_data.is_a?(String)
        self.session_string = session_data
      else
        # If it's a hash, convert to JSON
        self.session_string = session_data.to_json
      end

      true
    rescue StandardError => e
      Rails.logger.error "Failed to save MTProto session: #{e.message}"
      false
    end
  end

  def clear_mtproto_session
    Rails.logger.info "Clearing MTProto session for #{phone_number rescue 'unknown user'}"
    self.session_string = nil
  end

  # Legacy TDLib methods (deprecated - use MTProto methods instead)
  def create_tdlib_session
    Rails.logger.warn 'create_tdlib_session is deprecated. Use create_mtproto_session instead.'
    create_mtproto_session
  end

  def restore_tdlib_session
    Rails.logger.warn 'restore_tdlib_session is deprecated. Use restore_mtproto_session instead.'
    restore_mtproto_session
  end

  def save_tdlib_session(session_data)
    Rails.logger.warn 'save_tdlib_session is deprecated. Use save_mtproto_session instead.'
    save_mtproto_session(session_data)
  end

  def clear_tdlib_session
    Rails.logger.warn 'clear_tdlib_session is deprecated. Use clear_mtproto_session instead.'
    clear_mtproto_session
  end

  private

  def default_api_credentials
    self.class.default_api_credentials
  end
end
