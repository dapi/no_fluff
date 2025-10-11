# Фоновая задача для отправки уведомлений о деактивации канала
class ChannelDeactivationNotificationJob < ApplicationJob
  queue_as :notifications

  # Ретраи при ошибках Telegram API
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # Параметры для ApplicationJob
  # @param channel [Channel] - деактивированный канал
  # @param reason [String, nil] - причина деактивации
  def perform(channel, reason: nil)
    Rails.logger.info "Starting deactivation notifications for channel #{channel.id} (@#{channel.username})"

    notification_service = TelegramNotificationService.new(Telegram.bot)

    # Получаем всех активных подписчиков канала
    subscribers = channel.subscriptions.includes(:telegram_user).active

    # Статистика отправки
    stats = {
      total: subscribers.count,
      sent: 0,
      errors: 0,
      skipped: 0
    }

    # Отправляем уведомления каждому подписчику
    subscribers.find_each do |subscription|
      user = subscription.telegram_user

      # Пропускаем пользователей без chat_id
      if user.chat_id.blank?
        stats[:skipped] += 1
        Rails.logger.warn "Skipping user #{user.id} - no chat_id"
        next
      end

      result = notification_service.send_channel_deactivation_notification(user, channel, reason)

      if result[:success]
        stats[:sent] += 1
        Rails.logger.info "Successfully sent notification to user #{user.id}"
      else
        stats[:errors] += 1
        Rails.logger.error "Failed to send notification to user #{user.id}: #{result[:error]}"
      end

      # Небольшая задержка чтобы не превышать лимиты Telegram API
      sleep(0.1) if stats[:sent] % 10 == 0
    end

    # Отправляем отчет администратору (если настроен admin_chat_id)
    send_admin_report(channel, stats)

    Rails.logger.info "Completed deactivation notifications for channel #{channel.id}: #{stats}"
  end

  private

  # Отправляет отчет администратору о результатах рассылки
  def send_admin_report(channel, stats)
    admin_chat_id = ApplicationConfig.admin_chat_id

    return if admin_chat_id.blank?

    notification_service = TelegramNotificationService.new(Telegram.bot)

    result = notification_service.send_admin_deactivation_notification(
      admin_chat_id,
      channel,
      stats
    )

    if result[:success]
      Rails.logger.info "Admin report sent successfully for channel #{channel.id}"
    else
      Rails.logger.error "Failed to send admin report for channel #{channel.id}: #{result[:error]}"
    end
  end
end