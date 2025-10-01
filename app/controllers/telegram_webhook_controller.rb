# Основной контроллер для обработки обновлений от Telegram Bot API
# Документация: https://github.com/telegram-bot-rb/telegram-bot
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext
  include Telegram::SubscriptionCommands

  # Обработка ошибок
  rescue_from StandardError do |exception|
    Rails.logger.error "Telegram Bot Error: #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    respond_with :message, text: I18n.t('telegram_bot.errors.general')
  end

  # Команда /start - приветствие и краткая инструкция
  def start!(*)
    # Создаём или находим пользователя
    find_or_create_user

    # Отправляем приветственное сообщение с inline кнопками
    respond_with :message,
      text: I18n.t('telegram_bot.start.welcome'),
      reply_markup: start_keyboard
  end

  # Команда /help - список доступных команд
  def help!(*)
    respond_with :message, text: I18n.t('telegram_bot.help.commands')
  end

  
  # Команда /add - добавление канала
  def add!(*args)
    find_or_create_user

    # Если передан username канала сразу в команде: /add @channelname
    if args.any?
      channel_input = args.join(' ')
      add_channel(channel_input)
    else
      # Показываем инструкцию
      respond_with :message, text: I18n.t('telegram_bot.channels.add.prompt')
    end
  end

  # Команда /remove - удаление канала
  def remove!(*args)
    find_or_create_user

    # Если передан username канала сразу в команде: /remove @channelname
    if args.any?
      channel_input = args.join(' ')
      remove_channel(channel_input)
    else
      # Показываем инструкцию
      respond_with :message, text: I18n.t('telegram_bot.channels.remove.prompt')
    end
  end

  # Callback query: начать онбординг
  def start_onboarding_callback_query(*)
    answer_callback_query('')
    edit_message :text,
      text: I18n.t('telegram_bot.onboarding.add_channels'),
      reply_markup: onboarding_keyboard
  end

  # Callback query: показать подробную информацию
  def more_info_callback_query(*)
    answer_callback_query('')
    edit_message :text,
      text: I18n.t('telegram_bot.more_info.text'),
      reply_markup: more_info_keyboard
  end

  # Callback query: вернуться к началу из подробной информации
  def back_to_start_callback_query(*)
    answer_callback_query('')
    edit_message :text,
      text: I18n.t('telegram_bot.start.welcome'),
      reply_markup: start_keyboard
  end


  # Обработка обычных текстовых сообщений
  def message(message)
    text = message['text']

    # Если пользователь отправил текст, пробуем интерпретировать как канал
    # (только если текст начинается с @ или содержит t.me/)
    if text.start_with?('@') || text.include?('t.me/')
      find_or_create_user
      add_channel(text)
    else
      respond_with :message, text: "Вы написали: #{text}"
    end
  end

  private

  # Добавляет канал для текущего пользователя
  def add_channel(channel_input)
    service = Telegram::ChannelService.new(bot)
    result = service.add_channel_for_user(current_user, channel_input)

    respond_with :message, text: result[:message]
  end

  # Удаляет канал для текущего пользователя
  def remove_channel(channel_input)
    # Парсим username канала
    username = channel_input.to_s.strip

    # Убираем @ в начале если есть
    username = username[1..-1] if username.start_with?('@')

    # Извлекаем username из URL если нужно
    if username.match?(%r{^https?://t\.me/})
      username = username.match(%r{^https?://t\.me/([a-zA-Z0-9_]+)})&.[](1)
    elsif username.match?(%r{^t\.me/})
      username = username.match(%r{^t\.me/([a-zA-Z0-9_]+)})&.[](1)
    end

    if username.blank? || !username.match?(/\A[a-zA-Z0-9_]{5,32}\z/)
      respond_with :message, text: I18n.t('telegram_bot.channels.remove.invalid_format')
      return
    end

    # Ищем канал в БД
    channel = Channel.find_by("username ILIKE ?", username)

    unless channel
      respond_with :message, text: I18n.t('telegram_bot.channels.remove.not_found', channel: "@#{username}")
      return
    end

    # Ищем активную подписку
    subscription = current_user.subscriptions.active.find_by(channel: channel)

    unless subscription
      respond_with :message, text: I18n.t('telegram_bot.channels.remove.not_subscribed', channel: "@#{channel.username}")
      return
    end

    # Деактивируем подписку
    subscription.deactivate!

    respond_with :message, text: I18n.t('telegram_bot.channels.remove.success',
                                           channel: "@#{channel.username}",
                                           count: current_user.subscriptions.active.count)
  rescue StandardError => e
    Rails.logger.error "Error removing channel: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    respond_with :message, text: I18n.t('telegram_bot.channels.remove.error', error: e.message)
  end


  # Inline клавиатура для команды /start
  def start_keyboard
    kb = [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: I18n.t('telegram_bot.start.button_start'),
          callback_data: 'start_onboarding:'
        ),
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: I18n.t('telegram_bot.start.button_more_info'),
          callback_data: 'more_info:'
        )
      ]
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end

  # Inline клавиатура для подробной информации
  def more_info_keyboard
    kb = [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: I18n.t('telegram_bot.more_info.button_lets_start'),
          callback_data: 'start_onboarding:'
        )
      ],
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: '← Назад',
          callback_data: 'back_to_start:'
        )
      ]
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end

  # Inline клавиатура для онбординга
  def onboarding_keyboard
    kb = [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: I18n.t('telegram_bot.onboarding.button_my_subscriptions'),
          callback_data: 'my_subscriptions:'
        )
      ]
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
end
