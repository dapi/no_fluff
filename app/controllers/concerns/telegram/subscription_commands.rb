# Модуль с командами для управления подписками на каналы
module Telegram::SubscriptionCommands
  extend ActiveSupport::Concern

  included do
    # Команда /list - показать список подписок
    def list!(*)
      find_or_create_user

      subscriptions = current_user.subscriptions.includes(:channel).active.by_priority

      if subscriptions.empty?
        respond_with :message, text: I18n.t('telegram_bot.channels.list.empty')
      else
        respond_with :message,
          text: build_subscriptions_list(subscriptions),
          reply_markup: subscriptions_keyboard(subscriptions)
      end
    end

    # Callback query: мои подписки
    def my_subscriptions_callback_query(*)
      answer_callback_query('')
      find_or_create_user

      subscriptions = current_user.subscriptions.includes(:channel).active.by_priority

      if subscriptions.empty?
        if payload['message']
          edit_message :text, text: I18n.t('telegram_bot.channels.list.empty')
        else
          respond_with :message, text: I18n.t('telegram_bot.channels.list.empty')
        end
      else
        if payload['message']
          edit_message :text,
            text: build_subscriptions_list(subscriptions),
            reply_markup: subscriptions_keyboard(subscriptions)
        else
          respond_with :message,
            text: build_subscriptions_list(subscriptions),
            reply_markup: subscriptions_keyboard(subscriptions)
        end
      end
    end

    # Callback query: удалить канал
    def remove_channel_callback_query(channel_id)
      answer_callback_query('')
      find_or_create_user

      subscription = current_user.subscriptions.active.find_by(channel_id: channel_id)
      if subscription
        channel = subscription.channel

        # Клавиатура для подтверждения
        confirm_kb = [
          [
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text: I18n.t('telegram_bot.channels.list.buttons.remove'),
              callback_data: "confirm_remove:#{channel_id}"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text: 'Отмена',
              callback_data: 'my_subscriptions:'
            )
          ]
        ]

        edit_message :text,
          text: I18n.t('telegram_bot.channels.list.confirm_remove', channel: "@#{channel.username}"),
          reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: confirm_kb)
      end
    end

    # Callback query: подтвердить удаление канала
    def confirm_remove_callback_query(channel_id)
      answer_callback_query('')
      find_or_create_user

      subscription = current_user.subscriptions.active.find_by(channel_id: channel_id)
      if subscription
        channel = subscription.channel
        subscription.deactivate!

        edit_message :text,
          text: I18n.t('telegram_bot.channels.list.remove_success', channel: "@#{channel.username}"),
          reply_markup: subscriptions_keyboard(current_user.subscriptions.active.by_priority)
      end
    end

    # Callback query: увеличить приоритет канала
    def priority_up_callback_query(channel_id)
      answer_callback_query('')
      find_or_create_user

      subscription = current_user.subscriptions.active.find_by(channel_id: channel_id)
      if subscription && subscription.priority < 10
        subscription.update(priority: subscription.priority + 1)

        # Обновляем сообщение с новым списком
        subscriptions = current_user.subscriptions.includes(:channel).active.by_priority
        if payload['message']
          edit_message :text,
            text: build_subscriptions_list(subscriptions),
            reply_markup: subscriptions_keyboard(subscriptions)
        else
          respond_with :message,
            text: build_subscriptions_list(subscriptions),
            reply_markup: subscriptions_keyboard(subscriptions)
        end
      end
    end

    # Callback query: уменьшить приоритет канала
    def priority_down_callback_query(channel_id)
      answer_callback_query('')
      find_or_create_user

      subscription = current_user.subscriptions.active.find_by(channel_id: channel_id)
      if subscription && subscription.priority > 1
        subscription.update(priority: subscription.priority - 1)

        # Обновляем сообщение с новым списком
        subscriptions = current_user.subscriptions.includes(:channel).active.by_priority
        if payload['message']
          edit_message :text,
            text: build_subscriptions_list(subscriptions),
            reply_markup: subscriptions_keyboard(subscriptions)
        else
          respond_with :message,
            text: build_subscriptions_list(subscriptions),
            reply_markup: subscriptions_keyboard(subscriptions)
        end
      end
    end

    private

    # Находит или создаёт пользователя в БД
    def find_or_create_user
      user_data = from
      # Используем username если есть, иначе используем id в качестве username
      username = user_data['username'] || "user_#{user_data['id']}"

      @current_user ||= TelegramUser.find_or_create_by(username: username) do |user|
        user.first_name = user_data['first_name']
        user.last_name = user_data['last_name']
        user.language_code = user_data['language_code'] || 'ru'
        user.is_premium = user_data['is_premium'] || false
      end
    end

    # Возвращает текущего пользователя
    def current_user
      @current_user
    end

    # Построить текст списка подписок
    def build_subscriptions_list(subscriptions)
      text = "#{I18n.t('telegram_bot.channels.list.title')}\n\n"
      text += "#{I18n.t('telegram_bot.channels.list.total', count: subscriptions.count)}\n\n"

      subscriptions.each do |subscription|
        channel = subscription.channel
        text += I18n.t('telegram_bot.channels.list.channel_info',
          channel: channel.title.present? ? channel.title : "@#{channel.username}",
          priority: subscription.priority)
        text += "\n"
      end

      text
    end

    # Построить inline клавиатуру для управления подписками
    def subscriptions_keyboard(subscriptions)
      return nil if subscriptions.empty?

      keyboard = subscriptions.map do |subscription|
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.channels.list.buttons.priority_up'),
            callback_data: "priority_up:#{subscription.channel_id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.channels.list.buttons.priority_down'),
            callback_data: "priority_down:#{subscription.channel_id}"
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.channels.list.buttons.remove'),
            callback_data: "remove_channel:#{subscription.channel_id}"
          )
        ]
      end

      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)
    end
  end
end