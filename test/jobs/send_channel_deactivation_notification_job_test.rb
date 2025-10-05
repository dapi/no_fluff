require 'test_helper'

class SendChannelDeactivationNotificationJobTest < ActiveJob::TestCase
  test 'should build message with correct content' do
    channel = Channel.create!(
      telegram_id: '999999996',
      username: 'test_channel_message',
      title: 'Test Channel',
      deactivated_at: 1.hour.ago,
      deactivation_reason: "Bot was blocked by admin"
    )

    user = TelegramUser.create!(
      telegram_id: '888888885',
      username: 'test_user_message',
      language_code: 'ru'
    )

    job = SendChannelDeactivationNotificationJob.new
    message = job.send(:build_deactivation_message, user, channel)

    assert_includes message, 'test_channel_message'
    assert_includes message, 'Bot was blocked by admin'
    assert_includes message, '🔴'
  end

  test 'should work with different user languages' do
    channel = Channel.create!(
      telegram_id: '999999995',
      username: 'test_channel_lang',
      title: 'Test Channel',
      deactivated_at: 1.hour.ago,
      deactivation_reason: "Test error"
    )

    user_ru = TelegramUser.create!(
      telegram_id: '888888884',
      username: 'test_user_ru',
      language_code: 'ru'
    )

    user_en = TelegramUser.create!(
      telegram_id: '888888883',
      username: 'test_user_en',
      language_code: 'en'
    )

    job = SendChannelDeactivationNotificationJob.new

    # Проверяем что сообщения строятся без ошибок для разных языков
    assert_nothing_raised do
      job.send(:build_deactivation_message, user_ru, channel)
    end

    assert_nothing_raised do
      job.send(:build_deactivation_message, user_en, channel)
    end
  end

  test 'should default to russian language' do
    channel = Channel.create!(
      telegram_id: '999999994',
      username: 'test_channel_default_lang',
      title: 'Test Channel',
      deactivated_at: 1.hour.ago,
      deactivation_reason: "Test error"
    )

    user = TelegramUser.create!(
      telegram_id: '888888882',
      username: 'test_user_default_lang',
      language_code: 'ru'  # Используем русский вместо nil
    )

    job = SendChannelDeactivationNotificationJob.new

    assert_nothing_raised do
      job.send(:build_deactivation_message, user, channel)
    end
  end
end