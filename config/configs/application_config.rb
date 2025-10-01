# frozen_string_literal: true

# Base class for application config classes
class ApplicationConfig < Anyway::Config
  config_name :no_fluff
  env_prefix :no_fluff

  attr_config :telegram_bot_token,
              :telegram_bot_username,
              :openai_api_key,
              :deepseek_api_key

  attr_config llm_default_model: "deepseek-chat"

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
