require 'test_helper'

class Telegram::AdminAccessTest < ActionDispatch::IntegrationTest
  include TelegramHelper
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset if @bot
  end


  test 'admin user with is_admin: true can access protected commands' do
    admin_user = TelegramUser.create!(
      username: 'test_admin_user_new',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    # Mock a protected command (this would be in FollowerUserCommands)
    # We'll test the access logic directly
    controller = TelegramWebhookController.new
    controller.stubs(:current_user).returns(admin_user)

    # Для admin пользователь check_admin_access не должен бросать исключение
    # Он просто должен продолжить выполнение
    assert_nothing_raised do
      controller.send(:check_admin_access)
    end
  end

  test 'regular user with is_admin: false cannot access protected commands' do
    regular_user = TelegramUser.create!(
      username: 'regular_user',
      first_name: 'Regular',
      language_code: 'ru',
      is_admin: false
    )

    controller = TelegramWebhookController.new
    controller.stubs(:current_user).returns(regular_user)
    controller.stubs(:respond_with).returns(true)

    # This should return false when check_admin_access is called
    result = controller.send(:check_admin_access)
    assert_not result
  end

  test 'user with is_admin: false cannot access protected commands' do
    regular_user = TelegramUser.create!(
      username: 'nil_admin_user',
      first_name: 'User',
      language_code: 'ru',
      is_admin: false
    )

    controller = TelegramWebhookController.new
    controller.stubs(:current_user).returns(regular_user)
    controller.stubs(:respond_with).returns(true)

    # This should return false when check_admin_access is called
    result = controller.send(:check_admin_access)
    assert_not result
  end

  test 'check_admin_access sends appropriate error message for non-admin users' do
    regular_user = TelegramUser.create!(
      username: 'blocked_user',
      first_name: 'Blocked',
      language_code: 'ru',
      is_admin: false
    )

    # Mock the controller's respond_with method to capture the error message
    captured_message = nil
    controller = TelegramWebhookController.new
    controller.stubs(:current_user).returns(regular_user)
    controller.define_singleton_method(:respond_with) do |type, options = {}|
      captured_message = options[:text] if options[:text]
      throw :abort
    end

    # This should capture the error message
    controller.send(:check_admin_access) rescue nil

    assert_not_nil captured_message
    assert_includes captured_message, '🚫'
    assert_includes captured_message, 'Доступ'
  end

  test 'check_admin_access method exists and is callable' do
    controller = TelegramWebhookController.new
    # Проверяем, что метод существует в private методах
    assert controller.respond_to?(:check_admin_access, true)
  end

  test 'protected commands are correctly identified' do
    # Test that the protected commands list includes our follower user commands
    protected_commands = [
      :fadd!,
      :fconfirm!,
      :fremove!,
      :flist!
    ]

    protected_commands.each do |command|
      # Проверяем, что методы существуют в private методах
      assert TelegramWebhookController.new.respond_to?(command, true)
    end
  end

  test 'current_user is always available in Telegram webhook context' do
    # This test verifies the architectural decision that current_user always exists
    # In the real Telegram bot context, current_user should never be nil
    admin_user = TelegramUser.create!(
      username: 'current_user_test',
      first_name: 'Current',
      language_code: 'ru',
      is_admin: true
    )

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/start')
    send_webhook_update(update)

    assert_response :success
    # The controller should have processed the request without current_user being nil
  end
end
