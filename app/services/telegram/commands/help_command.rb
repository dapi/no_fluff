# Команда /help - список доступных команд
module Telegram
  module Commands
    class HelpCommand < BaseCommand
      def call
        safe_execute(action: 'help_command') do
          help_text = build_help_text
          respond_with :message, text: help_text
        end
      end

      private

      def build_help_text
        base_commands = I18n.t('telegram_bot.help.commands')

        if user&.is_admin?
          base_commands + "\n\n" + I18n.t('telegram_bot.help.admin_commands')
        else
          base_commands
        end
      end
    end
  end
end
