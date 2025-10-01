# Основной контроллер для обработки обновлений от Telegram Bot API
# Документация: https://github.com/telegram-bot-rb/telegram-bot
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext

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
    respond_with :message, text: "Вы написали: #{text}"
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

  # Возвращает текущего пользователя
  def current_user
    @current_user
  end
end
