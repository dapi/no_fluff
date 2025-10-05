# Сервис для удобной отправки ошибок в Bugsnag с контекстом
class ErrorNotificationService
  class << self
    # Отправить ошибку с базовым контекстом
    def notify(exception, context: nil, user: nil, metadata: {})
      return unless defined?(Bugsnag)

      Bugsnag.notify(exception) do |report|
        report.context = context if context
        report.add_metadata(:custom, metadata) if metadata.any?

        if user
          report.user = {
            id: user.id,
            username: user.username,
            email: user.email
          }
        end
      end
    end

    # Отправить ошибку из Telegram бота
    def notify_telegram_error(exception, user: nil, action: nil, metadata: {})
      notify(exception,
        context: "Telegram Bot",
        user: user,
        metadata: metadata.merge(
          action: action,
          controller: "TelegramWebhookController"
        )
      )
    end

    # Отправить ошибку из фоновой задачи
    def notify_job_error(exception, job_class:, job_id: nil, attempt: nil, metadata: {})
      notify(exception,
        context: "Background Job",
        metadata: metadata.merge(
          job_class: job_class.to_s,
          job_id: job_id,
          attempt: attempt
        )
      )
    end

    # Отправить ошибку API
    def notify_api_error(exception, endpoint:, method:, user: nil, metadata: {})
      notify(exception,
        context: "API Error",
        user: user,
        metadata: metadata.merge(
          endpoint: endpoint,
          method: method
        )
      )
    end

    # Отправить ошибку сервиса
    def notify_service_error(exception, service:, method:, user: nil, metadata: {})
      notify(exception,
        context: "Service Error",
        user: user,
        metadata: metadata.merge(
          service: service.to_s,
          method: method
        )
      )
    end
  end
end