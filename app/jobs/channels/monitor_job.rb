# Фоновая задача для мониторинга активных каналов
# Запускается периодически и проверяет наличие новых постов в каналах
class Channels::MonitorJob < ApplicationJob
  queue_as :channels

  # Интервал запуска в секундах (5 минут)
  RUN_INTERVAL = 5.minutes

  def perform(*args)
    start_time = Time.current
    processed_channels = 0
    skipped_channels = 0
    skip_reasons = {}

    begin
      Rails.logger.info 'Starting channel monitoring'

      # Получаем все активные каналы, за которыми есть подписки
      channels = Channel.joins(:subscriptions)
                       .where(subscriptions: { active: true })
                       .where(active: true)
                       .needs_monitoring

      Rails.logger.info "Found #{channels.count} channels to monitor"

      channels.each do |channel|
        with_error_context(channel_id: channel.id, channel_username: channel.username) do
          # Запускаем задачу для получения постов из канала
          Channels::FetchPostsJob.perform_later(channel.id)
          processed_channels += 1

          # Обновляем время последней проверки
          channel.mark_as_monitored!

          Rails.logger.debug "Scheduled fetch job for channel #{channel.username}"
        end
      end

      Rails.logger.info 'Channel monitoring completed'

      # Логируем успешное завершение мониторинга
      log_monitor_results(
        job_id: job_id,
        execution_time_ms: ((Time.current - start_time) * 1000).to_i,
        total_channels: channels.count,
        processed_channels: processed_channels,
        skipped_channels: skipped_channels,
        skip_reasons: skip_reasons,
        status: 'success',
        message: "Monitoring completed: #{processed_channels} channels processed, #{skipped_channels} channels skipped"
      )

    rescue StandardError => e
      # Логируем ошибку выполнения мониторинга
      log_monitor_results(
        job_id: job_id,
        execution_time_ms: ((Time.current - start_time) * 1000).to_i,
        total_channels: channels&.count || 0,
        processed_channels: processed_channels,
        skipped_channels: skipped_channels,
        skip_reasons: skip_reasons,
        status: 'error',
        message: "Monitoring failed: #{e.message}",
        errors: [e.message]
      )

      raise e
    end
  end

  private

  def log_monitor_results(job_id:, execution_time_ms:, total_channels:, processed_channels:, skipped_channels:, skip_reasons:, status:, message:, errors: [])
    data = {
      total_channels: total_channels,
      processed_channels: processed_channels,
      skipped_channels: skipped_channels,
      skip_reasons: skip_reasons,
      errors: errors || []
    }

    ChannelUpdateLog.create!(
      source: 'MonitorJob',
      message: message,
      status: status,
      job_id: job_id,
      execution_time_ms: execution_time_ms,
      data: data
    )
  rescue StandardError => e
    # Не даем ошибкам логирования прервать основную операцию
    Rails.logger.error "Failed to log monitor results: #{e.message}"
  end
end
