# Модуль с командами для управления подписками на каналы
module Telegram::SubscriptionCommands
  extend ActiveSupport::Concern
  include Telegram::KeyboardHelpers

  included do
    # Команда /list - показать список подписок
    def list!(*)
      subscriptions = current_user.subscriptions.includes(:channel).active.by_created_at

      if subscriptions.empty?
        respond_with :message, text: I18n.t('telegram_bot.channels.list.empty')
      else
        respond_with :message, text: build_subscriptions_list(subscriptions)
      end
    end

    # Callback query: мои подписки
    def my_subscriptions_callback_query(*)
      answer_callback_query('')
      subscriptions = current_user.subscriptions.includes(:channel).active.by_created_at

      if subscriptions.empty?
        if payload['message']
          edit_message :text, text: I18n.t('telegram_bot.channels.list.empty')
        else
          respond_with :message, text: I18n.t('telegram_bot.channels.list.empty')
        end
      else
        if payload['message']
          edit_message :text, text: build_subscriptions_list(subscriptions)
        else
          respond_with :message, text: build_subscriptions_list(subscriptions)
        end
      end
    end

    # Callback query: удалить канал
    def remove_channel_callback_query(channel_id)
      answer_callback_query('')
      subscription = current_user.subscriptions.active.find_by(channel_id: channel_id)
      if subscription
        channel = subscription.channel

        # Клавиатура для подтверждения
        confirm_kb = inline_keyboard(
          keyboard_row(
            callback_button(
              I18n.t('telegram_bot.channels.list.buttons.remove'),
              "confirm_remove:#{channel_id}"
            ),
            callback_button('Отмена', 'my_subscriptions:')
          )
        )

        edit_message :text,
          text: I18n.t('telegram_bot.channels.list.confirm_remove', channel: "@#{channel.username}"),
          reply_markup: confirm_kb
      end
    end

    # Callback query: подтвердить удаление канала
    def confirm_remove_callback_query(channel_id)
      answer_callback_query('')
      subscription = current_user.subscriptions.active.find_by(channel_id: channel_id)
      if subscription
        channel = subscription.channel
        subscription.deactivate!

        edit_message :text,
          text: I18n.t('telegram_bot.channels.list.remove_success', channel: "@#{channel.username}")
      end
    end

    private

    # Построить текст списка подписок
    def build_subscriptions_list(subscriptions)
      text = "#{I18n.t('telegram_bot.channels.list.title')}\n\n"
      text += "#{I18n.t('telegram_bot.channels.list.total', count: subscriptions.count)}\n\n"

      subscriptions.each do |subscription|
        channel = subscription.channel
        text += "• #{channel.title.present? ? channel.title : "@#{channel.username}"}"
        text += "\n"
      end

      text
    end

    # Построить inline клавиатуру для управления подписками
    def subscriptions_keyboard(subscriptions)
      return nil if subscriptions.empty?

      keyboard = subscriptions.map do |subscription|
        keyboard_row(
          callback_button(
            I18n.t('telegram_bot.channels.list.buttons.remove'),
            "remove_channel:#{subscription.channel_id}"
          )
        )
      end

      inline_keyboard(*keyboard)
    end
  end
end
