ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'active_job/test_helper'

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Отключаем параллельный запуск для тестов telegram-bot
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Используем транзакции для изоляции тестов
    setup do
      ActiveRecord::Base.connection.begin_transaction(joinable: false)
    end

    teardown do
      ActiveRecord::Base.connection.rollback_transaction
    end

    # Add more helper methods to be used by all tests here...
  end
end

# Добавляем ActiveJob::TestHelper для всех тестов
class ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
end
