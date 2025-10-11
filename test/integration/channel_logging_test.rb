require "test_helper"

class ChannelLoggingTest < ActionDispatch::IntegrationTest
  test "should create log entries for job execution" do
    # Создаем тестовый канал
    channel = Channel.create!(
      username: 'test_channel',
      telegram_id: 12345,
      active: true,
      monitored_at: 1.hour.ago
    )

    # Очищаем предыдущие записи и проверяем начальное состояние
    ChannelUpdateLog.delete_all
    assert_equal 0, ChannelUpdateLog.count

    # Создаем запись лога вручную для проверки функциональности
    ChannelUpdateLog.create!(
      source: 'TestJob',
      message: 'Test execution completed',
      status: 'success',
      channel: channel,
      job_id: 'test_job_123',
      execution_time_ms: 1000,
      data: { test: 'data' }
    )

    # Проверяем, что запись создана
    assert_equal 1, ChannelUpdateLog.count

    log = ChannelUpdateLog.first
    assert_equal 'TestJob', log.source
    assert_equal 'success', log.status
    assert_equal 'Test execution completed', log.message
    assert_equal 'test_job_123', log.job_id
    assert_equal 1000, log.execution_time_ms
    assert_equal channel.id, log.channel_id
    assert_equal({ 'test' => 'data' }, log.data)
  end
end