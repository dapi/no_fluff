# Основной контроллер для обработки обновлений от Telegram Bot API
# Документация: https://github.com/telegram-bot-rb/telegram-bot
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext
  include Telegram::SubscriptionCommands
  include Telegram::SettingsCommands
  include Telegram::KeyboardHelpers

  # Выполняем перед каждым действием
  before_action :find_or_create_user

  # Обработка ошибок
  rescue_from StandardError do |exception|
    Rails.logger.error "Telegram Bot Error: #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    respond_with :message, text: I18n.t("telegram_bot.errors.general")
  end

  # Команда /start - приветствие и краткая инструкция
  def start!(*)
    # Отправляем приветственное сообщение с inline кнопками
    respond_with :message,
      text: I18n.t("telegram_bot.start.welcome"),
      reply_markup: start_keyboard
  end

  # Команда /help - список доступных команд
  def help!(*)
    respond_with :message, text: I18n.t("telegram_bot.help.commands")
  end


  # Команда /add - добавление канала
  def add!(*args)
    # Если передан username канала сразу в команде: /add @channelname
    if args.any?
      channel_input = args.join(" ")
      add_channel(channel_input)
    else
      # Показываем инструкцию
      respond_with :message, text: I18n.t("telegram_bot.channels.add.prompt")
    end
  end

  # Команда /remove - удаление канала
  def remove!(*args)
    # Если передан username канала сразу в команде: /remove @channelname
    if args.any?
      channel_input = args.join(" ")
      remove_channel(channel_input)
    else
      # Показываем инструкцию
      respond_with :message, text: I18n.t("telegram_bot.channels.remove.prompt")
    end
  end

  # Callback query: начать онбординг
  def start_onboarding_callback_query(*)
    answer_callback_query("")
    edit_message :text,
      text: I18n.t("telegram_bot.onboarding.add_channels"),
      reply_markup: onboarding_keyboard
  end

  # Callback query: показать подробную информацию
  def more_info_callback_query(*)
    answer_callback_query("")
    edit_message :text,
      text: I18n.t("telegram_bot.more_info.text"),
      reply_markup: more_info_keyboard
  end

  # Callback query: вернуться к началу из подробной информации
  def back_to_start_callback_query(*)
    answer_callback_query("")
    edit_message :text,
      text: I18n.t("telegram_bot.start.welcome"),
      reply_markup: start_keyboard
  end


  # Обработка обычных текстовых сообщений
  def message(message)
    text = message["text"]

    # Если пользователь отправил текст, пробуем интерпретировать как канал
    # (только если текст начинается с @ или содержит t.me/)
    if text.start_with?("@") || text.include?("t.me/")
      add_channel(text)
    else
      respond_with :message, text: "Вы написали: #{text}"
    end
  end

  private

  # Находит или создаёт пользователя в БД
  def find_or_create_user
    user_data = from
    # Используем username если есть, иначе используем id в качестве username
    username = user_data["username"] || "user_#{user_data['id']}"

    @current_user ||= TelegramUser.find_or_create_by(username: username) do |user|
      user.first_name = user_data["first_name"]
      user.last_name = user_data["last_name"]
      user.language_code = user_data["language_code"] || "ru"
      user.is_premium = user_data["is_premium"] || false
      user.is_bot = user_data["is_bot"] || false
    end

    # Ничего дополнительно обновлять не нужно - telegram_id будет браться из ID записи
  end

  # Возвращает текущего пользователя
  def current_user
    @current_user
  end

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
    username = username[1..-1] if username.start_with?("@")

    # Извлекаем username из URL если нужно
    if username.match?(%r{^https?://t\.me/})
      username = username.match(%r{^https?://t\.me/([a-zA-Z0-9_]+)})&.[](1)
    elsif username.match?(%r{^t\.me/})
      username = username.match(%r{^t\.me/([a-zA-Z0-9_]+)})&.[](1)
    end

    if username.blank? || !username.match?(/\A[a-zA-Z0-9_]{5,32}\z/)
      respond_with :message, text: I18n.t("telegram_bot.channels.remove.invalid_format")
      return
    end

    # Ищем канал в БД
    channel = Channel.find_by("username ILIKE ?", username)

    unless channel
      respond_with :message, text: I18n.t("telegram_bot.channels.remove.not_found", channel: "@#{username}")
      return
    end

    # Ищем активную подписку
    subscription = current_user.subscriptions.active.find_by(channel: channel)

    unless subscription
      respond_with :message, text: I18n.t("telegram_bot.channels.remove.not_subscribed", channel: "@#{channel.username}")
      return
    end

    # Деактивируем подписку
    subscription.deactivate!

    respond_with :message, text: I18n.t("telegram_bot.channels.remove.success",
                                           channel: "@#{channel.username}",
                                           count: current_user.subscriptions.active.count)
  rescue StandardError => e
    Rails.logger.error "Error removing channel: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    respond_with :message, text: I18n.t("telegram_bot.channels.remove.error", error: e.message)
  end


  # Inline клавиатура для команды /start
  def start_keyboard
    inline_keyboard(
      keyboard_row(
        callback_button(I18n.t("telegram_bot.start.button_start"), "start_onboarding:"),
        callback_button(I18n.t("telegram_bot.start.button_more_info"), "more_info:")
      ),
      keyboard_row(
        callback_button("⚙️ Настройки", "settings:")
      )
    )
  end

  # Inline клавиатура для подробной информации
  def more_info_keyboard
    inline_keyboard(
      keyboard_row(
        callback_button(I18n.t("telegram_bot.more_info.button_lets_start"), "start_onboarding:")
      ),
      keyboard_row(
        callback_button("← Назад", "back_to_start:")
      )
    )
  end

  # Inline клавиатура для онбординга
  def onboarding_keyboard
    inline_keyboard(
      keyboard_row(
        callback_button(I18n.t("telegram_bot.onboarding.button_my_subscriptions"), "my_subscriptions:")
      )
    )
  end
end
