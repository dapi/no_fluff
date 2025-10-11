# frozen_string_literal: true

# Инициализатор для создания уведомлений о деплое
# Запускается после загрузки приложения, создает запись о новой версии
# если такой версии еще нет в базе данных

Rails.application.config.after_initialize do
  # Запускаем только для серверных процессов или в production
  next unless defined?(Rails::Server) || Rails.env.production?

  begin
    version = AppVersion.to_s

    DeployNotification.find_or_create_by(version: version) do |record|
      record.metadata = build_deploy_metadata
    end
  rescue => e
    Bugsnag.notify(e, { context: "deploy_notification_initializer" })
    Rails.logger.error "Deploy notification initialization failed: #{e.message}"
  end
end

private

def build_deploy_metadata
  metadata = {}

  # Добавляем информацию о Git
  if system('which git > /dev/null 2>&1')
    git_commit = `git rev-parse --short HEAD 2>/dev/null`.strip
    git_branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
    git_remote = `git config --get remote.origin.url 2>/dev/null`.strip

    metadata[:git_commit] = git_commit unless git_commit.empty?
    metadata[:git_branch] = git_branch unless git_branch.empty?
    metadata[:git_remote] = git_remote unless git_remote.empty?
  end

  # Добавляем информацию о системе
  metadata[:ruby_version] = RUBY_VERSION
  metadata[:rails_version] = Rails.version
  metadata[:environment] = Rails.env
  metadata[:hostname] = `hostname`.strip if system('which hostname > /dev/null 2>&1')

  # Добавляем время деплоя
  metadata[:deployed_at] = Time.current.iso8601

  metadata
end