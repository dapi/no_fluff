# frozen_string_literal: true

Bugsnag.configure do |config|
  config.app_version = AppVersion.format('%M.%m.%p')
  config.notify_release_stages = %w[production staging]

  # Add context about the application
  config.add_metadata(:app, {
    name: 'Без Шелухи',
    environment: Rails.env,
    ruby_version: RUBY_VERSION,
    rails_version: Rails.version
  })
end
