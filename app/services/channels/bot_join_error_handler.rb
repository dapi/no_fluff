# Сервис для детальной обработки ошибок вступления бота в каналы
module Channels
  class BotJoinErrorHandler
    ERROR_TYPES = {
      'bad request: chat not found' => {
        type: :channel_not_found,
        user_message: 'Канал не найден или был удален',
        admin_message: 'Канал не существует в Telegram',
        severity: :high,
        retry_possible: false
      },
      'forbidden: bot was kicked from the channel' => {
        type: :bot_kicked,
        user_message: 'Бот был удален из канала',
        admin_message: 'Бота исключили из канала',
        severity: :high,
        retry_possible: false
      },
      'forbidden: bot is not a member' => {
        type: :bot_not_member,
        user_message: 'Бот не является участником канала',
        admin_message: 'Бот не добавлен в канал',
        severity: :high,
        retry_possible: false
      },
      'forbidden: user is deactivated' => {
        type: :user_deactivated,
        user_message: 'Пользователь деактивирован',
        admin_message: 'Аккаунт пользователя деактивирован',
        severity: :high,
        retry_possible: false
      },
      'too many requests: retry after' => {
        type: :rate_limit,
        user_message: 'Слишком много запросов. Попробуйте позже.',
        admin_message: 'Превышен лимит запросов к Telegram API',
        severity: :medium,
        retry_possible: true
      },
      'timeout' => {
        type: :timeout,
        user_message: 'Время ожидания истекло',
        admin_message: 'Тайм-аут при подключении к Telegram API',
        severity: :medium,
        retry_possible: true
      },
      'network error' => {
        type: :network_error,
        user_message: 'Ошибка сети',
        admin_message: 'Проблемы с сетевым подключением',
        severity: :medium,
        retry_possible: true
      },
      'invalid token' => {
        type: :invalid_token,
        user_message: 'Ошибка аутентификации бота',
        admin_message: 'Неверный токен бота',
        severity: :critical,
        retry_possible: false
      }
    }.freeze

    def self.classify_error(error_message)
      error_lower = error_message.to_s.downcase

      ERROR_TYPES.each do |pattern, info|
        return info if error_lower.include?(pattern)
      end

      # Если не найдено совпадение, возвращаем ошибку по умолчанию
      {
        type: :unknown,
        user_message: 'Неизвестная ошибка',
        admin_message: error_message,
        severity: :medium,
        retry_possible: false
      }
    end

    def self.get_error_context(error_info, channel)
      {
        channel: {
          id: channel.id,
          username: channel.username,
          title: channel.title,
          telegram_id: channel.telegram_id
        },
        error: error_info,
        timestamp: Time.current,
        environment: Rails.env,
        bot_info: {
          username: ApplicationConfig.bot_username
        }
      }
    end

    def self.should_retry?(error_info)
      error_info[:retry_possible]
    end

    def self.get_severity_level(error_info)
      error_info[:severity]
    end
  end
end
