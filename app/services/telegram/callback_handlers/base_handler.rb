# Базовый класс для обработчиков callback query
# Реализует Handler Pattern для декомпозиции контроллера
module Telegram
  module CallbackHandlers
    class BaseHandler
      include Telegram::KeyboardHelpers

      def initialize(bot, user, callback_data, payload)
        @bot = bot
        @user = user
        @callback_data = callback_data
        @payload = payload
      end

      def call
        raise NotImplementedError, "#{self.class} must implement #call method"
      end

      protected

      attr_reader :bot, :user, :callback_data, :payload

      # Базовый метод для ответа на callback
      def answer_callback_query(text = '')
        bot.api.answer_callback_query(callback_query_id: payload['id'], text: text)
      end

      # Базовый метод для редактирования сообщения
      def edit_message(type, options = {})
        bot.api.edit_message_text(
          chat_id: chat_id,
          message_id: message_id,
          **default_options.merge(options)
        )
      end

      # Базовый метод для отправки нового сообщения
      def respond_with(type, options = {})
        bot.api.send_message(
          chat_id: chat_id,
          **default_options.merge(options)
        )
      end

      # ID чата для ответа
      def chat_id
        payload.dig('message', 'chat', 'id') || payload.dig('chat', 'id')
      end

      # ID сообщения для редактирования
      def message_id
        payload.dig('message', 'id')
      end

      # Опции по умолчанию для сообщений
      def default_options
        { parse_mode: 'HTML' }
      end

      # Проверка на администратора
      def admin_required
        return if user&.is_admin?

        answer_callback_query(I18n.t('telegram_bot.debug.access_denied'))
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
            handler: self.class.name,
            callback_data: callback_data,
            context: context
          }
        end

        Rails.logger.error "#{self.class.name} error: #{error.message}"
        answer_callback_query(I18n.t('telegram_bot.debug.error'))
      end
    end
  end
end
