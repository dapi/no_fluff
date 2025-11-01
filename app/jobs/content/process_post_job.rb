# Фоновая задача для сохранения поста в БД и запуска доставки
class Content::ProcessPostJob < ApplicationJob
  queue_as :content

  def perform(channel_id, post_data)
    with_error_context(channel_id: channel_id, post_data: post_data, action: 'process_post') do
      channel = Channel.find(channel_id)

      Rails.logger.info "Processing post #{post_data[:telegram_message_id]} from channel #{channel.username}"

      # Проверяем, может ли бот мониторить канал
      unless channel.bot_can_monitor?
        Rails.logger.info "Skipping post processing: bot cannot monitor channel #{channel.username} (status: #{channel.bot_join_status}, active: #{channel.active?})"
        return
      end

      # Создаем пост в БД
      post = create_post(channel, post_data)

      Rails.logger.info "Created post #{post.id} in database"

      # Получаем всех активных подписчиков канала
      subscribers = channel.telegram_users.joins(:subscriptions)
                             .where(subscriptions: { active: true })

      Rails.logger.info "Found #{subscribers.count} subscribers for channel #{channel.username}"

      # Для каждого подписчика запускаем задачу доставки поста
      subscribers.each do |user|
        schedule_delivery_for_user(user, post)
      end

      Rails.logger.info "Completed processing post #{post.id}"
    end
  end

  private

  def create_post(channel, post_data)
    channel.posts.create!(
      telegram_message_id: post_data[:telegram_message_id],
      text: post_data[:text],
      media_urls: post_data[:media_urls],
      published_at: post_data[:published_at],
      # Устанавливаем базовые значения для полей, которые могут использоваться в будущем
      importance_score: 50, # средняя важность по умолчанию
      is_ad: false,
      is_fluff: false,
      is_duplicate_of: nil
    )
  end

  def schedule_delivery_for_user(user, post)
    Content::DeliverPostsJob.perform_later(user.id, [ post.id ])
    Rails.logger.debug "Scheduled delivery for post #{post.id} to user #{user.username}"
  rescue StandardError => e
    # Handle individual user scheduling errors without failing the entire job
    handle_error(e,
                 metadata: {
                   user_id: user.id,
                   post_id: post.id,
                   action: 'schedule_delivery'
                 },
                 severity: :warn,
                 reraise: false)
  end
end
