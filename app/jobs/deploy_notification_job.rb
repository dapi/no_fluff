class DeployNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(version, created_at, metadata = {})
    Rails.logger.info "Starting deploy notification for version #{version}"

    TelegramUser.admins.find_each do |admin|
      begin
        send_notification(admin, version, created_at, metadata)
      rescue => e
        Bugsnag.notify(e, {
          admin_id: admin.id,
          version: version,
          context: 'deploy_notification'
        })
        Rails.logger.error "Failed to notify admin #{admin.id}: #{e.message}"
      end
    end

    Rails.logger.info "Completed deploy notification for version #{version}"
  end

  private

  def send_notification(admin, version, created_at, metadata)
    message = build_notification_message(version, created_at, metadata)

    bot = Telegram.bot
    bot.api.send_message(
      chat_id: admin.telegram_id,
      text: message,
      parse_mode: 'HTML'
    )
  end

  def build_notification_message(version, created_at, metadata)
    time_str = created_at.strftime('%Y-%m-%d %H:%M:%S UTC')

    message = "🚀 <b>Новая версия развернута</b>\n\n"
    message += "📦 Версия: <code>#{version}</code>\n"
    message += "⏰ Время: #{time_str}\n"

    if metadata.any?
      message += "\n📋 <b>Детали:</b>\n"
      metadata.each do |key, value|
        message += "• #{key.to_s.humanize}: #{value}\n"
      end
    end

    message += "\n✅ Деплой успешно завершен!"
    message
  end
end
