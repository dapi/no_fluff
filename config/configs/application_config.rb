# frozen_string_literal: true

# Base class for application config classes
class ApplicationConfig < Anyway::Config
  config_name :no_fluff
  env_prefix :no_fluff

  attr_config :bot_token,
              :bot_username,
              :openai_api_key,
              :deepseek_api_key,
              :telegram_api_id,
              :telegram_api_hash,
              :session_encryption_key,
              :active_record_encryption_primary_key,
              :active_record_encryption_deterministic_key,
              :active_record_encryption_key_derivation_salt

  attr_config llm_default_model: 'deepseek-chat',
    host: 'localhost',
    protocol: 'https',
    public_port: '443',
    free_channels_limit: 10,
    max_daily_joins: 50,
    max_channels_per_user: 400,
    rate_limit_delay_between_requests: 2.seconds

  required :bot_token unless Rails.env.test?
  required :telegram_api_id, :telegram_api_hash unless Rails.env.test?
  required :active_record_encryption_primary_key,
           :active_record_encryption_deterministic_key,
           :active_record_encryption_key_derivation_salt unless Rails.env.test?

  def home_url
    if home_subdomain.present?
      "#{protocol}://#{home_subdomain}.#{host}:#{port_suffix}"
    else
      "#{protocol}://#{host}#{port_suffix}"
    end
  end

  def port_suffix
    return if public_port.blank?
    return if public_port.to_s == '80' && protocol == 'http'
    return if public_port.to_s == '443' && protocol == 'https'

    ":#{public_port}"
  end

  def bot_url
    TELEGRAM_LINK_PREFIX + bot_username
  end

  def bot_id
    bot_token.split(':').first
  end

  def default_url_options
    options = { host:, protocol: }
    unless (public_port.to_s == '80' && protocol == 'http') || (public_port.to_s == '443' && protocol == 'https')
      options.merge! port: public_port
    end
    options
  end

  def telegram_bot_link
    "https://t.me/#{bot_username}"
  end

  # Telegram API methods for follower users
  def telegram_api_credentials
    {
      api_id: telegram_api_id,
      api_hash: telegram_api_hash
    }
  end

  def telegram_api_configured?
    telegram_api_id.present? && telegram_api_hash.present?
  end

  def session_encryption_enabled?
    session_encryption_key.present?
  end

  def follower_user_limits
    {
      max_daily_joins: max_daily_joins,
      max_channels_per_user: max_channels_per_user
    }
  end

  def rate_limit_delay
    rate_limit_delay_between_requests
  end

  class << self
    # Make it possible to access a singleton config instance
    # via class methods (i.e., without explicitly calling `instance`)
    delegate_missing_to :instance

    private

    # Returns a singleton config instance
    def instance
      @instance ||= new
    end
  end
end
