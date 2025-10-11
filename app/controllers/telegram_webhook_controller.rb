# Основной контроллер для обработки обновлений от Telegram Bot API
# Документация: https://github.com/telegram-bot-rb/telegram-bot
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext
  include Telegram::SubscriptionCommands
  include Telegram::SettingsCommands
  include Telegram::KeyboardHelpers
  include Telegram::MediaHandlers
  include AdminSessionManagement
  include ControllerErrorHandling

  # Выполняем перед каждым действием
  before_action :find_or_create_user

  # Команда /start - приветствие и краткая инструкция
  def start!(*)
    # Проверяем, есть ли в системе администраторы
    unless TelegramUser.any_admins?
      # Назначаем текущего пользователя администратором
      current_user.update!(is_admin: true)

      # Отправляем специальное сообщение для первого администратора
      respond_with :message,
        text: I18n.t('telegram_bot.start.first_admin') + "\n\n" + I18n.t('telegram_bot.start.welcome'),
        reply_markup: start_keyboard
    else
      # Обычное приветственное сообщение
      respond_with :message,
        text: I18n.t('telegram_bot.start.welcome'),
        reply_markup: start_keyboard
    end
  end

  # Команда /help - список доступных команд
  def help!(*)
    if current_user&.is_admin?
      # Показываем расширенную справку для администраторов
      help_text = I18n.t('telegram_bot.help.commands') + "\n\n" +
                  I18n.t('telegram_bot.help.admin_commands')
      respond_with :message, text: help_text
    else
      # Обычная справка для пользователей
      respond_with :message, text: I18n.t('telegram_bot.help.commands')
    end
  end

  # Команда /settings - показать настройки
  def settings!(*)
    agent = Telegram::SettingsAgent.new(bot, current_user)
    agent.show_settings
  end

  # Команда /add - добавление канала
  def add!(*args)
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

  # Callback query: показать настройки
  def settings_callback_query(*)
    answer_callback_query('')

    agent = Telegram::SettingsAgent.new(bot, current_user)
    # Для callback нужно редактировать сообщение, а не отправлять новое
    # Но SettingsAgent отправляет новое сообщение, поэтому используем edit_message
    settings_text = agent.send(:build_settings_text)
    settings_keyboard = agent.send(:build_settings_keyboard)

    edit_message :text,
      text: settings_text,
      reply_markup: settings_keyboard
  end

  # Callback query: установить частоту доставки
  def set_delivery_frequency_callback_query(frequency = nil)
    if frequency
      agent = Telegram::SettingsAgent.new(bot, current_user)
      agent.update_setting('delivery_frequency', frequency)
    end
    answer_callback_query('')
  end

  # Callback query: установить формат контента
  def set_content_format_callback_query(format = nil)
    if format
      agent = Telegram::SettingsAgent.new(bot, current_user)
      agent.update_setting('content_format', format)
    end
    answer_callback_query('')
  end

  # Callback query: установить строгость фильтрации
  def set_filter_strictness_callback_query(strictness = nil)
    if strictness
      agent = Telegram::SettingsAgent.new(bot, current_user)
      agent.update_setting('filter_strictness', strictness)
    end
    answer_callback_query('')
  end

  # Обработка обычных текстовых сообщений
  def message(message)
    text = message['text']

    # Если пользователь отправил текст, пробуем интерпретировать как канал
    # (только если текст начинается с @ или содержит t.me/)
    if text.start_with?('@') || text.include?('t.me/')
      add_channel(text)
    else
      # Показываем простое сообщение без использования сессий
      response_text = I18n.t('telegram_bot.messages.user_message', text: text)
      respond_with :message, text: response_text
    end
  end

  # Callback query: оформить подписку
  def activate_subscription_callback_query(*)
    answer_callback_query('')

    manager = SubscriptionManagement::Manager.new(current_user)
    result = manager.activate_premium_subscription

    if result[:success]
      # Показываем сообщение об успехе
      if payload['message']
        edit_message :text, text: result[:message]
      else
        respond_with :message, text: result[:message]
      end
    else
      # Показываем сообщение об ошибке
      error_message = result[:message]
      if payload['message']
        edit_message :text, text: error_message
      else
        respond_with :message, text: error_message
      end
    end
  end

  # Callback query: показать предложение подписки
  def show_subscription_offer_callback_query(*)
    answer_callback_query('')

    manager = SubscriptionManagement::Manager.new(current_user)
    offer = manager.subscription_offer

    # Создаем клавиатуру с предложением подписки
    offer_keyboard = inline_keyboard(
      keyboard_row(
        callback_button(offer[:activate_button_text], 'activate_subscription:')
      ),
      keyboard_row(
        callback_button(I18n.t('telegram_bot.messages.back'), 'my_subscriptions:')
      )
    )

    text = offer[:message]

    if payload['message']
      edit_message :text, text: text, reply_markup: offer_keyboard
    else
      respond_with :message, text: text, reply_markup: offer_keyboard
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
      user.is_bot = user_data['is_bot'] || false
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

    if result[:success]
      # Канал успешно добавлен
      respond_with :message, text: result[:message]
      respond_with :message, text: I18n.t('telegram_bot.channels.add.suggest_another')
    else
      # Ошибка при добавлении - проверяем связана ли она с лимитом
      limit_checker = Limits::LimitChecker.new(current_user)
      if limit_checker.limit_reached?
        # Показываем сообщение об ошибке и предложение подписки
        respond_with :message, text: result[:message]

        manager = SubscriptionManagement::Manager.new(current_user)
        offer = manager.subscription_offer

        offer_keyboard = inline_keyboard(
          keyboard_row(
            callback_button(offer[:activate_button_text], 'activate_subscription:')
          ),
          keyboard_row(
            callback_button('Мои подписки', 'my_subscriptions:')
          )
        )

        respond_with :message, text: offer[:message], reply_markup: offer_keyboard
      else
        # Другая ошибка - просто показываем сообщение
        respond_with :message, text: result[:message]
      end
    end
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
    channel = Channel.find_by('username ILIKE ?', username)

    unless channel
      respond_with :message, text: I18n.t('telegram_bot.channels.remove.not_found', channel: "@#{username}")
      return
    end

    # Ищем подписку
    subscription = current_user.subscriptions.find_by(channel: channel)

    unless subscription
      respond_with :message, text: I18n.t('telegram_bot.channels.remove.not_subscribed', channel: "@#{channel.username}")
      return
    end

    # Удаляем подписку
    subscription.destroy

    respond_with :message, text: I18n.t('telegram_bot.channels.remove.success',
                                           channel: "@#{channel.username}",
                                           count: current_user.subscriptions.count)
  end


  # Inline клавиатура для команды /start
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

  # Inline клавиатура для подробной информации
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

  # Inline клавиатура для онбординга
  def onboarding_keyboard
    inline_keyboard(
      keyboard_row(
        callback_button(I18n.t('telegram_bot.onboarding.button_my_subscriptions'), 'my_subscriptions:')
      )
    )
  end
end
