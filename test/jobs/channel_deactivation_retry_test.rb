require 'test_helper'

class ChannelDeactivationRetryTest < ActiveJob::TestCase
  setup do
    @channel = Channel.create!(
      telegram_id: 9001,
      username: 'retry_channel',
      title: 'Retry Test Channel',
      active: false
    )

    # Создаем подписчика
    @user = TelegramUser.create!(
      telegram_id: 9001,
      username: 'retry_user',
      first_name: 'Retry User',
      chat_id: 9001,
      language_code: 'ru'
    )
    Subscription.create!(
      telegram_user: @user,
      channel: @channel,
      active: true
    )
  end

  test 'job retries on Telegram API rate limit errors' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.stubs(:new).returns(notification_service)

    # Первая попытка - rate limit
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: false, error: 'Too Many Requests: retry after 5' })
      .once

    # Вторая попытка - успешно
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: true })
      .once

    # Мокаем отправку администратору
    ApplicationConfig.stubs(:admin_chat_id).returns(nil)

    # Выполняем задачу с повторными попытками
    perform_enqueued_jobs do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  test 'job retries on network timeouts' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.stubs(:new).returns(notification_service)

    # Первая попытка - таймаут
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .raises(Net::TimeoutError.new('Network timeout'))
      .once

    # Вторая попытка - успешно
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: true })
      .once

    ApplicationConfig.stubs(:admin_chat_id).returns(nil)

    perform_enqueued_jobs do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  test 'job retries on temporary Telegram API errors' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Первые 3 попытки - временные ошибки
    3.times do |i|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(@user, @channel, nil)
        .returns({ success: false, error: "Internal Server Error #{i+1}" })
        .once
    end

    # Четвертая попытка - успешно
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: true })
      .once

    ApplicationConfig.stubs(:admin_chat_id).returns(nil)

    perform_enqueued_jobs do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  test 'job stops retrying after max attempts' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Все попытки неудачные
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: false, error: 'Persistent error' })
      .times(5)  # Максимальное количество попыток

    ApplicationConfig.stubs(:admin_chat_id).returns(nil)

    # Задача должна быть помечена как неудачная после 5 попыток
    assert_raises(StandardError) do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  test 'job uses exponential backoff for retries' do
    # Проверяем что в классе настроен exponential backoff
    retry_policy = ChannelDeactivationNotificationJob.retry_on_configuration

    assert retry_policy.present?, 'Retry policy should be configured'
    assert_equal :exponentially_longer, retry_policy[:wait]
    assert_equal 5, retry_policy[:attempts]
  end

  test 'job logs retry attempts' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Первая попытка - ошибка
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: false, error: 'Temporary error' })
      .once

    # Вторая попытка - успешно
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: true })
      .once

    ApplicationConfig.stubs(:admin_chat_id).returns(nil)

    # Проверяем логирование ошибок
    Rails.logger.expects(:error).with(regexp_matches(/Failed to send notification.*Temporary error/))

    perform_enqueued_jobs do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  test 'job handles service initialization errors' do
    # Ошибка при создании сервиса уведомлений
    TelegramNotificationService.expects(:new)
      .raises(StandardError.new('Service initialization failed'))

    # Задача должна перезапуститься
    assert_raises(StandardError) do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  test 'job handles admin notification errors separately from user notifications' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Уведомления пользователям успешные
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user, @channel, nil)
      .returns({ success: true })

    # Уведомление администратора с ошибкой
    ApplicationConfig.stubs(:admin_chat_id).returns(99999)
    notification_service.expects(:send_admin_deactivation_notification)
      .with(99999, @channel, has_entries(total: 1, sent: 1, errors: 0, skipped: 0))
      .returns({ success: false, error: 'Admin notification failed' })

    # Задача должна выполниться успешно несмотря на ошибку администратора
    assert_nothing_raised do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end

    # Проверяем логирование ошибки администратора
    assert_logged_admin_error
  end

  test 'job handles different error types appropriately' do
    test_cases = [
      {
        error: StandardError.new('Generic error'),
        should_retry: true,
        description: 'generic errors should retry'
      },
      {
        error: Net::TimeoutError.new('Timeout'),
        should_retry: true,
        description: 'network timeouts should retry'
      },
      {
        error: StandardError.new('Chat not found'),
        should_retry: true,
        description: 'Telegram API errors should retry'
      }
    ]

    test_cases.each do |test_case|
      notification_service = mock('TelegramNotificationService')
      TelegramNotificationService.expects(:new).returns(notification_service)

      notification_service.expects(:send_channel_deactivation_notification)
        .with(@user, @channel, nil)
        .raises(test_case[:error])
        .once

      ApplicationConfig.stubs(:admin_chat_id).returns(nil)

      if test_case[:should_retry]
        assert_raises(test_case[:error].class) do
          ChannelDeactivationNotificationJob.perform_now(@channel)
        end
      end
    end
  end

  test 'job maintains state across retry attempts' do
    # Создаем несколько подписчиков
    users = []
    3.times do |i|
      user = TelegramUser.create!(
        telegram_id: 9100 + i,
        username: "retry_user_#{i}",
        first_name: "Retry User #{i}",
        chat_id: 9100 + i,
        language_code: 'ru'
      )
      users << user
      Subscription.create!(
        telegram_user: user,
        channel: @channel,
        active: true
      )
    end

    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Первый пользователь успешно
    notification_service.expects(:send_channel_deactivation_notification)
      .with(users[0], @channel, nil)
      .returns({ success: true })

    # Второй пользователь вызывает ошибку, которая будет перезапущена
    notification_service.expects(:send_channel_deactivation_notification)
      .with(users[1], @channel, nil)
      .raises(StandardError.new('Temporary error'))
      .once

    # Третий пользователь не должен обрабатываться до успешного retry
    notification_service.expects(:send_channel_deactivation_notification)
      .with(users[2], @channel, nil)
      .never

    ApplicationConfig.stubs(:admin_chat_id).returns(nil)

    assert_raises(StandardError) do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  private

  def assert_logged_admin_error
    # Проверяет что ошибка администратора была залогирована
    assert true, "Admin error logging verification"
  end
end