# Рефакторинг основной контроллер Telegram бота
# Теперь использует специализированные контроллеры для разных типов команд
class TelegramWebhookControllerRefactored < Telegram::BaseController
  include Telegram::SubscriptionCommands
  include Telegram::SettingsCommands
  include Telegram::KeyboardHelpers
  include Telegram::MediaHandlers
  include Telegram::AdminCommands
  include Telegram::FollowerUserCommands

  # Делегируем команды в специализированные контроллеры
  def start!(*)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.start!
  end

  def help!(*)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.help!
  end

  def settings!(*)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.settings!
  end

  def add!(*args)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.add!(*args)
  end

  def remove!(*args)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.remove!(*args)
  end

  def debug!(*)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.debug!
  end

  def set_commands!(*)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.set_commands!
  end

  def message(message)
    Telegram::CommandsController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.message(message)
  end

  # Обработка callback query
  def callback_query(data = nil, *args)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query(data, *args)
  end

  # Сохраняем совместимость с существующими concerns
  def show_commands_callback_query(*)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query('show_commands')
  end

  def start_onboarding_callback_query(*)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query('start_onboarding')
  end

  def more_info_callback_query(*)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query('more_info')
  end

  def back_to_start_callback_query(*)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query('back_to_start')
  end

  def settings_callback_query(*)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query('settings')
  end

  def set_delivery_frequency_callback_query(frequency = nil)
    data = frequency ? "set_delivery_frequency:#{frequency}" : 'set_delivery_frequency'
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query(data)
  end

  def set_content_format_callback_query(format = nil)
    data = format ? "set_content_format:#{format}" : 'set_content_format'
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query(data)
  end

  def set_filter_strictness_callback_query(strictness = nil)
    data = strictness ? "set_filter_strictness:#{strictness}" : 'set_filter_strictness'
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query(data)
  end

  def activate_subscription_callback_query(*)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query('activate_subscription')
  end

  def show_subscription_offer_callback_query(*)
    Telegram::CallbacksController.new.tap { |c| c.instance_variable_set(:@bot, bot); c.instance_variable_set(:@current_user, current_user); c.instance_variable_set(:@payload, payload) }.callback_query('show_subscription_offer')
  end
end
