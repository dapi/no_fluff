# Обработчики callback query для подписок
module Telegram
  module CallbackHandlers
    class SubscriptionHandler < BaseHandler
      attr_reader :action

      def initialize(bot, user, callback_data, payload)
        super(bot, user, callback_data, payload)
        @action = extract_action
      end

      def call
        safe_execute(callback_action: action) do
          case action
          when 'activate_subscription'
            handle_activate_subscription
          when 'show_subscription_offer'
            handle_show_subscription_offer
          else
            raise ArgumentError, "Unknown subscription action: #{action}"
          end
        end
      end

      private

      def extract_action
        callback_data.split(':').first
      end

      def handle_activate_subscription
        answer_callback_query('')

        manager = SubscriptionManagement::Manager.new(user)
        result = manager.activate_premium_subscription

        if result[:success]
          show_success_message(result[:message])
        else
          show_error_message(result[:message])
        end
      end

      def handle_show_subscription_offer
        answer_callback_query('')

        manager = SubscriptionManagement::Manager.new(user)
        offer = manager.subscription_offer

        offer_keyboard = build_subscription_offer_keyboard(offer)
        text = offer[:message]

        if payload['message']
          edit_message :text, text: text, reply_markup: offer_keyboard
        else
          respond_with :message, text: text, reply_markup: offer_keyboard
        end
      end

      def show_success_message(message)
        if payload['message']
          edit_message :text, text: message
        else
          respond_with :message, text: message
        end
      end

      def show_error_message(message)
        if payload['message']
          edit_message :text, text: message
        else
          respond_with :message, text: message
        end
      end

      def build_subscription_offer_keyboard(offer)
        inline_keyboard(
          keyboard_row(
            callback_button(offer[:activate_button_text], 'activate_subscription:')
          ),
          keyboard_row(
            callback_button(I18n.t('telegram_bot.messages.back'), 'my_subscriptions:')
          )
        )
      end
    end
  end
end
