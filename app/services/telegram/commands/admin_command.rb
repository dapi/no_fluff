# Административные команды (/debug, /set_commands)
module Telegram
  module Commands
    class AdminCommand < BaseCommand
      attr_reader :command_type, :args

      def initialize(bot, user, command_type, args = {})
        super(bot, user, {})
        @command_type = command_type
        @args = args
      end

      def call
        return unless admin_required

        case command_type
        when :debug
          handle_debug
        when :set_commands
          handle_set_commands
        else
          raise ArgumentError, "Unknown admin command: #{command_type}"
        end
      end

      private

      def handle_debug
        safe_execute(action: 'debug_command') do
          new_status = DebugNotifier.toggle!

          if new_status
            respond_with :message, text: I18n.t('telegram_bot.debug.enabled')
          else
            respond_with :message, text: I18n.t('telegram_bot.debug.disabled')
          end
        end
      end

      def handle_set_commands
        safe_execute(action: 'set_commands_command') do
          respond_with :message, text: '🔧 Устанавливаю команды бота...'

          manager = Telegram::CommandsManager.new(bot: bot)
          result = manager.set_commands!

          if result[:success]
            respond_with :message,
              text: "#{result[:message]}\n\n📊 Установлено команд: #{result[:commands_count]}",
              reply_markup: set_commands_keyboard
          else
            respond_with :message, text: result[:message]
          end
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
