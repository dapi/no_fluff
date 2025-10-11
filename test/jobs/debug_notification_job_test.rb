require 'test_helper'

class DebugNotificationJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  def setup
    # Создаем администраторов
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

    # Создаем обычного пользователя
    @regular_user = TelegramUser.create!(
      username: 'regular1',
      first_name: 'Regular',
      language_code: 'ru',
      is_admin: false
    )

    # Включаем режим отладки
    SystemSetting.set('debug_mode', true)
  end

  def teardown
    SystemSetting.where(key: 'debug_mode').delete_all
  end

  # Basic job execution tests
  test 'should enqueue job with correct parameters' do
    assert_enqueued_with(job: DebugNotificationJob, args: [ 'error', 'Test message', { user_id: 123 } ]) do
      DebugNotificationJob.perform_later('error', 'Test message', { user_id: 123 })
    end
  end

  test 'should enqueue job' do
    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('error', 'Test message', {})
    end
  end

  test 'should enqueue job for different message types' do
    message_types = [ 'error', 'warning', 'info', 'success', 'channel_update_error', 'message_processing_error', 'system_alert' ]

    message_types.each do |type|
      assert_enqueued_jobs 1 do
        DebugNotificationJob.perform_later(type, "Test #{type} message", {})
      end
      clear_enqueued_jobs
    end
  end

  test 'should enqueue job with context' do
    context = { user_id: 123, action: 'test', channel_id: 456 }

    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('info', 'Test with context', context)
    end
  end

  test 'should handle empty context' do
    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('info', 'Test with empty context', {})
    end
  end

  test 'should handle nil context' do
    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('info', 'Test with nil context', nil)
    end
  end

  test 'should handle long messages' do
    long_message = 'a' * 1000

    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('error', long_message, {})
    end
  end

  test 'should handle complex context data' do
    complex_context = {
      string: 'test',
      number: 42,
      array: [ 1, 2, 3 ],
      hash: { nested: 'value', deep: { value: 123 } },
      boolean: true,
      nil_value: nil,
      timestamp: Time.current
    }

    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('info', 'Test with complex context', complex_context)
    end
  end

  test 'should handle unicode characters' do
    unicode_message = 'Тестовое сообщение с эмодзи 🚨 ⚠️ ℹ️ ✅'

    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('error', unicode_message, {})
    end
  end

  test 'should queue job with correct queue' do
    job = DebugNotificationJob.perform_later('error', 'Test message', {})
    assert_equal 'content', job.queue_name
  end

  test 'should handle multiple jobs for different admins' do
    # Создадим несколько задач для проверки
    assert_enqueued_jobs 3 do
      DebugNotificationJob.perform_later('error', 'Test message 1', {})
      DebugNotificationJob.perform_later('warning', 'Test message 2', {})
      DebugNotificationJob.perform_later('info', 'Test message 3', {})
    end
  end

  test 'should be retryable' do
    job = DebugNotificationJob.perform_later('error', 'Test message', {})
    # Проверяем что задача может быть выполнена (базовая проверка)
    assert_not_nil job.job_id
  end

  test 'should handle different message lengths' do
    messages = [
      'Short',
      'Medium length message with some content',
      'a' * 500,  # Long message
      'b' * 1000  # Very long message
    ]

    messages.each do |message|
      assert_enqueued_jobs 1 do
        DebugNotificationJob.perform_later('info', message, {})
      end
      clear_enqueued_jobs
    end
  end

  test 'should handle special characters in context' do
    special_context = {
      special_chars: '!@#$%^&*()_+-=[]{}|;:,.<>?',
      quotes: '"Single quotes" and "double quotes"',
      newlines: "Line 1\nLine 2\nLine 3",
      unicode: 'Тест 中文 🌟'
    }

    assert_enqueued_jobs 1 do
      DebugNotificationJob.perform_later('info', 'Test with special characters', special_context)
    end
  end
end
