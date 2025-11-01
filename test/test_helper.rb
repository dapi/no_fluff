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

module ActiveSupport
  class TestCase
    # Отключаем параллельный запуск для тестов telegram-bot
    # parallelize(workers: :number_of_processors)

    fixtures :all

    # Отключаем транзакции для тестов deploy notification
    setup do
      if ActiveRecord::Base.connection.respond_to?(:begin_transaction)
        ActiveRecord::Base.connection.begin_transaction(joinable: false)
      end
    end

    teardown do
      if ActiveRecord::Base.connection.respond_to?(:rollback_transaction) &&
          ActiveRecord::Base.connection.current_transaction.open?
        ActiveRecord::Base.connection.rollback_transaction
      end
    end

    # Add more helper methods to be used by all tests here...
  end
end
