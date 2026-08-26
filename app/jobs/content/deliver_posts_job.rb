# Фоновая задача для доставки постов пользователю через форвардинг
class Content::DeliverPostsJob < ApplicationJob
  class DeliveryFailed < StandardError; end

  queue_as :content

  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(user_id, post_ids)
    with_error_context(user_id: user_id, post_ids: post_ids, action: 'deliver_posts') do
      user = TelegramUser.find(user_id)
      posts = Post.where(id: post_ids)

      Rails.logger.info "Delivering #{posts.count} posts to user #{user.username}"

      # Получаем инстанс бота
      bot = Telegram.bot

      posts.each do |post|
        deliver_single_post(user, post, bot)
      end

      Rails.logger.info "Completed delivery to user #{user.username}"
    end
  end

  private

  def deliver_single_post(user, post, bot)
    post.with_lock do
      return if Delivery.exists?(telegram_user: user, post: post)

      response = bot.send_message(
        chat_id: user.telegram_id,
        text: delivery_text(post)
      )
      raise DeliveryFailed, 'Telegram Bot API rejected delivery' unless response['ok']

      Delivery.create!(telegram_user: user, post: post, metadata: { telegram_message_id: post.telegram_message_id })
      Rails.logger.debug "Successfully delivered post #{post.id} to user #{user.username}"
    end
  rescue StandardError => e
    Rails.logger.error "Failed to deliver post #{post.id} to user #{user.id}: #{e.class}"
    raise
  end

  def delivery_text(post)
    source_url = "https://t.me/#{post.channel.username}/#{post.telegram_message_id}"
    [ post.text.to_s, "Источник: #{source_url}" ].join("\n\n")
  end
end
