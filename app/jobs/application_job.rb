class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Handle Telegram API errors specifically
  rescue_from Telegram::Bot::Error do |exception|
    Rails.logger.warn(
      "Telegram API error in job: #{self.class.name}",
      job_id: job_id,
      error: exception.message
    )

    ErrorNotificationService.notify_job_error(exception,
      job_class: self.class,
      job_id: job_id,
      metadata: {
        error_type: "Telegram API Error",
        arguments: sanitized_arguments
      }
    )
    # Don't retry Telegram API errors automatically
  end

  # Handle database record not found errors
  rescue_from ActiveRecord::RecordNotFound do |exception|
    Rails.logger.info(
      "Record not found in job: #{self.class.name}",
      job_id: job_id,
      error: exception.message
    )

    ErrorNotificationService.notify_job_error(exception,
      job_class: self.class,
      job_id: job_id,
      metadata: {
        error_type: "Record Not Found",
        model: exception.model&.name,
        arguments: sanitized_arguments
      }
    )
    # Don't retry if record doesn't exist
  end

  # Handle record validation errors - log validation details
  rescue_from ActiveRecord::RecordInvalid do |exception|
    ErrorNotificationService.notify_job_error(exception,
      job_class: self.class,
      job_id: job_id,
      metadata: {
        error_type: "Validation Error",
        validation_errors: exception.record&.errors&.full_messages,
        arguments: sanitized_arguments
      }
    )
  end

  # Global error handling for other errors
  rescue_from StandardError do |exception|
    # Log the error with context
    Rails.logger.error(
      "Job failed: #{self.class.name}",
      job_id: job_id,
      arguments: arguments,
      error: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace.first(5)
    )

    # Send to Bugsnag with full context
    ErrorNotificationService.notify_job_error(exception,
      job_class: self.class,
      job_id: job_id,
      attempt: executions,
      metadata: {
        error_class: exception.class.name,
        error_message: exception.message,
        arguments: sanitized_arguments
      }
    )

    # Re-raise to allow retry logic to work
    raise exception
  end

  private

  # Sanitize arguments for logging (remove sensitive data)
  def sanitized_arguments
    return [] unless arguments.respond_to?(:map)

    arguments.map do |arg|
      case arg
      when String
        arg.length > 100 ? "#{arg[0..97]}..." : arg
      when Hash
        arg.slice(:id, :user_id, :channel_id, :post_id, :action)
      else
        arg.class.name
      end
    end
  end

  # Helper method to add context to error handling
  def with_error_context(context)
    @error_context = context
    yield
  ensure
    @error_context = nil
  end

  # Get current error context if set
  def current_error_context
    @error_context || {}
  end
end
