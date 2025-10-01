class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Global error handling
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

    # Re-raise to allow retry logic to work
    raise exception
  end
end
