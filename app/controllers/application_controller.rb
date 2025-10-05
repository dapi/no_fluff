class ApplicationController < ActionController::API
  # Global error handling for all API controllers
  rescue_from StandardError do |exception|
    Rails.logger.error "Application Error: #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.first(10).join("\n")

    Bugsnag.notify(exception, metadata: {
      context: "Application Controller",
      controller: controller_name,
      action: action_name,
      request_path: request.path,
      request_method: request.method,
      error_class: exception.class.name,
      error_message: exception.message
    })

    render json: {
      error: "Internal server error",
      message: I18n.t("errors.general", default: "Something went wrong")
    }, status: :internal_server_error
  end

  rescue_from ActiveRecord::RecordInvalid do |exception|
    Rails.logger.error "Validation Error: #{exception.message}"

    Bugsnag.notify(exception, metadata: {
      context: "Application Validation Error",
      controller: controller_name,
      action: action_name,
      validation_errors: exception.record&.errors&.full_messages
    })

    render json: {
      error: "Validation failed",
      message: exception.record&.errors&.full_messages || ["Invalid data"]
    }, status: :unprocessable_entity
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: {
      error: "Not found",
      message: I18n.t("errors.not_found", default: "Resource not found")
    }, status: :not_found
  end
end
