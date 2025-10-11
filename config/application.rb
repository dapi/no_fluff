require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module NoFluff
  class Application < Rails::Application
    # Configure the path for configuration classes that should be used before initialization
    # NOTE: path should be relative to the project root (Rails.root)
    config.anyway_config.autoload_static_config_path = "config/configs"
    #
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Fix for SolidQueueDashboard compatibility with Rails 8
    # Rails 8 removed config.assets, but the gem still tries to access it
    unless config.respond_to?(:assets)
      config.assets = ActiveSupport::OrderedOptions.new
      config.assets.paths = []
      config.assets.precompile = []
      config.assets.prefix = '/assets'
      config.assets.debug = false
      config.assets.quiet = false
      config.assets.compile = false
      config.assets.digest = true
      config.assets.js_compressor = nil
      config.assets.css_compressor = nil
      config.assets.version = '1.0'
      config.assets.cache_store = [ :file_store, Rails.root.join('tmp', 'cache', 'assets') ]
      config.assets.manifest = Rails.root.join('public', 'assets', 'manifest.json')
      config.assets.logger = Rails.logger
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Set default locale to Russian
    config.i18n.default_locale = :ru

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end
