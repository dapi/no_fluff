# frozen_string_literal: true

# Фоновая задача для отправки отладочных уведомлений администраторам
class DebugNotificationJob < ApplicationJob
  queue_as :content

  # Выполняет отправку отладочного уведомления
  # @param message_type [String] тип сообщения
  # @param message [String] текст сообщения
  # @param context [Hash] дополнительный контекст
  def perform(message_type, message, context = {})
    return unless DebugNotifier.enabled?

    admin_users = TelegramUser.where(is_admin: true)
    return if admin_users.empty?

    # Получаем экземпляр бота
    bot = telegram_bot_instance
    return unless bot

    # Формируем сообщение
    formatted_message = format_message(message_type, message, context)

    # Отправляем всем администраторам
    admin_users.find_each do |admin|
      send_to_admin(bot, admin, formatted_message)
    end

    # Логируем отправку
    Rails.logger.info "[DebugNotifier] Sent #{message_type} notification to #{admin_users.count} admins"
  rescue StandardError => e
    # Отправка ошибок в Bugsnag с контекстом
    Bugsnag.notify(e) do |bugsnag|
      bugsnag.add_metadata(:debug_notifier, {
        message_type: message_type,
        message: message,
        context: context,
        admin_count: admin_users.count
      })
    end

    Rails.logger.error "[DebugNotifier] Failed to send notification: #{e.message}"
  end

  private

  # Возвращает экземпляр Telegram бота
  # @return [Telegram::Bot::Client, nil]
  def telegram_bot_instance
    @telegram_bot_instance ||= begin
      require 'telegram/bot'
      Telegram::Bot::Client.new(ApplicationConfig.bot_token)
    rescue StandardError => e
      Rails.logger.error "[DebugNotifier] Failed to initialize bot: #{e.message}"
      nil
    end
  end

  # Форматирует отладочное сообщение
  # @param message_type [String] тип сообщения
  # @param message [String] текст сообщения
  # @param context [Hash] дополнительный контекст
  # @return [String] отформатированное сообщение
  def format_message(message_type, message, context)
    emoji = type_emoji(message_type)
    timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')

    formatted = "#{emoji} DEBUG ALERT\n"
    formatted += "🔧 Type: #{message_type}\n"
    formatted += "⏰ Time: #{timestamp}\n"
    formatted += "📝 Message: #{message}\n"

    if context.any?
      formatted += "\n📊 Context:\n"
      context.each do |key, value|
        formatted += "  • #{key}: #{format_context_value(value)}\n"
      end
    end

    formatted
  end

  # Возвращает эмодзи для типа сообщения
  # @param message_type [String] тип сообщения
  # @return [String] эмодзи
  def type_emoji(message_type)
    case message_type.to_s
    when 'error', 'telegram_api_error', 'validation_error', 'timeout_error'
      '🚨'
    when 'warning'
      '⚠️'
    when 'info'
      'ℹ️'
    when 'success'
      '✅'
    when 'channel_update_error'
      '📡'
    when 'message_processing_error'
      '📨'
    when 'system_alert'
      '🔔'
    else
      '🔍'
    end
  end

  # Форматирует значение для контекста
  # @param value [Object] значение для форматирования
  # @return [String] отформатированное значение
  def format_context_value(value)
    case value
    when String
      value.length > 100 ? "#{value[0..97]}..." : value
    when Hash
      if value.keys.length > 5
        "#{value.keys.first(5).join(', ')}... (#{value.keys.length} total)"
      else
        value.map { |k, v| "#{k}: #{format_context_value(v)}" }.join(', ')
      end
    when Array
      if value.length > 5
        "[#{value.first(5).join(', ')}... (#{value.length} total)]"
      else
        "[#{value.join(', ')}]"
      end
    else
      value.to_s
    end
  end

  # Отправляет сообщение администратору
  # @param bot [Telegram::Bot::Client] экземпляр бота
  # @param admin [TelegramUser] администратор
  # @param message [String] сообщение
  def send_to_admin(bot, admin, message)
    bot.api.send_message(
      chat_id: admin.telegram_id,
      text: message,
      parse_mode: nil
    )
  rescue Telegram::Bot::Error => e
    Rails.logger.warn "[DebugNotifier] Failed to send to admin #{admin.id} (#{admin.telegram_id}): #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[DebugNotifier] Unexpected error sending to admin #{admin.id}: #{e.message}"
    raise
  end
end
