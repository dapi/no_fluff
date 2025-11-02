ENV['RAILS_ENV'] ||= 'test'
# Set encryption credentials for test environment
ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] = 'test_key_for_encryption_32_chars_long'
ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY'] = 'test_deterministic_key_for_encryption_32_chars'
ENV['ACTIVE_RECORD_ENCRYPTION_KEY_SALT'] = 'test_key_salt_for_encryption'

require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'

# Configure Mocha for mocking and stubbing
require 'mocha/minitest'

# Configure Telegram bot for testing
Telegram.reset_bots
Telegram::Bot::ClientStub.stub_all!

# Configure default test bot
Telegram.bots_config = {
  default: 'test_token'
}

# Configure DatabaseRewinder
require 'database_rewinder'

# Initialize DatabaseRewinder
DatabaseRewinder.clean_all

# Load all support files before they are used
Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

module ActiveSupport
  class TestCase
    # Отключаем параллельный запуск для тестов telegram-bot
    # parallelize(workers: :number_of_processors)

    fixtures :all

    # Include support modules
    include TelegramHelper
    include MocksHelper
    include FactoryHelper
    include AssertionHelper

    # Use DatabaseRewinder for database cleaning
    teardown do
      DatabaseRewinder.clean
    end

    # Reset Telegram bot after each test
    teardown do
      Telegram.bot.reset if Telegram.bot.respond_to?(:reset)
      reset_all_mocks
    end

    # Add more helper methods to be used by all tests here...
  end
end
