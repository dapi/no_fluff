# Обработчики callback query для онбординга
module Telegram
  module CallbackHandlers
    class OnboardingHandler < BaseHandler
      attr_reader :action

      def initialize(bot, user, callback_data, payload)
        super(bot, user, callback_data, payload)
        @action = extract_action
      end

      def call
        safe_execute(callback_action: action) do
          case action
          when 'start_onboarding'
            handle_start_onboarding
          when 'more_info'
            handle_more_info
          when 'back_to_start'
            handle_back_to_start
          else
            raise ArgumentError, "Unknown onboarding action: #{action}"
          end
        end
      end

      private

      def extract_action
        callback_data.split(':').first
      end

      def handle_start_onboarding
        answer_callback_query('')
        edit_message :text,
          text: I18n.t('telegram_bot.onboarding.add_channels'),
          reply_markup: onboarding_keyboard
      end

      def handle_more_info
        answer_callback_query('')
        edit_message :text,
          text: I18n.t('telegram_bot.more_info.text'),
          reply_markup: more_info_keyboard
      end

      def handle_back_to_start
        answer_callback_query('')
        edit_message :text,
          text: I18n.t('telegram_bot.start.welcome'),
          reply_markup: start_keyboard
      end

      def onboarding_keyboard
        inline_keyboard(
          keyboard_row(
            callback_button(I18n.t('telegram_bot.onboarding.button_my_subscriptions'), 'my_subscriptions:')
          )
        )
      end

      def more_info_keyboard
        inline_keyboard(
          keyboard_row(
            callback_button(I18n.t('telegram_bot.more_info.button_lets_start'), 'start_onboarding:')
          ),
          keyboard_row(
            callback_button('← Назад', 'back_to_start:')
          )
        )
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
