# frozen_string_literal: true

# Агент для управления пользовательскими настройками Telegram бота
# Обеспечивает отображение и изменение настроек пользователя
module Telegram
  class SettingsAgent
    include Telegram::KeyboardHelpers

    # Допустимые настройки пользователя
    VALID_SETTINGS = %w[delivery_frequency content_format filter_strictness].freeze

    # Допустимые значения для каждой настройки
    VALID_VALUES = {
      delivery_frequency: %w[real_time three_times_daily twice_daily once_daily every_few_days weekly on_demand],
      content_format: %w[original summaries unified_digest combo headlines],
      filter_strictness: %w[ultra high medium low smart]
    }.freeze

    # Инициализация агента
    # @param bot [Telegram::Bot::Client] экземпляр Telegram бота
    # @param user [TelegramUser] пользователь Telegram
    def initialize(bot, user)
      @bot = bot
      @user = user
      @logger = Rails.logger
      @cache = Rails.cache
    end

    # Показать настройки пользователя
    # Отправляет сообщение с текущими настройками и клавиатурой для их изменения
    def show_settings
      start_time = Time.current
      log_action('show_settings')

      text = build_settings_text
      keyboard = build_settings_keyboard

      @bot.send_message(
        chat_id: @user.telegram_id,
        text: text,
        reply_markup: keyboard
      )

      log_performance('show_settings', Time.current - start_time)
    rescue StandardError => e
      Bugsnag.notify(e) { |b| b.metadata = { user_id: @user.id, action: 'show_settings' } }

      # Отправляем debug уведомление если включен режим отладки
      DebugNotifier.notify_error(e, {
        service: self.class.name,
        user_id: @user.id,
        action: 'show_settings',
        timestamp: Time.current.iso8601
      }, "Error showing settings for user #{@user.id}: #{e.message}")

      log_error('show_settings', e)
      send_error(I18n.t('telegram_bot.errors.general'))
    end

    # Обновляет настройку пользователя
    # @param setting_name [String] название настройки
    # @param value [String] новое значение
    def update_setting(setting_name, value)
      start_time = Time.current
      log_action('update_setting', { setting: setting_name, value: value })

      result = validate_setting(setting_name, value)
      unless result[:success]
        log_validation_error(setting_name, value, result[:error])
        return send_error(result[:error])
      end

      @user.update!("#{setting_name}": value)

      success_message = I18n.t('telegram_bot.settings.success.updated',
                              setting: I18n.t("telegram_bot.settings.#{setting_name}.label"))
      send_success(success_message)

      log_performance('update_setting', Time.current - start_time)
    rescue ActiveRecord::RecordInvalid => e
      Bugsnag.notify(e) { |b| b.metadata = { user_id: @user.id, setting_name: setting_name, value: value, action: 'update_setting' } }
      log_validation_error(setting_name, value, e.message)
      send_error(I18n.t('telegram_bot.errors.validation'))
    rescue Telegram::Bot::Error => e
      Bugsnag.notify(e) { |b| b.metadata = { user_id: @user.id, setting_name: setting_name, value: value, action: 'update_setting' } }
      log_telegram_error('update_setting', e)
      send_error(I18n.t('telegram_bot.errors.telegram_api'))
    rescue StandardError => e
      Bugsnag.notify(e) { |b| b.metadata = { user_id: @user.id, setting_name: setting_name, value: value, action: 'update_setting' } }

      # Отправляем debug уведомление если включен режим отладки
      DebugNotifier.notify_error(e, {
        service: self.class.name,
        user_id: @user.id,
        setting_name: setting_name,
        value: value,
        action: 'update_setting',
        timestamp: Time.current.iso8601
      }, "Error updating setting #{setting_name} to #{value} for user #{@user.id}: #{e.message}")

      log_error('update_setting', e)
      send_error(I18n.t('telegram_bot.errors.general'))
    end

    private

    # Валидирует настройку и значение
    # @param setting_name [String] название настройки
    # @param value [String] значение настройки
    # @return [Hash] результат валидации { success: boolean, error: String }
    def validate_setting(setting_name, value)
      unless VALID_SETTINGS.include?(setting_name)
        return { success: false, error: I18n.t('telegram_bot.settings.errors.invalid_setting') }
      end

      unless valid_value?(setting_name, value)
        return { success: false, error: I18n.t('telegram_bot.settings.errors.invalid_value') }
      end

      { success: true }
    end

    # Проверяет что значение допустимо для настройки
    # @param setting [String] название настройки
    # @param value [String] значение для проверки
    # @return [Boolean] true если значение допустимо
    def valid_value?(setting, value)
      VALID_VALUES[setting.to_sym]&.include?(value)
    end

    # Генерирует текст с текущими настройками пользователя
    # @return [String] отформатированный текст с настройками
    def build_settings_text
      @cache.fetch("settings_text_#{@user.id}_#{@user.updated_at.to_i}", expires_in: 1.hour) do
        I18n.t('telegram_bot.settings.title') + "\n\n" +
        I18n.t('telegram_bot.settings.current_settings') + "\n\n" +
        build_setting_section('delivery_frequency') +
        build_setting_section('content_format') +
        build_setting_section('filter_strictness')
      end
    end

    # Генерирует текст для конкретной секции настроек
    # @param setting_name [String] название настройки
    # @return [String] отформатированный текст секции
    def build_setting_section(setting_name)
      current_value = @user.public_send(setting_name)
      I18n.t("telegram_bot.settings.#{setting_name}.label") +
      I18n.t("telegram_bot.settings.#{setting_name}.options.#{current_value}") + "\n\n"
    end

    # Генерирует inline клавиатуру для настроек
    # @return [Hash] хеш с inline клавиатурой
    def build_settings_keyboard
      inline_keyboard(
        keyboard_row(
          callback_button(I18n.t('telegram_bot.settings.delivery_frequency.button'), 'delivery_frequency:'),
          callback_button(I18n.t('telegram_bot.settings.content_format.button'), 'content_format:')
        ),
        keyboard_row(
          callback_button(I18n.t('telegram_bot.settings.filter_strictness.button'), 'filter_strictness:')
        )
      )
    end

    # Отправляет сообщение об ошибке
    # @param message [String] текст ошибки
    def send_error(message)
      @bot.send_message(chat_id: @user.telegram_id, text: message)
    end

    # Отправляет сообщение об успехе
    # @param message [String] текст успеха
    def send_success(message)
      @bot.send_message(chat_id: @user.telegram_id, text: message)
    end

    # Логирует действие
    # @param action [String] название действия
    # @param data [Hash] дополнительные данные
    def log_action(action, data = {})
      @logger.info "[Telegram::SettingsAgent] #{action} for user #{@user.id}: #{data.inspect}"
    end

    # Логирует ошибку
    # @param action [String] название действия
    # @param error [StandardError] исключение
    def log_error(action, error)
      @logger.error "[Telegram::SettingsAgent] Error in #{action}: #{error.message}"
      @logger.error error.backtrace.join("\n")
    end

    # Логирует ошибку валидации
    # @param setting [String] название настройки
    # @param value [String] значение
    # @param error [String] описание ошибки
    def log_validation_error(setting, value, error)
      @logger.warn "[Telegram::SettingsAgent] Validation error for #{setting}=#{value}: #{error}"
    end

    # Логирует ошибку Telegram API
    # @param action [String] название действия
    # @param error [Telegram::Bot::Error] исключение
    def log_telegram_error(action, error)
      @logger.error "[Telegram::SettingsAgent] Telegram API error in #{action}: #{error.message}"
    end

    # Логирует производительность
    # @param action [String] название действия
    # @param duration [Float] время выполнения в секундах
    def log_performance(action, duration)
      @logger.info "[Telegram::SettingsAgent] Performance: #{action} took #{(duration * 1000).round(2)}ms"
    end
  end
end
