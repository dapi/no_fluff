# Сервис для проверки лимитов подписок пользователей
module Limits
  class LimitChecker
    # Лимит бесплатных каналов
    FREE_CHANNELS_LIMIT = 10

    def initialize(user)
      @user = user
    end

    # Проверяет может ли пользователь добавить новый канал
    # @return [Boolean] - true если можно добавить, false если достигнут лимит
    def can_add_channel?
      return true if @user.is_premium?

      @user.channels_count < FREE_CHANNELS_LIMIT
    end

    # Проверяет достигнут ли лимит каналов для пользователя
    # @return [Boolean] - true если лимит достигнут, false если еще можно добавлять
    def limit_reached?
      return false if @user.is_premium?

      @user.channels_count >= FREE_CHANNELS_LIMIT
    end

    # Возвращает текущее количество каналов пользователя
    # @return [Integer]
    def current_channels_count
      @user.channels_count
    end

    # Возвращает оставшееся количество бесплатных каналов
    # @return [Integer] - 0 если лимит достигнут или пользователь премиум
    def remaining_free_channels
      return 0 if @user.is_premium?

      remaining = FREE_CHANNELS_LIMIT - @user.channels_count
      remaining > 0 ? remaining : 0
    end

    # Возвращает информацию о текущем статусе лимитов
    # @return [Hash] - детальная информация о лимитах пользователя
    def limit_status
      {
        current_count: current_channels_count,
        limit: FREE_CHANNELS_LIMIT,
        remaining: remaining_free_channels,
        is_premium: @user.is_premium?,
        can_add_more: can_add_channel?,
        limit_reached: limit_reached?
      }
    end

    # Проверяет указанное количество каналов на превышение лимита
    # @param requested_count [Integer] - запрашиваемое количество каналов
    # @return [Boolean] - true если указанное количество не превышает лимит
    def can_add_channels?(requested_count)
      return true if @user.is_premium?

      (@user.channels_count + requested_count) <= FREE_CHANNELS_LIMIT
    end

    # Возвращает сообщение о достижении лимита
    # @return [String] - локализованное сообщение
    def limit_reached_message
      I18n.t('telegram_bot.channels.add.limit_reached',
              limit: FREE_CHANNELS_LIMIT,
              current: current_channels_count)
    end

    private

    attr_reader :user
  end
end