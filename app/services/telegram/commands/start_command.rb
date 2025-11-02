# Команда /start - приветствие и краткая инструкция
module Telegram
  module Commands
    class StartCommand < BaseCommand
      def call
        if first_user?
          make_first_admin
          send_first_admin_message
        else
          send_welcome_message
        end
      end

      private

      def first_user?
        !TelegramUser.any_admins?
      end

      def make_first_admin
        user.update!(is_admin: true)
      end

      def send_first_admin_message
        respond_with :message,
          text: I18n.t('telegram_bot.start.first_admin') + "\n\n" + I18n.t('telegram_bot.start.welcome'),
          reply_markup: start_keyboard
      end

      def send_welcome_message
        respond_with :message,
          text: I18n.t('telegram_bot.start.welcome'),
          reply_markup: start_keyboard
      end

      def start_keyboard
        inline_keyboard(
          keyboard_row(
            callback_button(I18n.t('telegram_bot.start.button_start'), 'start_onboarding:'),
            callback_button(I18n.t('telegram_bot.start.button_more_info'), 'more_info:')
          ),
          keyboard_row(
            callback_button('⚙️ Настройки', 'settings:')
          )
        )
      end
    end
  end
end
