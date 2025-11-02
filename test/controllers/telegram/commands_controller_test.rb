# Тесты для Telegram::CommandsController
require 'test_helper'

class Telegram::CommandsControllerTest < ActionController::TestCase
  include TelegramHelper

  def setup
    @controller = Telegram::CommandsController.new
  end

  test 'should have start! method' do
    assert @controller.respond_to?(:start!)
  end

  test 'should have help! method' do
    assert @controller.respond_to?(:help!)
  end

  test 'should have settings! method' do
    assert @controller.respond_to?(:settings!)
  end

  test 'should have add! method' do
    assert @controller.respond_to?(:add!)
  end

  test 'should have remove! method' do
    assert @controller.respond_to?(:remove!)
  end

  test 'should have debug! method' do
    assert @controller.respond_to?(:debug!)
  end

  test 'should have set_commands! method' do
    assert @controller.respond_to?(:set_commands!)
  end

  test 'should have message method' do
    assert @controller.respond_to?(:message)
  end

  test 'should handle nil input gracefully' do
    # Test that methods don't crash with nil input
    assert_nothing_raised do
      @controller.instance_variable_set(:@bot, mock_telegram_bot)
      @controller.instance_variable_set(:@user, create_telegram_user)
      @controller.instance_variable_set(:@payload, create_message_update(text: '/test'))
    end
  end

  test 'should initialize with default attributes' do
    assert_not_nil @controller
    assert_respond_to @controller, :start!
    assert_respond_to @controller, :help!
    assert_respond_to @controller, :settings!
    assert_respond_to @controller, :add!
    assert_respond_to @controller, :remove!
    assert_respond_to @controller, :debug!
    assert_respond_to @controller, :set_commands!
    assert_respond_to @controller, :message
  end
end
