# Клиент для получения постов из Telegram каналов
module TelegramClient
  class ChannelFetcher
    # Лимит постов за один запрос
    POSTS_LIMIT = 20

    def initialize(bot)
      @bot = bot
    end

    # Получает последние посты из канала
    # @param channel_username [String] - username канала без @
    # @param limit [Integer] - количество постов для получения
    # @param offset_id [Integer, nil] - ID сообщения для пагинации
    # @return [Array<Hash>] - массив постов
    def get_channel_posts(channel_username, limit: POSTS_LIMIT, offset_id: nil)
      return [] if channel_username.blank?

      chat_id = channel_username.start_with?('@') ? channel_username : "@#{channel_username}"

      begin
        # Проверяем доступность канала
        unless channel_available?(channel_username)
          Rails.logger.warn "Channel #{channel_username} is not available"
          return []
        end

        # Для реального бота здесь должна быть логика получения постов через:
        # 1. Webhooks (посты приходят автоматически)
        # 2. get_chat_history (если бот имеет права администратора)
        # 3. Другие методы API

        # Для демонстрации работы системы создадим тестовый пост
        # В реальной реализации этот метод будет получать реальные посты
        if Rails.env.development?
          generate_demo_post(channel_username)
        else
          Rails.logger.info "Channel #{channel_username} is accessible, but post fetching requires proper setup"
          []
        end

      rescue StandardError => e
        Bugsnag.notify(e) { |b| b.metadata = { channel_username: channel_username, action: 'get_channel_posts' } }
        Rails.logger.error "Error fetching posts for #{channel_username}: #{e.message}"
        []
      end
    end

    # Проверяет доступность канала
    # @param channel_username [String] - username канала без @
    # @return [Boolean]
    def channel_available?(channel_username)
      return false if channel_username.blank?

      chat_id = channel_username.start_with?('@') ? channel_username : "@#{channel_username}"

      begin
        response = @bot.api.get_chat(chat_id: chat_id)
        response['ok'] && response['result'] && response['result']['type'] == 'channel'
      rescue StandardError => e
        Bugsnag.notify(e) { |b| b.metadata = { channel_username: channel_username, action: 'channel_available?' } }
        Rails.logger.error "Error checking channel availability for #{channel_username}: #{e.message}"
        false
      end
    end

    # Получает информацию о канале
    # @param channel_username [String] - username канала без @
    # @return [Hash, nil]
    def get_channel_info(channel_username)
      return nil if channel_username.blank?

      chat_id = channel_username.start_with?('@') ? channel_username : "@#{channel_username}"

      begin
        response = @bot.api.get_chat(chat_id: chat_id)

        if response['ok'] && response['result'] && response['result']['type'] == 'channel'
          chat = response['result']
          {
            id: chat['id'],
            title: chat['title'],
            username: chat['username'],
            description: chat['description'],
            invite_link: chat['invite_link'],
            member_count: chat['member_count'] || 0
          }
        else
          nil
        end
      rescue StandardError => e
        Bugsnag.notify(e) { |b| b.metadata = { channel_username: channel_username, action: 'get_channel_info' } }
        Rails.logger.error "Error getting channel info for #{channel_username}: #{e.message}"
        nil
      end
    end

    private

    # Нормализует сообщение в стандартный формат
    # @param message [Hash] - сообщение от Telegram API
    # @return [Hash, nil]
    def normalize_message(message)
      return nil unless message.is_a?(Hash)

      # Пропускаем сервисные сообщения
      return nil if message['text'].blank? && message['caption'].blank?

      # Извлекаем текст
      text = message['text'] || message['caption'] || ''

      # Извлекаем медиа URL
      media_urls = extract_media_urls(message)

      {
        telegram_message_id: message['message_id'],
        text: text,
        media_urls: media_urls,
        published_at: Time.at(message['date']),
        has_media: media_urls.any?
      }
    end

    # Извлекает URL медиафайлов из сообщения
    # @param message [Hash]
    # @return [Array<String>]
    def extract_media_urls(message)
      urls = []

      # Фото
      if message['photo']
        # Берем самое большое фото
        photo_sizes = message['photo'].is_a?(Array) ? message['photo'] : [ message['photo'] ]
        largest_photo = photo_sizes.max_by { |p| p['file_size'] || 0 }
        if largest_photo
          urls << "photo:#{largest_photo["file_id"]}"
        end
      end

      # Видео
      if message['video']
        urls << "video:#{message["video"]["file_id"]}"
      end

      # Документ
      if message['document']
        urls << "document:#{message["document"]["file_id"]}"
      end

      # Аудио
      if message['audio']
        urls << "audio:#{message["audio"]["file_id"]}"
      end

      # Стикеры и GIF не включаем
      urls
    end

    # Генерирует демо пост для тестирования (только в development)
    # @param channel_username [String]
    # @return [Array<Hash>]
    def generate_demo_post(channel_username)
      return [] unless Rails.env.development?

      # Генерируем пост только иногда, чтобы не засорять логи
      return [] unless rand < 0.1 # 10% шанс

      demo_texts = [
        '🚀 Новые технологии в искусственном интеллекте меняют подход к разработке ПО. Ученые представили прорывной алгоритм...',
        '📈 Рынок криптовалют продолжает расти. Биткоин достиг новой отметки, эксперты делятся прогнозами...',
        '💡 Полезный совет по продуктивности: Как управлять временем эффективно в эпоху цифровых отвлечений...',
        '🔒 Важные новости о кибербезопасности: Новый вирус обнаружен в популярных приложениях...'
      ]

      [ {
        telegram_message_id: rand(1000000..9999999),
        text: demo_texts.sample,
        media_urls: [],
        published_at: Time.current,
        has_media: false
      } ]
    end
  end
end
