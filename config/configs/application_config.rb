# frozen_string_literal: true

# Base class for application config classes
class ApplicationConfig < Anyway::Config
  config_name :no_fluff
  env_prefix :no_fluff

  attr_config :bot_token,
              :bot_username,
              :openai_api_key,
              :deepseek_api_key

  attr_config llm_default_model: 'deepseek-chat',
    host: 'localhost',
    protocol: 'https',
    public_port: '443'

  required :bot_token unless Rails.env.test?

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
