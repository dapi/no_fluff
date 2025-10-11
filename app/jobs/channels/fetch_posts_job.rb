# Фоновая задача для получения новых постов из канала
class Channels::FetchPostsJob < ApplicationJob
  queue_as :channels

  retry_on StandardError, wait: 1.minute, attempts: 3

  def perform(channel_id)
    start_time = Time.current
    channel = nil
    posts_count = 0
    new_posts_count = 0
    errors = []

    begin
      with_error_context(channel_id: channel_id, action: 'fetch_posts') do
        channel = Channel.find(channel_id)

        Rails.logger.info "Fetching posts for channel #{channel.username}"

        # Получаем Telegram ID канала
        chat_id = channel.telegram_id.to_s

        # Инициализируем клиент
        bot = Telegram.bots[:default]
        fetcher = TelegramClient::ChannelFetcher.new(bot)

        # Проверяем доступность канала
        unless fetcher.channel_available?(channel.username)
          Rails.logger.warn "Channel #{channel.username} is not available, deactivating"
          channel.deactivate!

          log_fetch_results(
            channel: channel,
            job_id: job_id,
            execution_time_ms: ((Time.current - start_time) * 1000).to_i,
            posts_count: 0,
            new_posts_count: 0,
            status: 'warning',
            message: "Channel #{channel.username} is not available and was deactivated",
            errors: ['Channel not available']
          )
          return
        end

        # Получаем последние посты
        posts_data = fetcher.get_channel_posts(channel.username, limit: 20)
        posts_count = posts_data.count

        Rails.logger.info "Fetched #{posts_data.count} posts from channel #{channel.username}"

        # Обновляем время последнего поста если есть посты
        if posts_data.any?
          channel.update_last_post!
        end

        # Обрабатываем каждый пост
        posts_data.each do |post_data|
          begin
            process_single_post(channel, post_data)
            new_posts_count += 1
          rescue StandardError => e
            errors << "Failed to process post #{post_data[:telegram_message_id]}: #{e.message}"
            Rails.logger.error "Error processing post #{post_data[:telegram_message_id]}: #{e.message}"
          end
        end

        Rails.logger.info "Completed fetching posts for channel #{channel.username}"

        # Логируем успешное завершение
        log_fetch_results(
          channel: channel,
          job_id: job_id,
          execution_time_ms: ((Time.current - start_time) * 1000).to_i,
          posts_count: posts_count,
          new_posts_count: new_posts_count,
          status: errors.empty? ? 'success' : 'warning',
          message: "Processed #{posts_count} posts, #{new_posts_count} new posts from #{channel.username}",
          errors: errors
        )
      end
    rescue StandardError => e
      # Логируем ошибку выполнения всего job
      log_fetch_results(
        channel: channel,
        job_id: job_id,
        execution_time_ms: ((Time.current - start_time) * 1000).to_i,
        posts_count: posts_count,
        new_posts_count: new_posts_count,
        status: 'error',
        message: "Failed to fetch posts from channel #{channel&.username || channel_id}: #{e.message}",
        errors: [e.message]
      )

      raise e
    end
  end

  private

  def process_single_post(channel, post_data)
    # Проверяем, нет ли уже такого поста в БД
    existing_post = Post.find_by(
      channel: channel,
      telegram_message_id: post_data[:telegram_message_id]
    )

    if existing_post
      Rails.logger.debug "Post #{post_data[:telegram_message_id]} already exists, skipping"
      return
    end

    # Запускаем задачу для сохранения и обработки поста
    Content::ProcessPostJob.perform_later(channel.id, post_data)

    Rails.logger.debug "Scheduled processing for post #{post_data[:telegram_message_id]}"
  rescue StandardError => e
    # Handle individual post processing errors without failing the entire job
    handle_error(e,
                 metadata: {
                   channel_id: channel.id,
                   message_id: post_data[:telegram_message_id],
                   action: 'process_single_post'
                 },
                 severity: :warn,
                 reraise: false)
  end

  def log_fetch_results(channel:, job_id:, execution_time_ms:, posts_count:, new_posts_count:, status:, message:, errors: [])
    data = {
      posts_processed: posts_count,
      new_posts: new_posts_count,
      errors: errors
    }

    ChannelUpdateLog.create!(
      source: 'FetchPostsJob',
      message: message,
      status: status,
      channel: channel,
      job_id: job_id,
      execution_time_ms: execution_time_ms,
      data: data
    )
  rescue StandardError => e
    # Не даем ошибкам логирования прервать основную операцию
    Rails.logger.error "Failed to log fetch results: #{e.message}"
  end
end
