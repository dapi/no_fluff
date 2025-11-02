# Упрощенные тесты для ChannelCommand
require 'test_helper'

class Telegram::Commands::ChannelCommandSimpleTest < ActiveSupport::TestCase
  include TelegramHelper

  def setup
    @bot = mock_telegram_bot
    @user = create_telegram_user
    @payload = create_message_update(text: '/add', chat_id: 12345, user_id: @user.id)
  end

  test 'should be able to create ChannelCommand for add' do
    command = Telegram::Commands::ChannelCommand.new(@bot, @user, :add, '@testchannel')

    assert_not_nil command
    assert_equal :add, command.action
    assert_equal '@testchannel', command.channel_input
  end

  test 'should be able to create ChannelCommand for remove' do
    command = Telegram::Commands::ChannelCommand.new(@bot, @user, :remove, '@testchannel')

    assert_not_nil command
    assert_equal :remove, command.action
    assert_equal '@testchannel', command.channel_input
  end

  test 'should implement call method' do
    command = Telegram::Commands::ChannelCommand.new(@bot, @user, :add)
    assert command.respond_to?(:call)
  end

  test 'should have parse_username method' do
    command = Telegram::Commands::ChannelCommand.new(@bot, @user, :add, 'https://t.me/testchannel')
    assert command.respond_to?(:parse_username, true)
  end

  test 'should have valid_username method' do
    command = Telegram::Commands::ChannelCommand.new(@bot, @user, :remove)
    assert command.respond_to?(:valid_username?, true)
  end

  test 'should handle different input types' do
    add_command = Telegram::Commands::ChannelCommand.new(@bot, @user, :add, '@testchannel')
    remove_command = Telegram::Commands::ChannelCommand.new(@bot, @user, :remove, '@testchannel')

    assert_equal :add, add_command.action
    assert_equal :remove, remove_command.action
    assert_equal '@testchannel', add_command.channel_input
    assert_equal '@testchannel', remove_command.channel_input
  end
end
