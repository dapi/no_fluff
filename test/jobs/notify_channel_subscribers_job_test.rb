require 'test_helper'

class NotifyChannelSubscribersJobTest < ActiveJob::TestCase
  test 'should enqueue notification jobs for all subscribers' do
    # Создаем чистые данные для теста
    channel = Channel.create!(
      telegram_id: '999999999',
      username: 'test_channel_notify',
      title: 'Test Channel'
    )

    user = TelegramUser.create!(
      telegram_id: '888888888',
      username: 'test_user_notify',
      language_code: 'ru'
    )

    # Создаем активную подписку
    subscription = channel.subscriptions.create!(telegram_user: user, active: true, priority: 5)

    assert_enqueued_jobs(1) do
      NotifyChannelSubscribersJob.perform_now(channel)
    end
  end

  test 'should handle channel with no active subscribers' do
    # Создаем канал без подписчиков
    channel = Channel.create!(
      telegram_id: '999999998',
      username: 'test_channel_no_subs',
      title: 'Test Channel No Subs'
    )

    assert_no_enqueued_jobs do
      NotifyChannelSubscribersJob.perform_now(channel)
    end
  end

  test 'should work with multiple subscribers' do
    # Создаем чистые данные для теста
    channel = Channel.create!(
      telegram_id: '999999997',
      username: 'test_channel_multi',
      title: 'Test Channel Multi'
    )

    user1 = TelegramUser.create!(
      telegram_id: '888888887',
      username: 'test_user_multi1',
      language_code: 'ru'
    )

    user2 = TelegramUser.create!(
      telegram_id: '888888886',
      username: 'test_user_multi2',
      language_code: 'en'
    )

    # Создаем активные подписки
    channel.subscriptions.create!(telegram_user: user1, active: true, priority: 5)
    channel.subscriptions.create!(telegram_user: user2, active: true, priority: 3)

    assert_enqueued_jobs(2) do
      NotifyChannelSubscribersJob.perform_now(channel)
    end
  end
end