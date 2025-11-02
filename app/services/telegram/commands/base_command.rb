# Базовый класс для всех команд Telegram бота
# Реализует Command Pattern для декомпозиции контроллера
module Telegram
  module Commands
    class BaseCommand
      include Telegram::KeyboardHelpers

      def initialize(bot, user, payload = {})
        @bot = bot
        @user = user
        @payload = payload
      end

      def call
        raise NotImplementedError, "#{self.class} must implement #call method"
      end

      protected

      attr_reader :bot, :user, :payload

      # Базовый метод для отправки сообщений
      def respond_with(type, options = {})
        bot.api.send_message(chat_id: chat_id, **default_options.merge(options))
      end

      # Базовый метод для редактирования сообщений
      def edit_message(type, options = {})
        bot.api.edit_message_text(chat_id: chat_id, message_id: message_id, **default_options.merge(options))
      end

      # Базовый метод для answer_callback_query
      def answer_callback_query(text = '')
        bot.api.answer_callback_query(callback_query_id: payload['id'], text: text)
      end

      # ID чата для ответа
      def chat_id
        payload.dig('chat', 'id') || payload.dig('message', 'chat', 'id')
      end

      # ID сообщения для редактирования
      def message_id
        payload.dig('message', 'id')
      end

      # ID callback query для ответа
      def callback_query_id
        payload['id']
      end

      # Опции по умолчанию для сообщений
      def default_options
        { parse_mode: 'HTML' }
      end

      # Проверка на администратора
      def admin_required
        return if user&.is_admin?

        respond_with :message, text: I18n.t('telegram_bot.debug.access_denied')
        false
      end

      # Безопасное выполнение с обработкой ошибок
      def safe_execute(error_context = {})
        yield
      rescue StandardError => e
        handle_error(e, error_context)
      end

      private

      def handle_error(error, context = {})
        Bugsnag.notify(error) do |notification|
          notification.metadata = {
            user_id: user&.id,
            command: self.class.name,
            context: context
          }
        end

        Rails.logger.error "#{self.class.name} error: #{error.message}"
        respond_with :message, text: I18n.t('telegram_bot.debug.error')
      end
    end
  end
end
