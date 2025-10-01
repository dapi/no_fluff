# Основной контроллер для обработки обновлений от Telegram Bot API
# Документация: https://github.com/telegram-bot-rb/telegram-bot
class TelegramWebhookController < Telegram::Bot::UpdatesController
  # Обработка ошибок
  rescue_from StandardError do |exception|
    Rails.logger.error "Telegram Bot Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    respond_with :message, text: 'Произошла ошибка. Попробуйте позже.'
  end

  # Команда /start - приветствие и краткая инструкция
  def start!(*)
    respond_with :message,
      text: "Привет! 👋\n\nЯ NoFluff бот — помогу фильтровать важные посты из ваших Telegram каналов.\n\nИспользуйте /help для списка команд."
  end

  # Обработка обычных текстовых сообщений
  def message(message)
    text = message['text']
    respond_with :message, text: "Вы написали: #{text}"
  end
end
