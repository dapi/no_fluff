# frozen_string_literal: true

module JobErrorHandling
  extend ActiveSupport::Concern

  included do
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    rescue_from Telegram::Bot::Error do |exception|
      log_job_error('Telegram API Error', exception)
      ErrorNotificationService.notify_job_error(exception,
        job_class: self.class,
        job_id: job_id,
        metadata: {
          error_type: 'Telegram API Error',
          arguments: sanitized_arguments
        }
      )
    end

    rescue_from ActiveRecord::RecordNotFound do |exception|
      log_job_error('Record Not Found', exception)
      ErrorNotificationService.notify_job_error(exception,
        job_class: self.class,
        job_id: job_id,
        metadata: {
          error_type: 'Record Not Found',
          model: exception.model&.name
        }
      )
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      log_job_error('Validation Error', exception)
      ErrorNotificationService.notify_job_error(exception,
        job_class: self.class,
        job_id: job_id,
        metadata: {
          error_type: 'Validation Error',
          validation_errors: exception.record.errors.full_messages
        }
      )
    end

    rescue_from StandardError do |exception|
      log_job_error('StandardError', exception)
      ErrorNotificationService.notify_job_error(exception,
        job_class: self.class,
        job_id: job_id,
        metadata: {
          error_type: 'StandardError',
          arguments: sanitized_arguments
        }
      )
    end
  end

  private

  def log_job_error(error_type, exception)
    Rails.logger.error "[Job #{error_type}] in #{self.class.name} ##{job_id}: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.first(10).join("\n")
  end

  def sanitized_arguments
    return {} unless arguments.present?

    arguments.map do |arg|
      case arg
      when TelegramUser
        { class: 'TelegramUser', id: arg.id, username: arg.username }
      when Channel
        { class: 'Channel', id: arg.id, username: arg.username }
      when Hash
        arg.slice(:telegram_message_id, :text, :photo_url, :video_url).compact
      else
        arg.class.name
      end
    end
  end
end
