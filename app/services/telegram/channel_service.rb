# Сервис для работы с Telegram каналами
module Telegram
  class ChannelService
    # Лимит бесплатных каналов
    FREE_CHANNELS_LIMIT = 10

    def initialize(bot)
      @bot = bot
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
        if DebugNotifier.enabled?
          DebugNotifier.notify_error(e, {
            service: self.class.name,
            username: username,
            action: 'get_channel_info',
            timestamp: Time.current.iso8601
          }, "Error getting channel info for #{username}: #{e.message}")
        end

        Rails.logger.error "Error getting channel info for #{username}: #{e.message}"
        nil
      end
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
      unless user.is_premium
        current_count = user.subscriptions.active.count
        if current_count >= FREE_CHANNELS_LIMIT
          return {
            success: false,
            message: I18n.t('telegram_bot.channels.add.limit_reached', limit: FREE_CHANNELS_LIMIT)
          }
        end
      end

      # Получаем информацию о канале
      channel_info = get_channel_info(username)

      unless channel_info
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.add.not_found', channel: "@#{username}")
        }
      end

      # Находим или создаем канал в БД
      channel = Channel.find_or_initialize_by(telegram_id: channel_info[:id])

      if channel.new_record?
        channel.assign_attributes(
          username: channel_info[:username] || username,
          title: channel_info[:title],
          description: channel_info[:description],
          subscribers_count: channel_info[:member_count]
        )

        unless channel.save
          return {
            success: false,
            message: I18n.t('telegram_bot.channels.add.error', error: channel.errors.full_messages.join(', '))
          }
        end
      else
        # Обновляем информацию о канале
        channel.update(
          title: channel_info[:title],
          description: channel_info[:description],
          subscribers_count: channel_info[:member_count],
          active: true
        )
      end

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
                           count: user.subscriptions.active.count),
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
      subscription = user.subscriptions.build(
        channel: channel,
        active: true
      )

      if subscription.save
        {
          success: true,
          message: I18n.t('telegram_bot.channels.add.success',
                         channel: "@#{channel.username}",
                         count: user.subscriptions.active.count),
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
      if DebugNotifier.enabled?
        DebugNotifier.notify_error(e, {
          service: self.class.name,
          user_id: user.id,
          channel_username: channel_username,
          action: 'add_channel_for_user',
          timestamp: Time.current.iso8601
        }, "Error adding channel #{channel_username} for user #{user.id}: #{e.message}")
      end

      Rails.logger.error "Error adding channel for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        message: I18n.t('telegram_bot.channels.add.error', error: e.message)
      }
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

      # Ищем любую подписку (активную или неактивную)
      subscription = user.subscriptions.find_by(channel: channel)

      unless subscription
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.remove.not_subscribed', channel: "@#{channel.username}")
        }
      end

      # Если подписка неактивна
      unless subscription.active?
        return {
          success: false,
          message: I18n.t('telegram_bot.channels.remove.not_subscribed', channel: "@#{channel.username}")
        }
      end

      # Деактивируем подписку
      subscription.deactivate!

      {
        success: true,
        message: I18n.t('telegram_bot.channels.remove.success',
                       channel: "@#{channel.username}",
                       count: user.subscriptions.active.count),
        channel: channel
      }
    rescue StandardError => e
      Bugsnag.notify(e) { |b| b.metadata = { user_id: user.id, channel_username: channel_username, action: 'remove_channel_for_user' } }
      Rails.logger.error "Error removing channel for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        message: I18n.t('telegram_bot.channels.remove.error', error: e.message)
      }
    end
  end
end
