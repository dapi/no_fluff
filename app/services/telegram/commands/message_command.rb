# Обработка обычных текстовых сообщений
module Telegram
  module Commands
    class MessageCommand < BaseCommand
      attr_reader :message

      def initialize(bot, user, message)
        super(bot, user, {})
        @message = message
      end

      def call
        text = message['text']

        if channel_like_message?(text)
          handle_channel_input(text)
        else
          handle_regular_message(text)
        end
      end

      private

      def channel_like_message?(text)
        text.start_with?('@') || text.include?('t.me/')
      end

      def handle_channel_input(text)
        channel_command = ChannelCommand.new(bot, user, :add, text)
        channel_command.call
      end

      def handle_regular_message(text)
        safe_execute(action: 'message_command', message: text) do
          response_text = I18n.t('telegram_bot.messages.user_message', text: text)
          respond_with :message, text: response_text
        end
      end
    end
  end
end
