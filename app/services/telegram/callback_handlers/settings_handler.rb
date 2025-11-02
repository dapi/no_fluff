# Обработчик callback query для настроек
module Telegram
  module CallbackHandlers
    class SettingsHandler < BaseHandler
      def call
        safe_execute(callback_action: 'settings') do
          answer_callback_query('')
          show_settings
        end
      end

      private

      def show_settings
        agent = Telegram::SettingsAgent.new(bot, user)
        settings_text = agent.send(:build_settings_text)
        settings_keyboard = agent.send(:build_settings_keyboard)

        if payload['message']
          edit_message :text,
            text: settings_text,
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: settings_text,
            reply_markup: settings_keyboard
        end
      end
    end
  end
end
