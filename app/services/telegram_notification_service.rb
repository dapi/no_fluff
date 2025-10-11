# Сервис для отправки уведомлений пользователям через Telegram
class TelegramNotificationService
  # Причины деактивации и их тексты
  DEACTIVATION_REASONS = {
    'admin_decision' => 'telegram_bot.channel_deactivation.notification.reasons.admin_decision',
    'inactive' => 'telegram_bot.channel_deactivation.notification.reasons.inactive',
    'violation' => 'telegram_bot.channel_deactivation.notification.reasons.violation',
    'technical' => 'telegram_bot.channel_deactivation.notification.reasons.technical'
  }.freeze

  def initialize(bot)
    @bot = bot
  end

  # Отправляет уведомление о деактивации канала пользователю
  # @param user [TelegramUser] - пользователь для уведомления
  # @param channel [Channel] - деактивированный канал
  # @param reason [String, nil] - причина деактивации
  # @return [Hash] - результат операции { success: true/false, error: String }
  def send_channel_deactivation_notification(user, channel, reason = nil)
    return { success: false, error: 'User has no chat_id' } if user.chat_id.blank?

    message = build_deactivation_message(channel, reason)
    keyboard = build_notification_keyboard

    send_message(user.chat_id, message, keyboard)
  rescue StandardError => e
    Bugsnag.notify(e) do |b|
      b.metadata = {
        user_id: user.id,
        channel_id: channel.id,
        reason: reason,
        action: 'send_channel_deactivation_notification'
      }
    end
    Rails.logger.error "Error sending deactivation notification to user #{user.id}: #{e.message}"

    { success: false, error: e.message }
  end

  # Отправляет уведомление администратору о результатах деактивации
  # @param admin_chat_id [Integer] - ID чата администратора
  # @param channel [Channel] - деактивированный канал
  # @param stats [Hash] - статистика отправки { sent: Integer, errors: Integer, total: Integer }
  # @return [Hash] - результат операции { success: true/false, error: String }
  def send_admin_deactivation_notification(admin_chat_id, channel, stats)
    message = build_admin_message(channel, stats)

    send_message(admin_chat_id, message)
  rescue StandardError => e
    Bugsnag.notify(e) do |b|
      b.metadata = {
        admin_chat_id: admin_chat_id,
        channel_id: channel.id,
        stats: stats,
        action: 'send_admin_deactivation_notification'
      }
    end
    Rails.logger.error "Error sending admin notification for channel #{channel.id}: #{e.message}"

    { success: false, error: e.message }
  end

  private

  # Формирует текст уведомления для пользователя
  def build_deactivation_message(channel, reason)
    reason_text = if reason.present? && DEACTIVATION_REASONS.key?(reason)
                    I18n.t(DEACTIVATION_REASONS[reason])
                  elsif reason.present?
                    reason
                  else
                    ''
                  end

    I18n.t(
      'telegram_bot.channel_deactivation.notification.message',
      channel_name: "@#{channel.username}",
      reason_text: reason_text.present? ? "\n\n📝 #{reason_text}" : ''
    )
  end

  # Формирует клавиатуру для уведомления
  def build_notification_keyboard
    {
      inline_keyboard: [
        [
          { text: I18n.t('telegram_bot.channel_deactivation.notification.actions.browse_channels'), callback_data: 'browse_channels' },
          { text: I18n.t('telegram_bot.channel_deactivation.notification.actions.notification_settings'), callback_data: 'notification_settings' }
        ]
      ]
    }
  end

  # Формирует текст уведомления для администратора
  def build_admin_message(channel, stats)
    I18n.t(
      'telegram_bot.channel_deactivation.admin_notification.message',
      channel_name: "@#{channel.username}",
      sent_count: stats[:sent] || 0,
      error_count: stats[:errors] || 0,
      total_subscribers: stats[:total] || 0
    )
  end

  # Отправляет сообщение через Telegram API
  def send_message(chat_id, text, reply_markup = nil)
    response = @bot.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: 'Markdown',
      reply_markup: reply_markup
    )

    if response['ok']
      { success: true }
    else
      error_msg = response['description'] || 'Unknown Telegram API error'
      { success: false, error: error_msg }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end
end