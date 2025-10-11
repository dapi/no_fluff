require 'test_helper'
require 'benchmark'

class ChannelDeactivationPerformanceTest < ActiveSupport::TestCase
  setup do
    @bot = Telegram.bot
    @service = Telegram::ChannelService.new(@bot)

    # Создаем канал
    @channel = Channel.create!(
      telegram_id: 8001,
      username: 'performance_channel',
      title: 'Performance Test Channel',
      active: true
    )

    # Настраиваем быстрые моки для производительности
    setup_fast_mocks
  end

  teardown do
    # Очищаем созданных пользователей после тестов
    Subscription.where(channel: @channel).destroy_all
    TelegramUser.where('telegram_id > 10000').destroy_all
  end

  test 'performance with 1000 subscribers' do
    create_subscribers(1000)

    # Измеряем время выполнения
    time = Benchmark.measure do
      ChannelDeactivationNotificationJob.perform_now(@channel, reason: 'admin_decision')


 end

    # Проверяем что выполняется за приемлемое время (менее 30 секунд)
    assert time.real < 30, "Processing 1000 subscribers took too long: #{time.real}s"
    Rails.logger.info "Processed 1000 subscribers in #{time.real}s"
  end

  test 'performance with 5000 subscribers' do
    create_subscribers(5000)

    time = Benchmark.measure do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end

    # Для большего объема допустимо больше времени (менее 120 секунд)
    assert time.real < 120, "Processing 5000 subscribers took too long: #{time.real}s"
    Rails.logger.info "Processed 5000 subscribers in #{time.real}s"
  end

  test 'memory usage with large subscriber count' do
    create_subscribers(2000)

    # Измеряем память до выполнения
    GC.start
    memory_before = `ps -o rss= -p #{Process.pid}`.to_i

    # Выполняем задачу
    ChannelDeactivationNotificationJob.perform_now(@channel)

    # Измеряем память после выполнения
    GC.start
    memory_after = `ps -o rss= -p #{Process.pid}`.to_i
    memory_increase = memory_after - memory_before

    # Проверяем что память не выросла слишком сильно (менее 100MB)
    assert memory_increase < 102_400, "Memory increased too much: #{memory_increase}KB"
    Rails.logger.info "Memory increase for 2000 subscribers: #{memory_increase}KB"
  end

  test 'batch processing efficiency' do
    create_subscribers(3000)

    # Проверяем что find_each используется для пакетной обработки
    batches_processed = 0
    Subscription.where(channel: @channel).active.expects(:find_each).yields.at_least(50.times # 3000/60 = 50 батчей по умолчанию
    .multiple_times

    # Мокаем отправку сообщений
    @notification_service.expects(:send_channel_deactivation_notification)
      .at_least(3000.times
    .returns({ success: true })

    ChannelDeactivationNotificationJob.perform_now(@channel)
  end

  test 'rate limiting compliance' do
    create_subscribers(100)

    # Замеряем интервалы между отправками
    send_times = []

    @bot.expects(:send_message).at_least(100.times.with do
      send_times << Time.current
      { 'ok' => true }
    end

    ChannelDeactivationNotificationJob.perform_now(@channel)

    # Проверяем что есть задержки после каждых 10 сообщений
    if send_times.size >= 20
      # Проверяем задержку между 10-м и 11-м сообщением
      delay = send_times[10] - send_times[9]
      assert delay >= 0.1, "Rate limiting delay not applied: #{delay}s"
    end
  end

  test 'error handling performance' do
    create_subscribers(1000)

    # Мокаем ошибки для 10% пользователей
    error_users = (1..100).step(10).to_a

    @notification_service.stubs(:send_channel_deactivation_notification)
      .returns({ success: true })
      .then.returns({ success: false, error: 'Simulated error' })
      .then.returns({ success: true })
      .multiple_times

    time = Benchmark.measure do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end

    # Ошибки не должны значительно замедлять обработку
    assert time.real < 35, "Error handling took too long: #{time.real}s"
    Rails.logger.info "Processed 1000 subscribers with errors in #{time.real}s"
  end

  test 'concurrent processing capability' do
    create_subscribers(500)

    # Создаем несколько каналов для конкурентной обработки
    channels = []
    3.times do |i|
      channel = Channel.create!(
        telegram_id: 8002 + i,
        username: "concurrent_channel_#{i}",
        title: "Concurrent Channel #{i}",
        active: false
      )

      # Добавляем те же подписчиков к каждому каналу
      @channel.subscriptions.active.each do |sub|
        Subscription.create!(
          telegram_user: sub.telegram_user,
          channel: channel,
          active: true
        )
      end

      channels << channel
    end

    # Измеряем время параллельной обработки
    time = Benchmark.measure do
      threads = channels.map do |channel|
        Thread.new do
          ChannelDeactivationNotificationJob.perform_now(channel)
        end
      end

      threads.each(&:join)
    end

    # Параллельная обработка должна быть эффективнее последовательной
    assert time.real < 60, "Concurrent processing took too long: #{time.real}s"
    Rails.logger.info "Processed 3 channels concurrently in #{time.real}s"
  end

  test 'database query optimization' do
    create_subscribers(1000)

    # Проверяем что используется includes для предзагрузки telegram_user
    Subscription.expects(:includes).with(:telegram_user).returns(Subscription.none)
    ChannelDeactivationNotificationJob.perform_now(@channel)
  end

  private

  def create_subscribers(count)
    Rails.logger.info "Creating #{count} test subscribers..."

    # Создаем пользователей пачками для производительности
    users = []
    count.times do |i|
      users << {
        telegram_id: 10001 + i,
        username: "perf_user_#{i}",
        first_name: "Performance User #{i}",
        chat_id: 20001 + i,
        language_code: 'ru',
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # Массовая вставка пользователей
    TelegramUser.insert_all(users)

    # Создаем подписки пачками
    subscriptions = []
    count.times do |i|
      subscriptions << {
        telegram_user_id: 10001 + i,
        channel_id: @channel.id,
        priority: 5,
        active: true,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    Subscription.insert_all(subscriptions)
    Rails.logger.info "Created #{count} subscribers"
  end

  def setup_fast_mocks
    # Создаем сервис уведомлений один раз для всех тестов
    @notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.stubs(:new).returns(@notification_service)

    # По умолчанию все уведомления успешные
    @notification_service.stubs(:send_channel_deactivation_notification)
      .returns({ success: true })

    @notification_service.stubs(:send_admin_deactivation_notification)
      .returns({ success: true })

    # Отключаем логирование для производительности
    Rails.logger.stubs(:info)
    Rails.logger.stubs(:warn)
    Rails.logger.stubs(:error)

    # Отключаем admin_chat_id
    ApplicationConfig.stubs(:admin_chat_id).returns(nil)
  end
end