require 'test_helper'

class ChannelDeactivationNotificationJobTest < ActiveJob::TestCase
  setup do
    @channel = Channel.create!(
      telegram_id: 6001,
      username: 'testchannel_job',
      title: 'Test Channel Job',
      active: false
    )

    # Создаем пользователей с подписками
    @users = []
    5.times do |i|
      user = TelegramUser.create!(
        telegram_id: 3000 + i,
        username: "user_job_#{i}",
        first_name: "User Job #{i}",
        chat_id: 4000 + i,
        language_code: 'ru'
      )
      @users << user
      Subscription.create!(
        telegram_user: user,
        channel: @channel,
        active: true
      )
    end

    # Создаем пользователя без chat_id
    @user_without_chat = TelegramUser.create!(
      telegram_id: 3005,
      username: "user_no_chat",
      first_name: "User No Chat",
      language_code: 'ru'
    )
    Subscription.create!(
      telegram_user: @user_without_chat,
      channel: @channel,
      active: true
    )
  end

  test 'perform sends notifications to all active subscribers' do
    # Мокаем сервис уведомлений
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Мокаем успешную отправку для каждого пользователя
    @users.each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, 'admin_decision')
        .returns({ success: true })
    end

    # Мокаем отправку администратору
    ApplicationConfig.stubs(:admin_chat_id).returns(99999)
    notification_service.expects(:send_admin_deactivation_notification)
      .with(99999, @channel, has_entries(total: 5, sent: 5, errors: 0, skipped: 0))
      .returns({ success: true })

    # Выполняем задачу
    ChannelDeactivationNotificationJob.perform_now(@channel, reason: 'admin_decision')
  end

  test 'perform skips users without chat_id' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Отправляем уведомления только пользователям с chat_id
    @users.each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, nil)
        .returns({ success: true })
    end

    # Пользователь без chat_id не должен получать уведомление
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@user_without_chat, @channel, nil)
      .never

    # Мокаем отправку администратору
    ApplicationConfig.stubs(:admin_chat_id).returns(99999)
    notification_service.expects(:send_admin_deactivation_notification)
      .with(99999, @channel, has_entries(total: 6, sent: 5, errors: 0, skipped: 1))
      .returns({ success: true })

    ChannelDeactivationNotificationJob.perform_now(@channel)
  end

  test 'perform handles notification errors gracefully' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Первые 3 пользователя успешно
    @users[0..2].each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, nil)
        .returns({ success: true })
    end

    # Последние 2 пользователя с ошибкой
    @users[3..4].each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, nil)
        .returns({ success: false, error: 'Telegram API error' })
    end

    # Мокаем отправку администратору с правильной статистикой
    ApplicationConfig.stubs(:admin_chat_id).returns(99999)
    notification_service.expects(:send_admin_deactivation_notification)
      .with(99999, @channel, has_entries(total: 5, sent: 3, errors: 2, skipped: 0))
      .returns({ success: true })

    ChannelDeactivationNotificationJob.perform_now(@channel)
  end

  test 'perform works when admin_chat_id is not configured' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Все пользователи успешно
    @users.each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, nil)
        .returns({ success: true })
    end

    # Администратор не настроен
    ApplicationConfig.stubs(:admin_chat_id).returns(nil)
    notification_service.expects(:send_admin_deactivation_notification).never

    ChannelDeactivationNotificationJob.perform_now(@channel)
  end

  test 'perform handles admin notification error' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # Все пользователи успешно
    @users.each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, nil)
        .returns({ success: true })
    end

    # Ошибка отправки администратору
    ApplicationConfig.stubs(:admin_chat_id).returns(99999)
    notification_service.expects(:send_admin_deactivation_notification)
      .with(99999, @channel, has_entries(total: 5, sent: 5, errors: 0, skipped: 0))
      .returns({ success: false, error: 'Admin notification failed' })

    # Задача должна выполниться без ошибок
    assert_nothing_raised do
      ChannelDeactivationNotificationJob.perform_now(@channel)
    end
  end

  test 'perform handles mixed success and error scenarios' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    # 2 пользователя успешно
    @users[0..1].each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, 'technical')
        .returns({ success: true })
    end

    # 1 пользователя с ошибкой
    notification_service.expects(:send_channel_deactivation_notification)
      .with(@users[2], @channel, 'technical')
      .returns({ success: false, error: 'Network error' })

    # Мокаем отправку администратору
    ApplicationConfig.stubs(:admin_chat_id).returns(99999)
    notification_service.expects(:send_admin_deactivation_notification)
      .with(99999, @channel, has_entries(total: 6, sent: 2, errors: 1, skipped: 1))
      .returns({ success: true })

    ChannelDeactivationNotificationJob.perform_now(@channel, reason: 'technical')
  end

  test 'perform uses correct queue name' do
    assert_equal :notifications, ChannelDeactivationNotificationJob.new.queue_name
  end

  test 'perform includes proper logging' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    @users.each do |user|
      notification_service.expects(:send_channel_deactivation_notification)
        .with(user, @channel, nil)
        .returns({ success: true })
    end

    ApplicationConfig.stubs(:admin_chat_id).returns(nil)

    # Проверяем что логи записываются (мокаем Rails.logger)
    Rails.logger.expects(:info).with(regexp_matches(/Starting deactivation notifications/))
    Rails.logger.expects(:info).with(regexp_matches(/Successfully sent notification/)).times(5)
    Rails.logger.expects(:info).with(regexp_matches(/Completed deactivation notifications/))

    ChannelDeactivationNotificationJob.perform_now(@channel)
  end

  test 'perform logs errors for failed notifications' do
    notification_service = mock('TelegramNotificationService')
    TelegramNotificationService.expects(:new).returns(notification_service)

    notification_service.expects(:send_channel_deactivation_notification)
      .with(@users[0], @channel, nil)
      .returns({ success: false, error: 'API rate limit' })

    Rails.logger.expects(:error).with(regexp_matches(/Failed to send notification.*API rate limit/))

    ChannelDeactivationNotificationJob.perform_now(@channel)
  end
end