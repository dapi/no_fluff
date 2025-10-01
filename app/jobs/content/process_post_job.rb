# Фоновая задача для сохранения поста в БД и запуска доставки
class Content::ProcessPostJob < ApplicationJob
  queue_as :content

  def perform(channel_id, post_data)
    channel = Channel.find(channel_id)

    Rails.logger.info "Processing post #{post_data[:telegram_message_id]} from channel #{channel.username}"

    # Создаем пост в БД
    post = channel.posts.create!(
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

    Rails.logger.info "Created post #{post.id} in database"

    # Получаем всех активных подписчиков канала
    subscribers = channel.telegram_users.joins(:subscriptions)
                           .where(subscriptions: { active: true })

    Rails.logger.info "Found #{subscribers.count} subscribers for channel #{channel.username}"

    # Для каждого подписчика запускаем задачу доставки поста
    subscribers.each do |user|
      begin
        Content::DeliverPostsJob.perform_later(user.id, [ post.id ])

        Rails.logger.debug "Scheduled delivery for post #{post.id} to user #{user.username}"
      rescue StandardError => e
        Rails.logger.error "Error scheduling delivery for user #{user.username}: #{e.message}"
      end
    end

    Rails.logger.info "Completed processing post #{post.id}"
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Error creating post: #{e.message}"
    Rails.logger.error e.record.errors.full_messages.join(", ")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Channel #{channel_id} not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Error processing post: #{e.message}"
    raise
  end
end
