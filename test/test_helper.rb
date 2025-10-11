ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# Configure Mocha for mocking and stubbing
require 'mocha/minitest'

module ActiveSupport
  class TestCase
    # Отключаем параллельный запуск для тестов telegram-bot
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # fixtures :all

    # Используем транзакции для изоляции тестов
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

module ActionDispatch
  class IntegrationTest
    # Отключаем fixtures для integration тестов
    # fixtures :all
  end
end
