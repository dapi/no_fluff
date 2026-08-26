# Фоновая задача для доставки постов пользователю через форвардинг
class Content::DeliverPostsJob < ApplicationJob
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
    response = bot.send_message(
      chat_id: user.telegram_id,
      text: delivery_text(post)
    )

    if response['ok']
      Rails.logger.debug "Successfully forwarded post #{post.id} to user #{user.username}"
    else
      Rails.logger.error "Failed to forward post #{post.id} to user #{user.username}: #{response["description"]}"
    end

    # Небольшая задержка между сообщениями чтобы избежать rate limits
    sleep(0.1)
  rescue StandardError => e
    Rails.logger.error "Failed to deliver post #{post.id} to user #{user.id}: #{e.class}"
    raise
  end

  def delivery_text(post)
    source_url = "https://t.me/#{post.channel.username}/#{post.telegram_message_id}"
    [ post.text.to_s, "Источник: #{source_url}" ].join("\n\n")
  end
end
