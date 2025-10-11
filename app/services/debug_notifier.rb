# frozen_string_literal: true

# Сервис для отправки отладочных уведомлений администраторам
# Использует SystemSetting для хранения режима отладки
class DebugNotifier
  # Типы отладочных сообщений
  MESSAGE_TYPES = %w[
    error
    warning
    info
    success
    channel_update_error
    message_processing_error
    system_alert
  ].freeze

  class << self
    # Проверяет включен ли режим отладки
    # @return [Boolean] true если режим отладки включен
    def enabled?
      SystemSetting.get('debug_mode', false)
    end

    # Включает режим отладки
    # @param description [String] описание включения
    def enable!(description = nil)
      SystemSetting.set('debug_mode', true, description || 'Debug mode enabled')
    end

    # Выключает режим отладки
    def disable!
      SystemSetting.set('debug_mode', false, 'Debug mode disabled')
    end

    # Переключает режим отладки
    # @return [Boolean] новое состояние режима отладки
    def toggle!
      if enabled?
        disable!
        false
      else
        enable!
        true
      end
    end

    # Отправляет отладочное уведомление всем администраторам
    # @param message_type [String] тип сообщения
    # @param message [String] текст сообщения
    # @param context [Hash] дополнительный контекст
    # @return [Integer] количество администраторов которым отправлено сообщение
    def notify(message_type, message, context = {})
      return 0 unless enabled?
      return 0 unless MESSAGE_TYPES.include?(message_type)

      admin_users = TelegramUser.where(is_admin: true)
      return 0 if admin_users.empty?

      # Отправляем через фоновую задачу
      DebugNotificationJob.perform_later(message_type, message, context)
      admin_users.count
    end

    # Удобные методы для разных типов уведомлений
    def error(message, context = {})
      notify('error', message, context)
    end

    def warning(message, context = {})
      notify('warning', message, context)
    end

    def info(message, context = {})
      notify('info', message, context)
    end

    def success(message, context = {})
      notify('success', message, context)
    end

    def channel_error(channel, error, context = {})
      notify('channel_update_error',
             "Failed to update channel @#{channel.username}: #{error.message}",
             context.merge(channel_id: channel.id, error_class: error.class.name))
    end

    def message_processing_error(message_obj, error, context = {})
      notify('message_processing_error',
             "Failed to process message #{message_obj.id}: #{error.message}",
             context.merge(message_id: message_obj.id, error_class: error.class.name))
    end

    def system_alert(message, context = {})
      notify('system_alert', message, context)
    end

    # Отправляет уведомление об ошибке с автоматическим определением типа
    # @param error [StandardError] исключение
    # @param context [Hash] дополнительный контекст
    # @param message [String] дополнительное сообщение
    def notify_error(error, context = {}, message = nil)
      error_type = case error
                   when Telegram::Bot::Error
                     'telegram_api_error'
                   when ActiveRecord::RecordInvalid
                     'validation_error'
                   when Timeout::Error
                     'timeout_error'
                   else
                     'error'
                   end

      error_message = message || "#{error.class}: #{error.message}"
      notify(error_type, error_message, context.merge(
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(5)
      ))
    end

    # Проверяет что есть хотя бы один администратор
    # @return [Boolean] true если есть администраторы
    def has_admins?
      TelegramUser.where(is_admin: true).exists?
    end

    # Возвращает количество администраторов
    # @return [Integer] количество администраторов
    def admin_count
      TelegramUser.where(is_admin: true).count
    end
  end
end