# Фоновая задача для мониторинга активных каналов
# Запускается периодически и проверяет наличие новых постов в каналах
class Channels::MonitorJob < ApplicationJob
  queue_as :channels

  # Интервал запуска в секундах (5 минут)
  RUN_INTERVAL = 5.minutes

  def perform(*args)
    Rails.logger.info "Starting channel monitoring"

    # Получаем все активные каналы, за которыми есть подписки
    channels = Channel.joins(:subscriptions)
                     .where(subscriptions: { active: true })
                     .where(active: true)
                     .needs_monitoring

    Rails.logger.info "Found #{channels.count} channels to monitor"

    channels.each do |channel|
      begin
        # Запускаем задачу для получения постов из канала
        Channels::FetchPostsJob.perform_later(channel.id)

        # Обновляем время последней проверки
        channel.mark_as_monitored!

        Rails.logger.debug "Scheduled fetch job for channel #{channel.username}"
      rescue StandardError => e
        Rails.logger.error "Error scheduling fetch for channel #{channel.username}: #{e.message}"
      end
    end

    Rails.logger.info "Channel monitoring completed"
  end
end