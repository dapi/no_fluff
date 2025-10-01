# Фоновая задача для доставки постов пользователю через форвардинг
class Content::DeliverPostsJob < ApplicationJob
  queue_as :content

  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(user_id, post_ids)
    user = TelegramUser.find(user_id)
    posts = Post.where(id: post_ids)

    Rails.logger.info "Delivering #{posts.count} posts to user #{user.username}"

    # Получаем инстанс бота
    bot = Telegram.bots[:default]

    posts.each do |post|
      begin
        # Форвардим сообщение пользователю
        response = bot.api.forward_message(
          chat_id: user.telegram_id, # chat_id пользователя
          from_chat_id: post.channel.telegram_id, # ID канала
          message_id: post.telegram_message_id # ID сообщения в канале
        )

        if response["ok"]
          Rails.logger.debug "Successfully forwarded post #{post.id} to user #{user.username}"
        else
          Rails.logger.error "Failed to forward post #{post.id} to user #{user.username}: #{response["description"]}"
        end

        # Небольшая задержка между сообщениями чтобы избежать rate limits
        sleep(0.1)

      rescue StandardError => e
        Rails.logger.error "Error forwarding post #{post.id} to user #{user.username}: #{e.message}"

        # Если ошибка связана с отсутствием прав или удаленным постом, логируем и продолжаем
        if e.message.include?("Bad Request") || e.message.include?("not found")
          Rails.logger.warn "Skipping post #{post.id} due to access restrictions or deletion"
          next
        else
          # Для других ошибок пробуем еще раз (retry_on обработает)
          raise
        end
      end
    end

    Rails.logger.info "Completed delivery to user #{user.username}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "User #{user_id} or posts not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Error delivering posts to user #{user_id}: #{e.message}"
    raise
  end
end