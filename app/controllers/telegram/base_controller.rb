# Базовый контроллер для Telegram команд
class Telegram::BaseController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext
  include AdminSessionManagement
  include ControllerErrorHandling

  before_action :find_or_create_user

  protected

  def find_or_create_user
    @current_user ||= TelegramUser.from_telegram(from)
  end

  def current_user
    @current_user
  end

  # Маршрутизация команд к соответствующим классам
  def route_to_command_class(command_class, *args)
    command_class.new(bot, current_user, *args).call
  end

  # Маршрутизация callback к соответствующим обработчикам
  def route_to_callback_handler(handler_class, callback_data)
    handler_class.new(bot, current_user, callback_data, payload).call
  end
end
