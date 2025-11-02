# Обработчики callback query для обновления настроек
module Telegram
  module CallbackHandlers
    class SettingUpdateHandler < BaseHandler
      attr_reader :setting_type, :value

      def initialize(bot, user, callback_data, payload)
        super(bot, user, callback_data, payload)
        parse_callback_data
      end

      def call
        safe_execute(callback_action: "update_#{setting_type}") do
          update_setting
          answer_callback_query('')
        end
      end

      private

      def parse_callback_data
        # Пример callback_data: "set_delivery_frequency:daily"
        parts = callback_data.split(':')
        @setting_type = parts[1] # delivery_frequency, content_format, filter_strictness
        @value = parts[2] if parts.size > 2
      end

      def update_setting
        return unless setting_type && value

        agent = Telegram::SettingsAgent.new(bot, user)
        agent.update_setting(setting_type, value)
      end
    end
  end
end
