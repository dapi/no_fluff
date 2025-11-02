# Тесты для SettingsHandler
require 'test_helper'

class Telegram::CallbackHandlers::SettingsHandlerTest < ActiveSupport::TestCase
  include TelegramHelper

  def setup
    @bot = mock_telegram_bot
    @user = create_telegram_user
    @callback_data = 'settings'
    @payload = create_callback_update(
      data: @callback_data,
      chat_id: 12345,
      user_id: @user.id,
      message_id: 67890
    )
    @handler = Telegram::CallbackHandlers::SettingsHandler.new(@bot, @user, @callback_data, @payload)
  end

  test 'should be able to create SettingsHandler' do
    assert_not_nil @handler
    assert_equal @bot, @handler.instance_variable_get(:@bot)
    assert_equal @user, @handler.instance_variable_get(:@user)
    assert_equal @callback_data, @handler.instance_variable_get(:@callback_data)
    assert_equal @payload, @handler.instance_variable_get(:@payload)
  end

  test 'should implement call method' do
    assert @handler.respond_to?(:call)
  end

  test 'should handle different callback data' do
    different_data = 'settings:format'
    handler = Telegram::CallbackHandlers::SettingsHandler.new(@bot, @user, different_data, @payload)

    assert_equal different_data, handler.instance_variable_get(:@callback_data)
  end

  test 'should handle callback without message' do
    payload_without_message = create_callback_update(
      data: @callback_data,
      chat_id: 12345,
      user_id: @user.id
    )
    handler = Telegram::CallbackHandlers::SettingsHandler.new(@bot, @user, @callback_data, payload_without_message)

    assert_not_nil handler
    assert_equal @bot, handler.instance_variable_get(:@bot)
  end

  test 'should initialize with nil payload' do
    handler = Telegram::CallbackHandlers::SettingsHandler.new(@bot, @user, @callback_data, nil)

    assert_not_nil handler
    assert_equal @callback_data, handler.instance_variable_get(:@callback_data)
  end

  test 'should handle complex callback data' do
    complex_data = 'settings:filter:strictness:2'
    handler = Telegram::CallbackHandlers::SettingsHandler.new(@bot, @user, complex_data, @payload)

    assert_equal complex_data, handler.instance_variable_get(:@callback_data)
    assert_not_nil handler
  end

  test 'should accept different users' do
    admin_user = create_telegram_user(is_admin: true)
    handler = Telegram::CallbackHandlers::SettingsHandler.new(@bot, admin_user, @callback_data, @payload)

    assert_equal admin_user, handler.instance_variable_get(:@user)
  end

  test 'should handle empty callback data' do
    empty_data = ''
    handler = Telegram::CallbackHandlers::SettingsHandler.new(@bot, @user, empty_data, @payload)

    assert_equal empty_data, handler.instance_variable_get(:@callback_data)
  end
end
