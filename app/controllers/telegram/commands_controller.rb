# Контроллер для основных команд Telegram бота
class Telegram::CommandsController < Telegram::BaseController
  # Команда /start
  def start!(*)
    route_to_command_class(Telegram::Commands::StartCommand)
  end

  # Команда /help
  def help!(*)
    route_to_command_class(Telegram::Commands::HelpCommand)
  end

  # Команда /settings
  def settings!(*)
    route_to_command_class(Telegram::Commands::SettingsCommand)
  end

  # Команда /add
  def add!(*args)
    route_to_command_class(Telegram::Commands::ChannelCommand, :add, args.join(' '))
  end

  # Команда /remove
  def remove!(*args)
    route_to_command_class(Telegram::Commands::ChannelCommand, :remove, args.join(' '))
  end

  # Административные команды
  def debug!(*)
    route_to_command_class(Telegram::Commands::AdminCommand, :debug)
  end

  def set_commands!(*)
    route_to_command_class(Telegram::Commands::AdminCommand, :set_commands)
  end

  # Обработка текстовых сообщений
  def message(message)
    route_to_command_class(Telegram::Commands::MessageCommand, message)
  end
end
