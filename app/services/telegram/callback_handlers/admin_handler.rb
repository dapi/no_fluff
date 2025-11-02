# Обработчики callback query для административных функций
module Telegram
  module CallbackHandlers
    class AdminHandler < BaseHandler
      attr_reader :action

      def initialize(bot, user, callback_data, payload)
        super(bot, user, callback_data, payload)
        @action = extract_action
      end

      def call
        return unless admin_required

        safe_execute(callback_action: action) do
          case action
          when 'show_commands'
            handle_show_commands
          else
            raise ArgumentError, "Unknown admin action: #{action}"
          end
        end
      end

      private

      def extract_action
        callback_data.split(':').first
      end

      def handle_show_commands
        answer_callback_query('')

        manager = Telegram::CommandsManager.new(bot: bot)
        commands_text = manager.format_all_commands_for_display

        if payload['message']
          edit_message :text, text: commands_text, reply_markup: set_commands_keyboard
        else
          respond_with :message, text: commands_text, reply_markup: set_commands_keyboard
        end
      end

      def set_commands_keyboard
        inline_keyboard(
          keyboard_row(
            callback_button('📋 Показать команды', 'show_commands:'),
            callback_button('🔄 Обновить команды', 'set_commands:')
          )
        )
      end
    end
  end
end
