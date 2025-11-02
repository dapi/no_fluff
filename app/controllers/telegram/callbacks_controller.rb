# Контроллер для обработки callback query
class Telegram::CallbacksController < Telegram::BaseController
  # Основной обработчик callback query
  def callback_query(data = nil, *args)
    return unless data

    handler_class = determine_handler_class(data)
    route_to_callback_handler(handler_class, data)
  rescue NameError
    answer_callback_query(I18n.t('telegram_bot.errors.unknown_callback'))
  end

  private

  def determine_handler_class(data)
    action = data.split(':').first

    case action
    when 'settings', 'set_delivery_frequency', 'set_content_format', 'set_filter_strictness'
      if action.start_with?('set_')
        Telegram::CallbackHandlers::SettingUpdateHandler
      else
        Telegram::CallbackHandlers::SettingsHandler
      end
    when 'start_onboarding', 'more_info', 'back_to_start'
      Telegram::CallbackHandlers::OnboardingHandler
    when 'activate_subscription', 'show_subscription_offer'
      Telegram::CallbackHandlers::SubscriptionHandler
    when 'show_commands'
      Telegram::CallbackHandlers::AdminHandler
    else
      raise NameError, "Unknown callback action: #{action}"
    end
  end
end
