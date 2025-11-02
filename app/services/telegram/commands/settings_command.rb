# Команда /settings - показать настройки
module Telegram
  module Commands
    class SettingsCommand < BaseCommand
      def call
        safe_execute(action: 'settings_command') do
          agent = Telegram::SettingsAgent.new(bot, user)
          agent.show_settings
        end
      end
    end
  end
end
