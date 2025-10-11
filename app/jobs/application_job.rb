class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Handle record not found errors - log and notify but don't fail the job
  rescue_from ActiveRecord::RecordNotFound do |exception|
    handle_error(exception, action: 'record_not_found', severity: :warn, reraise: false)
  end

  # Handle record validation errors - log validation details
  rescue_from ActiveRecord::RecordInvalid do |exception|
    metadata = {
      action: 'record_invalid',
      record_errors: exception.record&.errors&.full_messages&.join(', ')
    }
    handle_error(exception, metadata: metadata, severity: :error, reraise: false)
  end

  # Handle all other standard errors
  rescue_from StandardError do |exception|
    handle_error(exception, action: 'job_failed', severity: :error, reraise: true)
  end

  private

  # Unified error handling with Bugsnag notification, debug notifications and logging
  def handle_error(exception, metadata: {}, action: nil, severity: :error, reraise: true)
    # Build metadata for Bugsnag and logging
    error_metadata = build_error_metadata(metadata.merge(action: action))

    # Send to Bugsnag
    Bugsnag.notify(exception) do |b|
      b.metadata = error_metadata
      b.severity = severity
    end

    # Send debug notification if debug mode is enabled
    debug_message = "#{severity.to_s.capitalize} in #{self.class.name}: #{exception.message}"
    debug_context = error_metadata.merge(
      severity: severity,
      action: action,
      timestamp: Time.current.iso8601
    )
    DebugNotifier.notify_error(exception, debug_context, debug_message)

    # Log the error with context
    log_error(exception, error_metadata, severity)

    # Re-raise if requested to allow retry logic to work
    raise exception if reraise
  end

  # Build base error metadata with job context
  def build_error_metadata(additional_metadata = {})
    base_metadata = {
      job_class: self.class.name,
      job_id: job_id,
      arguments: sanitized_arguments,
      error_class: exception_class_name(additional_metadata[:exception])
    }

    base_metadata.merge(additional_metadata.compact)
  end

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

  # Extract exception class name safely
  def exception_class_name(exception)
    exception&.class&.name || 'Unknown'
  end

  # Log error with appropriate level and context
  def log_error(exception, metadata, severity)
    log_message = "#{severity.to_s.capitalize} in #{metadata[:job_class]}: #{exception.message}"

    case severity
    when :debug
      Rails.logger.debug(log_message, metadata)
    when :info
      Rails.logger.info(log_message, metadata)
    when :warn
      Rails.logger.warn(log_message, metadata)
    else
      Rails.logger.error(log_message, metadata)
      Rails.logger.error(exception.backtrace&.first(10)&.join("\n"))
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
