class SendChannelDeactivationNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(channel, user)
    # Формируем сообщение
    message = build_deactivation_message(user, channel)

    # Отправляем через Telegram
    response = TelegramClient.send_message(
      chat_id: user.telegram_id,
      text: message,
      parse_mode: :html
    )

    # Логируем результат
    unless response.ok?
      Bugsnag.notify("Failed to send channel deactivation notification",
                     metadata: {
                       user_id: user.id,
                       channel_id: channel.id,
                       error: response.error
                     })
    end
  end

  private

  def build_deactivation_message(user, channel)
    I18n.t('notifications.channel_deactivated',
           channel_name: channel.username,
           reason: channel.deactivation_reason,
           locale: user.language_code || 'ru')
  end
end