# Фоновая задача для получения новых постов из канала
class Channels::FetchPostsJob < ApplicationJob
  queue_as :channels

  retry_on StandardError, wait: 1.minute, attempts: 3

  def perform(channel_id)
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
        return
      end

      # Получаем последние посты
      posts_data = fetcher.get_channel_posts(channel.username, limit: 20)

      Rails.logger.info "Fetched #{posts_data.count} posts from channel #{channel.username}"

      # Обновляем время последнего поста если есть посты
      if posts_data.any?
        channel.update_last_post!
      end

      # Обрабатываем каждый пост
      posts_data.each do |post_data|
        process_single_post(channel, post_data)
      end

      # Отмечаем успешное обновление канала
      channel.mark_as_successfully_updated

      Rails.logger.info "Completed fetching posts for channel #{channel.username}"
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
    Rails.logger.error "Error processing post #{post_data[:telegram_message_id]}: #{e.message}"

    ErrorNotificationService.notify_job_error(e,
      job_class: self.class,
      job_id: job_id,
      metadata: {
        error_type: "Post Processing Error",
        channel_id: channel.id,
        channel_username: channel.username,
        message_id: post_data[:telegram_message_id],
        action: 'process_single_post',
        severity: 'warning'
      }
    )
  end
end
