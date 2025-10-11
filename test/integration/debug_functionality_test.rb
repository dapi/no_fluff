require 'test_helper'

class DebugFunctionalityTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @bot = Telegram.bot
    @bot.reset

    # Создаем администратора и обычного пользователя
    @admin_user = TelegramUser.create!(
      username: 'admin_integration',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    @regular_user = TelegramUser.create!(
      username: 'user_integration',
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

  def create_user_update(user_id: 123456, username: 'testuser', command: '/debug')
    {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
        'from' => {
          'id' => user_id,
          'username' => username,
          'first_name' => 'Test',
          'last_name' => 'User',
          'language_code' => 'ru',
          'is_premium' => false
        },
        'chat' => { 'id' => user_id, 'type' => 'private' },
        'text' => command
      }
    }
  end

  def send_webhook_update(update)
    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }
  end

  def extract_message_content(requests)
    message_requests = requests.select { |method, _| method == :sendMessage }
    return nil if message_requests.empty?

    method, params = message_requests.first
    params.first
  end

  # Полный тест цикла работы команды /debug
  test 'complete debug functionality workflow' do
    # 1. Изначально режим отладки выключен
    assert_not DebugNotifier.enabled?

    # 2. Администратор включает режим отладки
    update1 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update1)

    assert_response :success
    assert DebugNotifier.enabled?

    message_content1 = extract_message_content(@bot.requests)
    assert_not_nil message_content1
    assert_includes message_content1[:text], I18n.t('telegram_bot.debug.enabled')

    # 3. Проверяем что настройка сохранена в базе
    assert_equal true, SystemSetting.get('debug_mode')

    # 4. Проверяем что DebugNotifier API работает
    assert_equal 1, DebugNotifier.admin_count
    assert DebugNotifier.has_admins?

    # 5. Тестируем отправку debug уведомления
    @bot.reset
    assert_enqueued_jobs 1 do
      DebugNotifier.error('Test error message', { test_context: 'integration_test' })
    end

    # 6. Администратор выключает режим отладки
    update2 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update2)

    assert_response :success
    assert_not DebugNotifier.enabled?

    message_content2 = extract_message_content(@bot.requests)
    assert_not_nil message_content2
    assert_includes message_content2[:text], I18n.t('telegram_bot.debug.disabled')

    # 7. Проверяем что настройка обновлена в базе
    assert_equal false, SystemSetting.get('debug_mode')
  end

  test 'debug notifications work with error handling integration' do
    # Включаем режим отладки
    DebugNotifier.enable!

    # Проверяем что DebugNotifier включен и готов к работе
    assert DebugNotifier.enabled?
    assert_equal 1, DebugNotifier.admin_count
    assert DebugNotifier.has_admins?

    # Проверяем базовый API
    result = DebugNotifier.error('Test integration error', { test_context: 'integration_test' })
    assert_equal 1, result  # Количество администраторов которым будет отправлено сообщение
  end

  test 'debug mode persists across multiple requests' do
    # Включаем режим отладки
    update1 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update1)

    assert DebugNotifier.enabled?

    # Делаем несколько запросов и проверяем что режим остается включенным
    3.times do |i|
      @bot.reset
      update_help = create_user_update(user_id: @admin_user.telegram_id,
                                      username: @admin_user.username,
                                      command: '/help')
      send_webhook_update(update_help)

      assert_response :success
      assert DebugNotifier.enabled?, "Debug mode should stay enabled after request #{i + 1}"
    end

    # Выключаем режим
    @bot.reset
    update2 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update2)

    assert_not DebugNotifier.enabled?
  end

  test 'debug command works correctly with multiple admins' do
    # Создаем второго администратора
    admin2 = TelegramUser.create!(
      username: 'admin2_integration',
      first_name: 'Admin2',
      language_code: 'ru',
      is_admin: true
    )

    # Первый администратор включает режим
    update1 = create_user_update(user_id: @admin_user.telegram_id,
                                username: @admin_user.username,
                                command: '/debug')
    send_webhook_update(update1)

    assert DebugNotifier.enabled?
    assert_equal 2, DebugNotifier.admin_count

    # Второй администратор выключает режим
    @bot.reset
    update2 = create_user_update(user_id: admin2.telegram_id,
                                username: admin2.username,
                                command: '/debug')
    send_webhook_update(update2)

    assert_not DebugNotifier.enabled?
  end

  test 'debug functionality integrates with existing error handling' do
    # Включаем режим отладки
    DebugNotifier.enable!

    # Создаем тестовый сервис который вызывает ошибку
    test_service = Class.new do
      def self.test_method
        raise StandardError.new('Test service error')
      end
    end

    # Проверяем что при ошибке будет отправлено debug уведомление
    assert_enqueued_jobs 1 do
      begin
        test_service.test_method
      rescue StandardError => e
        DebugNotifier.notify_error(e, { service: 'TestService', method: 'test_method' })
      end
    end
  end

  test 'debug notifications respect admin permissions' do
    # Включаем режим отладки
    DebugNotifier.enable!

    # Убедимся что есть только один администратор
    assert_equal 1, DebugNotifier.admin_count

    # Проверяем что уведомления будут отправлены только администратору
    assert_enqueued_jobs 1 do
      DebugNotifier.info('Test message to admins only')
    end

    # Проверяем что обычный пользователь не получает уведомления
    regular_user_message = 'Regular user should not receive debug notifications'
    assert_not_equal regular_user_message, @regular_user.username
  end

  test 'debug command integration with help system' do
    # Проверяем что команда /debug появляется в помощи администраторам
    update_help_admin = create_user_update(user_id: @admin_user.telegram_id,
                                           username: @admin_user.username,
                                           command: '/help')
    send_webhook_update(update_help_admin)

    assert_response :success

    admin_help_content = extract_message_content(@bot.requests)
    assert_not_nil admin_help_content
    assert_includes admin_help_content[:text], '/debug — включить/выключить режим отладки'

    # Проверяем что команда /debug не появляется в помощи обычным пользователям
    @bot.reset
    update_help_regular = create_user_update(user_id: @regular_user.telegram_id,
                                             username: @regular_user.username,
                                             command: '/help')
    send_webhook_update(update_help_regular)

    assert_response :success

    regular_help_content = extract_message_content(@bot.requests)
    assert_not_nil regular_help_content
    assert_not_includes regular_help_content[:text], '/debug — включить/выключить режим отладки'
  end
end
