# Фоновая задача для вступления бота в Telegram канал
# Запускается после добавления канала в систему
class Channels::BotJoinJob < ApplicationJob
  queue_as :channels
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(channel_id)
    with_error_context(channel_id: channel_id, action: 'bot_join') do
      channel = Channel.find(channel_id)

      Rails.logger.info "Starting bot join process for channel #{channel.username}"

      # Обновляем статус на joining
      channel.start_joining!

      # Пытаемся вступить в канал
      join_result = attempt_to_join_channel(channel)

      if join_result == true
        channel.mark_as_joined!
        notify_admins_success(channel)
        Rails.logger.info "Bot successfully joined channel #{channel.username}"
      else
        error_info = Channels::BotJoinErrorHandler.classify_error(join_result[:error_description])
        error_context = Channels::BotJoinErrorHandler.get_error_context(error_info, channel)

        channel.mark_as_join_failed!(join_result[:error_description])
        notify_admins_failure(channel, join_result[:error_description])

        # Логируем с детальным контекстом
        Rails.logger.error "Bot failed to join channel #{channel.username} - #{error_info[:type]}: #{join_result[:error_description]}"
        Rails.logger.error "Error context: #{error_context.to_json}"

        # Отправляем уведомление в Bugsnag с полным контекстом
        Bugsnag.notify(
          StandardError.new("Bot join failed: #{error_info[:type]}"),
          error_info[:admin_message]
        ) do |b|
          b.metadata = error_context
          b.severity = Channels::BotJoinErrorHandler.get_severity_level(error_info)
        end
      end
    end
  end

  private

  def attempt_to_join_channel(channel)
    begin
      # Инициализируем клиент
      bot = Telegram.bots[:default]

      # Для публичных каналов бот может просто начать следить
      # через webhook без дополнительного вступления
      chat_id = channel.telegram_id

      # Проверяем доступность канала
      chat_info = bot.get_chat(chat_id: chat_id)

      if chat_info['ok']
        Rails.logger.info "Channel #{channel.username} is accessible to bot"
        true
      else
        error_code = chat_info['error_code'] || 'unknown'
        error_description = chat_info['description'] || 'Unknown error'

        Rails.logger.warn "Cannot access channel #{channel.username}: #{error_code} - #{error_description}"
        { error_code: error_code, error_description: error_description }
      end

    rescue Telegram::Bot::Error => e
      Rails.logger.error "Telegram API error for channel #{channel.username}: #{e.message}"
      { error_code: 'telegram_api_error', error_description: e.message }
    rescue StandardError => e
      Rails.logger.error "Unexpected error for channel #{channel.username}: #{e.message}"
      { error_code: 'unexpected_error', error_description: e.message }
    end
  end

  def extract_error_message(result)
    return 'Unknown error' if result == true
    return result[:error_description] if result.is_a?(Hash) && result[:error_description]
    'Failed to join channel'
  end

  def notify_admins_success(channel)
    Channels::BotJoinNotificationService.new.notify_success(channel)
  end

  def notify_admins_failure(channel, error_message)
    Channels::BotJoinNotificationService.new.notify_failure(channel, error_message)
  end
end
