require 'test_helper'

class TelegramDebugCommandTest < ActionDispatch::IntegrationTest
  include TelegramHelper
  setup do
    @bot = Telegram.bot
    @bot.reset

    # Создаем администратора
    @admin_user = TelegramUser.create!(
      username: 'admin_debug',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    # Создаем обычного пользователя
    @regular_user = TelegramUser.create!(
      username: 'user_debug',
      first_name: 'User',
      language_code: 'ru',
      is_admin: false
    )

    # Очищаем настройки
    SystemSetting.where(key: 'debug_mode').delete_all
  end

  teardown do
    @bot.reset if @bot
    SystemSetting.where(key: 'debug_mode').delete_all
  end


  # Access control tests
  test 'should allow admin to use debug command' do
    update = create_user_update(user_id: @admin_user.telegram_id,
                               username: @admin_user.username,
                               command: '/debug')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.debug.enabled')
  end

  test 'should deny access to regular users' do
    update = create_user_update(user_id: @regular_user.telegram_id,
                               username: @regular_user.username,
                               command: '/debug')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.debug.access_denied')
  end

  test 'should handle unknown user gracefully' do
    unknown_telegram_id = 999999
    update = create_user_update(user_id: unknown_telegram_id,
                               username: 'unknown_user',
                               command: '/debug')
    send_webhook_update(update)

    assert_response :success

    # Пользователь будет создан автоматически, но не будет админом
    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.debug.access_denied')
  end

  # Debug mode toggle tests
  test 'should enable debug mode when disabled' do
    # Убедимся что режим отладки выключен
    assert_not DebugNotifier.enabled?

    update = create_user_update(user_id: @admin_user.telegram_id,
                               username: @admin_user.username,
                               command: '/debug')
    send_webhook_update(update)

    assert_response :success
    assert DebugNotifier.enabled?

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.debug.enabled')
  end

  test 'should disable debug mode when enabled' do
    # Включаем режим отладки
    DebugNotifier.enable!

    assert DebugNotifier.enabled?

    update = create_user_update(user_id: @admin_user.telegram_id,
                               username: @admin_user.username,
                               command: '/debug')
    send_webhook_update(update)

    assert_response :success
    assert_not DebugNotifier.enabled?

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.debug.disabled')
  end

  test 'should toggle debug mode multiple times' do
    # Изначально выключен
    assert_not DebugNotifier.enabled?

    # Включаем
    update1 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update1)
    assert_response :success
    assert DebugNotifier.enabled?

    # Выключаем
    @bot.reset
    update2 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update2)
    assert_response :success
    assert_not DebugNotifier.enabled?

    # Снова включаем
    @bot.reset
    update3 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update3)
    assert_response :success
    assert DebugNotifier.enabled?
  end

  # Multiple admins tests
  test 'should work with multiple admins' do
    # Создаем второго администратора
    admin2 = TelegramUser.create!(
      username: 'admin2_debug',
      first_name: 'Admin2',
      language_code: 'ru',
      is_admin: true
    )

    # Первый администратор включает режим
    update1 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update1)
    assert_response :success
    assert DebugNotifier.enabled?

    # Второй администратор тоже может использовать команду
    @bot.reset
    update2 = create_user_update(user_id: admin2.telegram_id,
                                username: admin2.username,
                                command: '/debug')
    send_webhook_update(update2)
    assert_response :success
    assert_not DebugNotifier.enabled?
  end

  # Integration tests
  test 'should integrate with SystemSetting correctly' do
    # Проверяем что системная настройка действительно меняется
    assert_nil SystemSetting.get('debug_mode')

    update = create_user_update(user_id: @admin_user.telegram_id,
                               username: @admin_user.username,
                               command: '/debug')
    send_webhook_update(update)

    assert_response :success
    assert_equal true, SystemSetting.get('debug_mode')
  end

  test 'should work with DebugNotifier API' do
    # Проверяем что наш API работает с реальной настройкой
    assert_not DebugNotifier.enabled?

    update = create_user_update(user_id: @admin_user.telegram_id,
                               username: @admin_user.username,
                               command: '/debug')
    send_webhook_update(update)

    assert_response :success
    assert DebugNotifier.enabled?
    assert_equal TelegramUser.where(is_admin: true).count, DebugNotifier.admin_count
  end

  # Command format tests
  test 'should handle debug command with spaces' do
    update = create_user_update(user_id: @admin_user.telegram_id,
                               username: @admin_user.username,
                               command: '/debug   ')  # Дополнительные пробелы
    send_webhook_update(update)

    assert_response :success
    assert DebugNotifier.enabled?
  end

  test 'should show debug command in admin help' do
    update = create_user_update(user_id: @admin_user.telegram_id,
                               username: @admin_user.username,
                               command: '/help')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], '/debug — включить/выключить режим отладки'
  end

  test 'should not show debug command in regular user help' do
    update = create_user_update(user_id: @regular_user.telegram_id,
                               username: @regular_user.username,
                               command: '/help')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_not_includes message_content[:text], '/debug — включить/выключить режим отладки'
  end
end
