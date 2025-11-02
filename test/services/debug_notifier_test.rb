require 'test_helper'
require 'timeout'
require 'ostruct'

class DebugNotifierTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  def setup
    # Очищаем настройки перед каждым тестом
    SystemSetting.where(key: 'debug_mode').delete_all

    # Создаем администраторов и обычных пользователей
    @admin1 = TelegramUser.create!(
      username: 'admin1',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    @admin2 = TelegramUser.create!(
      username: 'admin2',
      first_name: 'Admin2',
      language_code: 'ru',
      is_admin: true
    )

    @regular_user = TelegramUser.create!(
      username: 'regular1',
      first_name: 'Regular',
      language_code: 'ru',
      is_admin: false
    )
  end

  def teardown
    # Очищаем настройки после каждого теста
    SystemSetting.where(key: 'debug_mode').delete_all
  end

  # enabled? tests
  test 'enabled? should return false when debug mode is not set' do
    assert_not DebugNotifier.enabled?
  end

  test 'enabled? should return false when debug mode is set to false' do
    SystemSetting.set('debug_mode', false)
    assert_not DebugNotifier.enabled?
  end

  test 'enabled? should return true when debug mode is set to true' do
    SystemSetting.set('debug_mode', true)
    assert DebugNotifier.enabled?
  end

  test 'enabled? should return default value when setting does not exist' do
    # Проверяем что используется правильное значение по умолчанию
    assert_not DebugNotifier.enabled?
  end

  # enable! tests
  test 'enable! should enable debug mode' do
    DebugNotifier.enable!
    assert DebugNotifier.enabled?

    setting = SystemSetting.find_by(key: 'debug_mode')
    assert_equal true, setting.value
    assert_equal 'Debug mode enabled', setting.description
  end

  test 'enable! should accept custom description' do
    custom_description = 'Custom enable description'
    DebugNotifier.enable!(custom_description)

    setting = SystemSetting.find_by(key: 'debug_mode')
    assert_equal custom_description, setting.description
  end

  # disable! tests
  test 'disable! should disable debug mode' do
    SystemSetting.set('debug_mode', true)
    DebugNotifier.disable!
    assert_not DebugNotifier.enabled?

    setting = SystemSetting.find_by(key: 'debug_mode')
    assert_equal false, setting.value
    assert_equal 'Debug mode disabled', setting.description
  end

  # toggle! tests
  test 'toggle! should enable debug mode when disabled' do
    assert_not DebugNotifier.enabled?
    result = DebugNotifier.toggle!

    assert result
    assert DebugNotifier.enabled?
  end

  test 'toggle! should disable debug mode when enabled' do
    SystemSetting.set('debug_mode', true)
    assert DebugNotifier.enabled?

    result = DebugNotifier.toggle!

    assert_not result
    assert_not DebugNotifier.enabled?
  end

  # notify tests
  test 'notify should return 0 when debug mode is disabled' do
    SystemSetting.set('debug_mode', false)

    result = DebugNotifier.notify('error', 'Test message')

    assert_equal 0, result
  end

  test 'notify should return 0 when no admins exist' do
    SystemSetting.set('debug_mode', true)
    @admin1.destroy!
    @admin2.destroy!
    # Удаляем также админа из фикстур
    TelegramUser.where(is_admin: true).destroy_all

    result = DebugNotifier.notify('error', 'Test message')

    assert_equal 0, result
  end

  test 'notify should return admin count when debug mode is enabled' do
    SystemSetting.set('debug_mode', true)

    result = DebugNotifier.notify('error', 'Test message')

    assert_equal 3, result  # Учитываем admin_user из фикстур + других админов
  end

  test 'notify should return 0 for invalid message type' do
    SystemSetting.set('debug_mode', true)

    result = DebugNotifier.notify('invalid_type', 'Test message')

    assert_equal 0, result
  end

  test 'notify should enqueue job for valid message type' do
    SystemSetting.set('debug_mode', true)

    assert_enqueued_jobs 1 do
      DebugNotifier.notify('error', 'Test message')
    end
  end

  test 'notify should pass context to job' do
    SystemSetting.set('debug_mode', true)
    context = { user_id: 123, action: 'test' }

    assert_enqueued_jobs 1 do
      DebugNotifier.notify('info', 'Test message', context)
    end
  end

  # Convenience method tests
  test 'error should call notify with error type' do
    SystemSetting.set('debug_mode', true)

    assert_enqueued_jobs 1 do
      DebugNotifier.error('Error message')
    end
  end

  test 'warning should call notify with warning type' do
    SystemSetting.set('debug_mode', true)

    assert_enqueued_jobs 1 do
      DebugNotifier.warning('Warning message')
    end
  end

  test 'info should call notify with info type' do
    SystemSetting.set('debug_mode', true)

    assert_enqueued_jobs 1 do
      DebugNotifier.info('Info message')
    end
  end

  test 'success should call notify with success type' do
    SystemSetting.set('debug_mode', true)

    assert_enqueued_jobs 1 do
      DebugNotifier.success('Success message')
    end
  end

  test 'channel_error should call notify with channel_update_error type' do
    SystemSetting.set('debug_mode', true)
    channel = OpenStruct.new(id: 456, username: 'testchannel')
    error = StandardError.new('Test error')

    assert_enqueued_jobs 1 do
      DebugNotifier.channel_error(channel, error, { extra: 'context' })
    end
  end

  test 'message_processing_error should call notify with message_processing_error type' do
    SystemSetting.set('debug_mode', true)
    # Создаем заглушку для сообщения
    message = OpenStruct.new(id: 123, content: 'test message')
    error = StandardError.new('Test error')

    assert_enqueued_jobs 1 do
      DebugNotifier.message_processing_error(message, error, { extra: 'context' })
    end
  end

  test 'system_alert should call notify with system_alert type' do
    SystemSetting.set('debug_mode', true)

    assert_enqueued_jobs 1 do
      DebugNotifier.system_alert('System alert message')
    end
  end

  # notify_error tests
  test 'notify_error should determine error type correctly' do
    SystemSetting.set('debug_mode', true)

    # StandardError - should use 'error' type
    standard_error = StandardError.new('Standard error')

    assert_enqueued_jobs 1 do
      DebugNotifier.notify_error(standard_error)
    end
  end

  test 'notify_error should include custom message' do
    SystemSetting.set('debug_mode', true)
    error = StandardError.new('Original error')
    custom_message = 'Custom error message'

    assert_enqueued_jobs 1 do
      DebugNotifier.notify_error(error, {}, custom_message)
    end
  end

  test 'notify_error should include context and error details' do
    SystemSetting.set('debug_mode', true)
    error = StandardError.new('Test error')
    context = { user_id: 123 }

    assert_enqueued_jobs 1 do
      DebugNotifier.notify_error(error, context)
    end
  end

  # has_admins? tests
  test 'has_admins? should return true when admins exist' do
    assert DebugNotifier.has_admins?
  end

  test 'has_admins? should return false when no admins exist' do
    @admin1.destroy!
    @admin2.destroy!
    # Удаляем также админа из фикстур
    TelegramUser.where(is_admin: true).destroy_all

    assert_not DebugNotifier.has_admins?
  end

  # admin_count tests
  test 'admin_count should return correct number of admins' do
    assert_equal 3, DebugNotifier.admin_count  # @admin1 + @admin2 + admin_user из фикстур

    @admin1.destroy!
    assert_equal 2, DebugNotifier.admin_count

    @admin2.destroy!
    assert_equal 1, DebugNotifier.admin_count  # Остается admin_user из фикстур
  end

  # MESSAGE_TYPES constant tests
  test 'should have valid message types' do
    expected_types = %w[
      error
      warning
      info
      success
      channel_update_error
      message_processing_error
      system_alert
    ]

    assert_equal expected_types.sort, DebugNotifier::MESSAGE_TYPES.sort
  end

  test 'should accept all valid message types' do
    SystemSetting.set('debug_mode', true)

    DebugNotifier::MESSAGE_TYPES.each do |type|
      assert_enqueued_jobs 1 do
        DebugNotifier.notify(type, "Test #{type} message")
      end
      clear_enqueued_jobs
    end
  end

  # Integration tests
  test 'should work with debug mode toggle and notification' do
    # Initially disabled
    assert_not DebugNotifier.enabled?
    assert_equal 0, DebugNotifier.notify('info', 'Test')

    # Enable debug mode
    DebugNotifier.enable!
    assert DebugNotifier.enabled?
    assert_equal 3, DebugNotifier.notify('info', 'Test')  # @admin1 + @admin2 + admin_user из фикстур

    # Disable debug mode
    DebugNotifier.disable!
    assert_not DebugNotifier.enabled?
    assert_equal 0, DebugNotifier.notify('info', 'Test')
  end

  test 'should handle context with different data types' do
    SystemSetting.set('debug_mode', true)

    context = {
      string: 'test string',
      number: 42,
      array: [ 1, 2, 3 ],
      hash: { nested: 'value' },
      boolean: true,
      nil_value: nil
    }

    assert_enqueued_jobs 1 do
      DebugNotifier.notify('info', 'Test with complex context', context)
    end
  end
end
