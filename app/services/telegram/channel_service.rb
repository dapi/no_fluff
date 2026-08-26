# Сервис для работы с Telegram каналами
module Telegram
  class ChannelService
    def initialize(bot = Telegram.bot, follower_user: nil, mtproto_client: nil)
      @bot = bot
      @follower_user = follower_user
      @mtproto_client = mtproto_client
    end

    # Парсит username канала из различных форматов
    # @param input [String] - может быть @username, username, t.me/username, https://t.me/username
    # @return [String, nil] - username без @, или nil если невалидный формат
    def parse_channel_username(input)
      return nil if input.blank?

      # Убираем пробелы
      input = input.strip

      # Если это URL
      if input.match?(%r{^https?://t\.me/})
        # Извлекаем username из URL: https://t.me/channelname
        username = input.match(%r{^https?://t\.me/([a-zA-Z0-9_]+)})&.[](1)
        return username
      elsif input.match?(%r{^t\.me/})
        # Извлекаем username из URL: t.me/channelname
        username = input.match(%r{^t\.me/([a-zA-Z0-9_]+)})&.[](1)
        return username
      elsif input.start_with?('@')
        # Убираем @ в начале
        username = input[1..-1]
        return username if valid_username?(username)
      elsif valid_username?(input)
        # Просто username без @
        return input
      end

      nil
    end

    # Проверяет валидность username
    # Telegram usernames: 5-32 символов, только буквы, цифры и подчеркивания
    def valid_username?(username)
      return false if username.blank?
      username.match?(/\A[a-zA-Z0-9_]{5,32}\z/)
    end

    # Получает информацию о канале через Telegram API
    # @param username [String] - username канала без @
    # @return [Hash, nil] - информация о канале или nil если не найден
    def get_channel_info(username)
      return nil if username.blank?

      # Добавляем @ если его нет
      chat_id = username.start_with?('@') ? username : "@#{username}"

      begin
        response = @bot.get_chat(chat_id: chat_id)

        # Проверяем что это канал
        if response['ok'] && response['result']
          chat = response['result']

          # Проверяем что это именно канал (не группа, не приватный чат)
          return nil unless chat['type'] == 'channel'

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
        Bugsnag.notify(e) { |b| b.metadata = { username: username, action: 'get_channel_info' } }

        # Отправляем debug уведомление если включен режим отладки
        DebugNotifier.notify_error(e, {
          service: self.class.name,
          username: username,
          action: 'get_channel_info',
          timestamp: Time.current.iso8601
        }, "Error getting channel info for #{username}: #{e.message}")

        ErrorNotificationService.notify_service_error(e,
        service: self.class,
        method: 'get_channel_info',
        metadata: {
          username: username,
          error_class: e.class.name,
          error_message: e.message
        }
      )
        Rails.logger.error "Error getting channel info for #{username}: #{e.message}"
        nil
      end
    end

    # Добавляет или обновляет канал в базе данных по username
    # @param channel_username [String] - username канала (может быть в разных форматах)
    # @return [Hash] - результат операции { success: true/false, channel: Channel, message: String }
    def add_channel_to_database(channel_username)
      # Парсим username
      username = parse_channel_username(channel_username)

      unless username
        return {
          success: false,
          channel: nil,
          message: I18n.t('telegram_bot.channels.add.invalid_format')
        }
      end

      channel_result = resolve_and_join_public_channel(username)
      unless channel_result[:success]
        return {
          success: false,
          channel: nil,
          message: channel_result[:message]
        }
      end

      channel_info = channel_result.fetch(:channel)
      follower_user = channel_result.fetch(:follower_user)
      channel = Channel.find_by(telegram_id: channel_info.fetch(:id)) || Channel.find_or_initialize_by(username: channel_info.fetch(:username))

      if channel.new_record?
        channel.assign_attributes(
          telegram_id: channel_info.fetch(:id),
          username: channel_info.fetch(:username),
          title: channel_info[:title],
          description: channel_info[:description],
          subscribers_count: channel_info[:member_count],
          follower_user: follower_user,
          assignment_status: :assigned,
          assigned_at: Time.current,
          user_access_status: :joined
        )

        unless channel.save
          return {
            success: false,
            channel: nil,
            message: I18n.t('telegram_bot.channels.add.error', error: channel.errors.full_messages.join(', '))
          }
        end

        follower_user.join_channel!
        channel.mark_user_join_success
      else
        channel.update(
          username: channel_info.fetch(:username),
          title: channel_info[:title],
          description: channel_info[:description],
          subscribers_count: channel_info[:member_count],
          follower_user: follower_user,
          assignment_status: :assigned,
          assigned_at: Time.current,
          user_access_status: :joined
        )
        channel.activate! unless channel.active?
      end

      {
        success: true,
        channel: channel,
        message: nil
      }
    rescue StandardError => e
      Bugsnag.notify(e) { |b| b.metadata = { channel_username: channel_username, action: 'add_channel_to_database' } }

      ErrorNotificationService.notify_service_error(e,
        service: self.class,
        method: 'add_channel_to_database',
        metadata: {
          channel_username: channel_username,
          error_class: e.class.name,
          error_message: e.message
        }
      )
      Rails.logger.error "Error adding channel to database: #{e.message}"

      {
        success: false,
        channel: nil,
        message: I18n.t('telegram_bot.channels.add.error', error: e.message)
      }
    end

    # Добавляет канал в подписки пользователя
    # @param user [TelegramUser] - пользователь
    # @param channel_username [String] - username канала
    # @return [Hash] - результат операции { success: true/false, message: String, channel: Channel }
    def add_channel_for_user(user, channel_username)
      # Парсим username
      username = parse_channel_username(channel_username)

      unless username
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.add.invalid_format')
        }
      end

      # Проверяем лимит каналов для бесплатных пользователей
      limit_checker = Limits::LimitChecker.new(user)
      unless limit_checker.can_add_channel?
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.add.limit_reached',
                         limit: ApplicationConfig.free_channels_limit,
                         current: limit_checker.current_channels_count)
        }
      end

      existing_subscription = user.subscriptions.joins(:channel).find_by(channels: { username: username })
      return existing_subscription_result(existing_subscription, user) if existing_subscription

      channel_result = add_channel_to_database(channel_username)

      unless channel_result[:success]
        return {
          success: false,
          message: channel_result[:message]
        }
      end

      channel = channel_result[:channel]

      # Проверяем, не подписан ли уже пользователь
      subscription = user.subscriptions.find_by(channel: channel)

      if subscription
        # Если подписка существует но неактивна - активируем
        if !subscription.active
          subscription.activate!
          return {
            success: true,
            message: I18n.t('telegram_bot.channels.add.success',
                           channel: "@#{channel.username}",
                           count: user.channels_count),
            channel: channel
          }
        else
          return {
            success: false,
            message: I18n.t('telegram_bot.channels.add.already_subscribed', channel: "@#{channel.username}")
          }
        end
      end

      # Создаем подписку
      subscription = user.subscriptions.build(channel: channel)

      if subscription.save
        Channels::MtprotoChannelSyncJob.perform_later(channel.id, channel.follower_user_id, Channels::MtprotoChannelSync::DEFAULT_LIMIT)
        {
          success: true,
          message: I18n.t('telegram_bot.channels.add.success',
                         channel: "@#{channel.username}",
                         count: user.channels_count),
          channel: channel
        }
      else
        {
          success: false,
          message: I18n.t('telegram_bot.channels.add.error', error: subscription.errors.full_messages.join(', '))
        }
      end
    rescue StandardError => e
      Bugsnag.notify(e) { |b| b.metadata = { user_id: user.id, channel_username: channel_username, action: 'add_channel_for_user' } }

      # Отправляем debug уведомление если включен режим отладки
      DebugNotifier.notify_error(e, {
        service: self.class.name,
        user_id: user.id,
        channel_username: channel_username,
        action: 'add_channel_for_user',
        timestamp: Time.current.iso8601
      }, "Error adding channel #{channel_username} for user #{user.id}: #{e.message}")

      ErrorNotificationService.notify_service_error(e,
        service: self.class,
        method: 'add_channel_for_user',
        user: user,
        metadata: {
          user_id: user.id,
          channel_username: channel_username,
          error_class: e.class.name,
          error_message: e.message
        }
      )
      Rails.logger.error "Error adding channel for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        message: I18n.t('telegram_bot.channels.add.error', error: e.message)
      }
    end

    def resolve_and_join_public_channel(username)
      follower_user = @follower_user || FollowerUser.next_available
      return mtproto_failure('telegram_bot.channels.add.mtproto_unavailable') unless follower_user&.authorized? && follower_user.session_string.present?

      client = @mtproto_client || UserClientMtproto.new(follower_user)
      resolved = client.resolve_channel("@#{username}")
      return mtproto_failure('telegram_bot.channels.add.not_found', channel: "@#{username}") unless resolved[:success]

      joined = client.join_channel("@#{username}")
      return mtproto_failure('telegram_bot.channels.add.mtproto_unavailable') unless joined[:success]

      { success: true, channel: joined.fetch(:channel).symbolize_keys, follower_user: follower_user }
    rescue StandardError => e
      Bugsnag.notify(e) { |bugsnag| bugsnag.metadata = { username: username, action: 'resolve_and_join_public_channel' } }
      mtproto_failure('telegram_bot.channels.add.mtproto_unavailable')
    end

    def mtproto_failure(key, **options)
      { success: false, message: I18n.t(key, **options) }
    end

    def existing_subscription_result(subscription, user)
      if subscription.active?
        { success: false, message: I18n.t('telegram_bot.channels.add.already_subscribed', channel: "@#{subscription.channel.username}") }
      else
        subscription.activate!
        { success: true, message: I18n.t('telegram_bot.channels.add.success', channel: "@#{subscription.channel.username}", count: user.channels_count), channel: subscription.channel }
      end
    end

    # Удаляет канал из подписок пользователя
    # @param user [TelegramUser] - пользователь
    # @param channel_username [String] - username канала
    # @return [Hash] - результат операции { success: true/false, message: String, channel: Channel }
    def remove_channel_for_user(user, channel_username)
      # Парсим username
      username = parse_channel_username(channel_username)

      unless username
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.remove.invalid_format')
        }
      end

      # Ищем канал в БД
      channel = Channel.find_by(username: username)

      unless channel
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.remove.not_found', channel: "@#{username}")
        }
      end

      # Ищем подписку
      subscription = user.subscriptions.find_by(channel: channel)

      unless subscription
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.remove.not_subscribed', channel: "@#{channel.username}")
        }
      end

      # Удаляем подписку
      subscription.destroy

      {
        success: true,
        message: I18n.t('telegram_bot.channels.remove.success',
                       channel: "@#{channel.username}",
                       count: user.channels_count),
        channel: channel
      }
    rescue StandardError => e
      ErrorNotificationService.notify_service_error(e,
        service: self.class,
        method: 'remove_channel_for_user',
        user: user,
        metadata: {
          user_id: user.id,
          channel_username: channel_username,
          error_class: e.class.name,
          error_message: e.message
        }
      )
      Rails.logger.error "Error removing channel for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        message: I18n.t('telegram_bot.channels.remove.error', error: e.message)
      }
    end
  end
end
