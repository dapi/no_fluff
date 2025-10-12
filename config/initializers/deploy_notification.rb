# frozen_string_literal: true

# Инициализатор для создания уведомлений о деплое
# Запускается после загрузки приложения, создает запись о новой версии
# если такой версии еще нет в базе данных

Rails.application.config.after_initialize do
  # Запускаем только для серверных процессов или в production
  next unless defined?(Rails::Server) || Rails.env.production?

  begin
    version = AppVersion.to_s

    DeployNotification.find_or_create_by(version: version)
  rescue => e
    Bugsnag.notify(e, { context: 'deploy_notification_initializer' })
    Rails.logger.error "Deploy notification initialization failed: #{e.message}"
  end
end
