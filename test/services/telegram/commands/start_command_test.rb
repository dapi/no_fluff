# Упрощенные тесты для StartCommand
require 'test_helper'

class Telegram::Commands::StartCommandSimpleTest < ActiveSupport::TestCase
  include TelegramHelper

  def setup
    @bot = mock_telegram_bot
    @user = create_telegram_user(is_admin: false)
    @payload = create_message_update(text: '/start', chat_id: 12345, user_id: @user.id)
    @command = Telegram::Commands::StartCommand.new(@bot, @user, @payload)
  end

  test 'should be able to create StartCommand' do
    assert_not_nil @command
    assert_equal @bot, @command.instance_variable_get(:@bot)
    assert_equal @user, @command.instance_variable_get(:@user)
    assert_equal @payload, @command.instance_variable_get(:@payload)
  end

  test 'should implement call method' do
    assert @command.respond_to?(:call)
  end

  test 'should detect first user scenario' do
    TelegramUser.stubs(:any_admins?).returns(false)

    assert_equal true, @command.send(:first_user?)
  end

  test 'should detect regular user scenario' do
    TelegramUser.stubs(:any_admins?).returns(true)

    assert_equal false, @command.send(:first_user?)
  end

  test 'should create keyboard structure' do
    TelegramUser.stubs(:any_admins?).returns(true)

    keyboard = @command.send(:start_keyboard)
    assert_kind_of Hash, keyboard
    assert keyboard[:inline_keyboard].present?
    assert_equal 2, keyboard[:inline_keyboard].length
  end
end
