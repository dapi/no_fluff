class ApplicationJob < ActiveJob::Base
  include JobErrorHandling

  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

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
