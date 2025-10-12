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
      success = attempt_to_join_channel(channel)

      if success
        channel.mark_as_joined!
        notify_admins_success(channel)
        Rails.logger.info "Bot successfully joined channel #{channel.username}"
      else
        error_message = extract_error_message(success)
        channel.mark_as_join_failed!(error_message)
        notify_admins_failure(channel, error_message)
        Rails.logger.error "Bot failed to join channel #{channel.username}: #{error_message}"
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
    # TODO: Implement admin notifications in stage 4
    Rails.logger.info "Bot successfully joined channel: #{channel.username} (#{channel.title})"
  end

  def notify_admins_failure(channel, error_message)
    # TODO: Implement admin notifications in stage 4
    Rails.logger.error "Bot failed to join channel #{channel.username}: #{error_message}"
  end
end
