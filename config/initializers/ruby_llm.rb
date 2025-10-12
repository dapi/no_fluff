# Не настраиваем RubyLLM в тестах
RubyLLM.configure do |config|
  unless Rails.env.test? || ENV.key?('SECRET_KEY_BASE_DUMMY')
    config.openai_api_key = ApplicationConfig.openai_api_key
    config.deepseek_api_key = ApplicationConfig.deepseek_api_key
    config.default_model = ApplicationConfig.llm_default_model
    # config.default_model = "gpt-4.1-nano"
  end

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
