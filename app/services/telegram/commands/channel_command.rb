# Команды для управления каналами (/add, /remove)
module Telegram
  module Commands
    class ChannelCommand < BaseCommand
      attr_reader :action, :channel_input

      def initialize(bot, user, action, channel_input = nil)
        super(bot, user, {})
        @action = action
        @channel_input = channel_input
      end

      def call
        case action
        when :add
          handle_add
        when :remove
          handle_remove
        else
          raise ArgumentError, "Unknown action: #{action}"
        end
      end

      private

      def handle_add
        if channel_input.present?
          add_channel(channel_input)
        else
          respond_with :message, text: I18n.t('telegram_bot.channels.add.prompt')
        end
      end

      def handle_remove
        if channel_input.present?
          remove_channel(channel_input)
        else
          respond_with :message, text: I18n.t('telegram_bot.channels.remove.prompt')
        end
      end

      def add_channel(input)
        safe_execute(action: 'add_channel', channel_input: input) do
          service = Telegram::ChannelService.new(bot)
          result = service.add_channel_for_user(user, input)

          if result[:success]
            handle_successful_add(result)
          else
            handle_failed_add(result)
          end
        end
      end

      def handle_successful_add(result)
        respond_with :message, text: result[:message]
        respond_with :message, text: I18n.t('telegram_bot.channels.add.suggest_another')
      end

      def handle_failed_add(result)
        respond_with :message, text: result[:message]

        limit_checker = Limits::LimitChecker.new(user)
        return unless limit_checker.limit_reached?

        show_subscription_offer
      end

      def show_subscription_offer
        manager = SubscriptionManagement::Manager.new(user)
        offer = manager.subscription_offer

        offer_keyboard = build_subscription_offer_keyboard(offer)
        respond_with :message, text: offer[:message], reply_markup: offer_keyboard
      end

      def build_subscription_offer_keyboard(offer)
        inline_keyboard(
          keyboard_row(
            callback_button(offer[:activate_button_text], 'activate_subscription:')
          ),
          keyboard_row(
            callback_button('Мои подписки', 'my_subscriptions:')
          )
        )
      end

      def remove_channel(input)
        safe_execute(action: 'remove_channel', channel_input: input) do
          username = parse_username(input)
          return respond_with_invalid_format unless valid_username?(username)

          channel = find_channel(username)
          return respond_with_not_found(username) unless channel

          subscription = find_subscription(channel)
          return respond_with_not_subscribed(channel) unless subscription

          remove_subscription(subscription)
        end
      end

      def parse_username(input)
        username = input.to_s.strip
        username = username[1..-1] if username.start_with?('@')

        # Извлечение username из URL
        if username.match?(%r{^https?://t\.me/})
          username = username.match(%r{^https?://t\.me/([a-zA-Z0-9_]+)})&.[](1)
        elsif username.match?(%r{^t\.me/})
          username = username.match(%r{^t\.me/([a-zA-Z0-9_]+)})&.[](1)
        end

        username
      end

      def valid_username?(username)
        username.present? && username.match?(/\A[a-zA-Z0-9_]{5,32}\z/)
      end

      def respond_with_invalid_format
        respond_with :message, text: I18n.t('telegram_bot.channels.remove.invalid_format')
      end

      def find_channel(username)
        Channel.find_by('username ILIKE ?', username)
      end

      def respond_with_not_found(username)
        respond_with :message, text: I18n.t('telegram_bot.channels.remove.not_found', channel: "@#{username}")
      end

      def find_subscription(channel)
        user.subscriptions.find_by(channel: channel)
      end

      def respond_with_not_subscribed(channel)
        respond_with :message, text: I18n.t('telegram_bot.channels.remove.not_subscribed', channel: "@#{channel.username}")
      end

      def remove_subscription(subscription)
        subscription.destroy
        respond_with :message, text: I18n.t('telegram_bot.channels.remove.success',
                                              channel: "@#{subscription.channel.username}",
                                              count: user.subscriptions.count)
      end
    end
  end
end
