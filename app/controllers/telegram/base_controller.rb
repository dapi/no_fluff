# Базовый контроллер для Telegram команд
class Telegram::BaseController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext
  include AdminSessionManagement
  include ControllerErrorHandling

  before_action :find_or_create_user

  protected

  def find_or_create_user
    user_data = from
    username = user_data['username'] || "user_#{user_data['id']}"

    @current_user ||= TelegramUser.find_or_create_by(username: username) do |user|
      user.first_name = user_data['first_name']
      user.last_name = user_data['last_name']
      user.language_code = user_data['language_code'] || 'ru'
      user.is_premium = user_data['is_premium'] || false
      user.is_bot = user_data['is_bot'] || false
    end
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
