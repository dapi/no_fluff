# Фоновая задача для сохранения поста в БД и запуска доставки
class Content::ProcessPostJob < ApplicationJob
  queue_as :content

  def perform(channel_id, post_data)
    with_error_context(channel_id: channel_id, post_data: post_data, action: 'process_post') do
      channel = Channel.find(channel_id)

      post = post_data.is_a?(Hash) ? create_post(channel, post_data) : Post.find(post_data)
      Rails.logger.info "Processing post #{post.telegram_message_id} from channel #{channel.username}"

      # Проверяем, может ли бот мониторить канал
      unless channel.bot_can_monitor? || channel.user_can_monitor?
        Rails.logger.info "Skipping post processing: channel cannot be monitored #{channel.username}"
        return
      end

      # Bot webhook payloads are retained only for backwards-compatible
      # persistence. The MTProto path below always supplies a persisted post id
      # and is the sole path that classifies and delivers imported content.
      return if post_data.is_a?(Hash)

      classify(post) unless post.classified?
      return unless deliverable?(post)

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
    channel.posts.create_or_find_by!(telegram_message_id: post_data[:telegram_message_id]) do |post|
      post.assign_attributes(
      telegram_message_id: post_data[:telegram_message_id],
      text: post_data[:text],
      media_urls: post_data[:media_urls],
      published_at: post_data[:published_at],
      # Устанавливаем базовые значения для полей, которые могут использоваться в будущем
      importance_score: 0,
      is_ad: false,
      is_fluff: false,
      is_duplicate_of: nil
      )
    end
  end

  def classify(post)
    result = Content::PostClassifier.new.classify(post)
    post.update!(
      importance_score: result.fetch(:importance_score),
      is_important: result.fetch(:deliverable),
      is_fluff: !result.fetch(:deliverable),
      classification_data: result.slice(:deliverable, :confidence)
    )
  end

  def deliverable?(post)
    post.classified? && post.is_important? && !post.is_ad? && !post.is_fluff?
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
