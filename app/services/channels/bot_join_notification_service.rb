# Сервис для отправки уведомлений администраторам о результатах вступления бота в каналы
module Channels
  class BotJoinNotificationService
    def initialize
      @bot = Telegram.bots[:default]
    end

    # Отправляет уведомление об успешном вступлении бота в канал
    def notify_success(channel)
      return unless should_notify?

      admins.each do |admin|
        send_message_to_admin(
          admin.telegram_id,
          success_message(channel)
        )
      end

      Rails.logger.info "Sent bot join success notifications to #{admins.count} admins for channel #{channel.username}"
    end

    # Отправляет уведомление о неудачном вступлении бота в канал
    def notify_failure(channel, error)
      return unless should_notify?

      admins.each do |admin|
        send_message_to_admin(
          admin.telegram_id,
          failure_message(channel, error)
        )
      end

      Rails.logger.info "Sent bot join failure notifications to #{admins.count} admins for channel #{channel.username}"
    end

    private

    def admins
      @admins ||= TelegramUser.where(is_admin: true)
    end

    def should_notify?
      admins.any?
    end

    def send_message_to_admin(telegram_id, text)
      begin
        @bot.send_message(
          chat_id: telegram_id,
          text: text,
          parse_mode: 'Markdown'
        )
      rescue StandardError => e
        Rails.logger.error "Failed to send notification to admin #{telegram_id}: #{e.message}"
        Bugsnag.notify(e) do |b|
          b.metadata = {
            service: self.class.name,
            admin_telegram_id: telegram_id,
            action: 'send_notification'
          }
        end
      end
    end

    def success_message(channel)
      I18n.t(
        'channels.bot_join.success',
        channel_title: channel.title,
        channel_username: channel.username,
        channel_id: channel.telegram_id,
        subscribers_count: channel.subscribers_count || 0,
        joined_at: I18n.l(channel.bot_join_at, format: :short)
      )
    end

    def failure_message(channel, error)
      I18n.t(
        'channels.bot_join.failure',
        channel_title: channel.title,
        channel_username: channel.username,
        channel_id: channel.telegram_id,
        error_message: error,
        failed_at: I18n.l(Time.current, format: :short)
      )
    end
  end
end
