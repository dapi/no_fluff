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

  # TDLib session management methods
  def create_tdlib_session
    return nil unless telegram_api_configured?

    # TODO: Implement actual TDLib session creation
    # This will be used when tdlib-ruby dependency conflicts are resolved
    Rails.logger.info "Creating TDLib session for #{phone_number rescue 'unknown user'}"
    nil
  end

  def restore_tdlib_session
    return nil unless has_session?

    # TODO: Implement actual TDLib session restoration
    Rails.logger.info "Restoring TDLib session for #{phone_number rescue 'unknown user'}"
    nil
  end

  def save_tdlib_session(session_data)
    return false unless session_data.present?

    # TODO: Implement actual TDLib session saving
    Rails.logger.info "Saving TDLib session for #{phone_number rescue 'unknown user'}"
    self.session_string = session_data.to_json
    true
  end

  def clear_tdlib_session
    # TODO: Implement actual TDLib session clearing
    Rails.logger.info "Clearing TDLib session for #{phone_number rescue 'unknown user'}"
    self.session_string = nil
  end

  private

  def default_api_credentials
    self.class.default_api_credentials
  end
end
