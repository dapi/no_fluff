# Сервис для управления подписками пользователей
module SubscriptionManagement
  class Manager
    def initialize(user)
      @user = user
    end

    # Активирует премиум статус для пользователя
    # @return [Hash] - результат операции { success: true/false, message: String }
    def activate_premium_subscription
      return { success: false, message: 'Пользователь уже имеет премиум статус' } if @user.is_premium?

      begin
        @user.update!(is_premium: true)

        {
          success: true,
          message: I18n.t('telegram_bot.subscription.success'),
          user: @user
        }
      rescue StandardError => e
        Rails.logger.error "Error activating premium subscription for user #{@user.id}: #{e.message}"
        Bugsnag.notify(e) { |b| b.metadata = { user_id: @user.id, action: 'activate_premium_subscription' } }

        {
          success: false,
          message: I18n.t('telegram_bot.subscription.error', error: e.message)
        }
      end
    end

    # Деактивирует премиум статус для пользователя
    # @return [Hash] - результат операции { success: true/false, message: String }
    def deactivate_premium_subscription
      return { success: false, message: 'Пользователь не имеет премиум статуса' } unless @user.is_premium?

      begin
        @user.update!(is_premium: false)

        # Проверяем не превышает ли количество каналов лимит после деактивации
        limit_checker = Limits::LimitChecker.new(@user)
        if limit_checker.limit_reached?
          {
            success: true,
            message: I18n.t('telegram_bot.subscription.deactivated_with_limit_warning',
                           limit: ApplicationConfig.free_channels_limit,
                           current: limit_checker.current_channels_count),
            user: @user,
            warning: true
          }
        else
          {
            success: true,
            message: I18n.t('telegram_bot.subscription.deactivated'),
            user: @user
          }
        end
      rescue StandardError => e
        Rails.logger.error "Error deactivating premium subscription for user #{@user.id}: #{e.message}"
        Bugsnag.notify(e) { |b| b.metadata = { user_id: @user.id, action: 'deactivate_premium_subscription' } }

        {
          success: false,
          message: I18n.t('telegram_bot.subscription.error', error: e.message)
        }
      end
    end

    # Возвращает текущий статус подписки пользователя
    # @return [Hash] - информация о статусе подписки
    def subscription_status
      limit_checker = Limits::LimitChecker.new(@user)

      {
        is_premium: @user.is_premium?,
        channels_count: limit_checker.current_channels_count,
        limit: ApplicationConfig.free_channels_limit,
        can_add_more: limit_checker.can_add_channel?,
        remaining_free: limit_checker.remaining_free_channels,
        limit_reached: limit_checker.limit_reached?
      }
    end

    # Проверяет нужна ли пользователю подписка
    # @return [Boolean] - true если лимит достигнут и пользователь не премиум
    def needs_subscription?
      !@user.is_premium? && Limits::LimitChecker.new(@user).limit_reached?
    end

    # Возвращает информацию о предложении подписки
    # @return [Hash] - данные для UI предложения подписки
    def subscription_offer
      limit_checker = Limits::LimitChecker.new(@user)
      current_count = limit_checker.current_channels_count
      limit = ApplicationConfig.free_channels_limit
      exceeded_by = [current_count - limit, 0].max

      {
        current_channels: current_count,
        limit: limit,
        exceeded_by: exceeded_by,
        message: I18n.t('telegram_bot.subscription.offer_message',
                       current: current_count,
                       limit: limit),
        activate_button_text: I18n.t('telegram_bot.subscription.activate_button')
      }
    end

    private

    attr_reader :user
  end
end