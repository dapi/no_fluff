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
      bot = Telegram.bots[:default]

      posts.each do |post|
        deliver_single_post(user, post, bot)
      end

      Rails.logger.info "Completed delivery to user #{user.username}"
    end
  end

  private

  def deliver_single_post(user, post, bot)
    # Форвардим сообщение пользователю
    response = bot.api.forward_message(
      chat_id: user.telegram_id, # chat_id пользователя
      from_chat_id: post.channel.telegram_id, # ID канала
      message_id: post.telegram_message_id # ID сообщения в канале
    )

    if response['ok']
      Rails.logger.debug "Successfully forwarded post #{post.id} to user #{user.username}"
    else
      Rails.logger.error "Failed to forward post #{post.id} to user #{user.username}: #{response["description"]}"
    end

    # Небольшая задержка между сообщениями чтобы избежать rate limits
    sleep(0.1)
  rescue StandardError => e
    # Handle individual post delivery errors
    handle_post_delivery_error(e, user, post)
  end

  def handle_post_delivery_error(error, user, post)
    # Если ошибка связана с отсутствием прав или удаленным постом, логируем и продолжаем
    if error.message.include?('Bad Request') || error.message.include?('not found')
      Rails.logger.warn "Skipping post #{post.id} due to access restrictions or deletion"
      handle_error(error,
                   metadata: {
                     user_id: user.id,
                     post_id: post.id,
                     action: 'skip_post_delivery'
                   },
                   severity: :warn,
                   reraise: false)
      return
    end

    # Для других ошибок пробуем еще раз (retry_on обработает)
    handle_error(error,
                 metadata: {
                   user_id: user.id,
                   post_id: post.id,
                   action: 'forward_post'
                 },
                 severity: :error,
                 reraise: true)
  end
end
