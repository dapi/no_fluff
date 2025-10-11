# frozen_string_literal: true

module ControllerErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from Telegram::Bot::Error do |exception|
      log_error("Telegram API Error", exception)
      ErrorNotificationService.notify_telegram_error(exception,
        user: current_user,
        action: action_name,
        metadata: {
          controller: self.class.name,
          error_type: "Telegram API Error"
        }
      )
      respond_with :message, text: I18n.t("telegram_bot.errors.telegram_api")
    end

    rescue_from ActiveRecord::RecordNotFound do |exception|
      log_error("Record Not Found", exception)
      ErrorNotificationService.notify_telegram_error(exception,
        user: current_user,
        action: action_name,
        metadata: {
          controller: self.class.name,
          error_type: "Record Not Found"
        }
      )
      respond_with :message, text: I18n.t("telegram_bot.errors.not_found")
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      log_error("Record Invalid", exception)
      ErrorNotificationService.notify_telegram_error(exception,
        user: current_user,
        action: action_name,
        metadata: {
          controller: self.class.name,
          error_type: "Validation Error",
          validation_errors: exception.record.errors.full_messages
        }
      )
      respond_with :message, text: I18n.t("telegram_bot.errors.validation")
    end

    rescue_from StandardError do |exception|
      log_error("StandardError", exception)
      ErrorNotificationService.notify_telegram_error(exception,
        user: current_user,
        action: action_name,
        metadata: {
          controller: self.class.name,
          error_type: "StandardError"
        }
      )
      respond_with :message, text: I18n.t("telegram_bot.errors.general")
    end
  end

  private

  def log_error(error_type, exception)
    Rails.logger.error "[#{error_type}] in #{self.class.name}##{action_name}: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
  end
end