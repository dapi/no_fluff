# Модуль с командами для управления настройками пользователя
module Telegram::SettingsCommands
  extend ActiveSupport::Concern

  included do
    # Команда /settings - показать настройки пользователя
    def settings!(*)
      find_or_create_user

      respond_with :message,
        text: build_settings_text,
        reply_markup: settings_keyboard
    end

    # Callback query: показать меню настроек
    def settings_callback_query(*)
      answer_callback_query('')
      find_or_create_user

      if payload['message']
        edit_message :text,
          text: build_settings_text,
          reply_markup: settings_keyboard
      else
        respond_with :message,
          text: build_settings_text,
          reply_markup: settings_keyboard
      end
    end

    # Callback query: изменить частоту доставки
    def delivery_frequency_callback_query(*)
      answer_callback_query('')
      find_or_create_user

      if payload['message']
        edit_message :text,
          text: I18n.t('telegram_bot.settings.delivery_frequency.title'),
          reply_markup: delivery_frequency_keyboard
      else
        respond_with :message,
          text: I18n.t('telegram_bot.settings.delivery_frequency.title'),
          reply_markup: delivery_frequency_keyboard
      end
    end

    # Callback query: изменить формат контента
    def content_format_callback_query(*)
      answer_callback_query('')
      find_or_create_user

      if payload['message']
        edit_message :text,
          text: I18n.t('telegram_bot.settings.content_format.title'),
          reply_markup: content_format_keyboard
      else
        respond_with :message,
          text: I18n.t('telegram_bot.settings.content_format.title'),
          reply_markup: content_format_keyboard
      end
    end

    # Callback query: изменить строгость фильтрации
    def filter_strictness_callback_query(*)
      answer_callback_query('')
      find_or_create_user

      if payload['message']
        edit_message :text,
          text: I18n.t('telegram_bot.settings.filter_strictness.title'),
          reply_markup: filter_strictness_keyboard
      else
        respond_with :message,
          text: I18n.t('telegram_bot.settings.filter_strictness.title'),
          reply_markup: filter_strictness_keyboard
      end
    end

    # Callback query: установить частоту доставки
    def set_delivery_frequency_callback_query(frequency)
      answer_callback_query('')
      find_or_create_user

      if current_user.delivery_frequency != frequency.to_sym
        current_user.update!(delivery_frequency: frequency)

        if payload['message']
          edit_message :text,
            text: I18n.t('telegram_bot.settings.delivery_frequency.success',
                         value: I18n.t("telegram_bot.settings.delivery_frequency.options.#{frequency}")),
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: I18n.t('telegram_bot.settings.delivery_frequency.success',
                         value: I18n.t("telegram_bot.settings.delivery_frequency.options.#{frequency}")),
            reply_markup: settings_keyboard
        end
      else
        # Если значение уже установлено, просто возвращаемся к настройкам
        if payload['message']
          edit_message :text,
            text: build_settings_text,
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: build_settings_text,
            reply_markup: settings_keyboard
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error setting delivery frequency: #{e.message}"
      respond_with :message, text: I18n.t('telegram_bot.errors.general')
    end

    # Callback query: установить формат контента
    def set_content_format_callback_query(format)
      answer_callback_query('')
      find_or_create_user

      if current_user.content_format != format.to_sym
        current_user.update!(content_format: format)

        if payload['message']
          edit_message :text,
            text: I18n.t('telegram_bot.settings.content_format.success',
                         value: I18n.t("telegram_bot.settings.content_format.options.#{format}")),
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: I18n.t('telegram_bot.settings.content_format.success',
                         value: I18n.t("telegram_bot.settings.content_format.options.#{format}")),
            reply_markup: settings_keyboard
        end
      else
        # Если значение уже установлено, просто возвращаемся к настройкам
        if payload['message']
          edit_message :text,
            text: build_settings_text,
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: build_settings_text,
            reply_markup: settings_keyboard
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error setting content format: #{e.message}"
      respond_with :message, text: I18n.t('telegram_bot.errors.general')
    end

    # Callback query: установить строгость фильтрации
    def set_filter_strictness_callback_query(strictness)
      answer_callback_query('')
      find_or_create_user

      if current_user.filter_strictness != strictness.to_sym
        current_user.update!(filter_strictness: strictness)

        if payload['message']
          edit_message :text,
            text: I18n.t('telegram_bot.settings.filter_strictness.success',
                         value: I18n.t("telegram_bot.settings.filter_strictness.options.#{strictness}")),
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: I18n.t('telegram_bot.settings.filter_strictness.success',
                         value: I18n.t("telegram_bot.settings.filter_strictness.options.#{strictness}")),
            reply_markup: settings_keyboard
        end
      else
        # Если значение уже установлено, просто возвращаемся к настройкам
        if payload['message']
          edit_message :text,
            text: build_settings_text,
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: build_settings_text,
            reply_markup: settings_keyboard
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error setting filter strictness: #{e.message}"
      respond_with :message, text: I18n.t('telegram_bot.errors.general')
    end

    private

    # Построить текст с текущими настройками
    def build_settings_text
      I18n.t('telegram_bot.settings.title') + "\n\n" +
      I18n.t('telegram_bot.settings.current_settings') + "\n\n" +
      I18n.t('telegram_bot.settings.delivery_frequency.label') +
      I18n.t("telegram_bot.settings.delivery_frequency.options.#{current_user.delivery_frequency}") + "\n\n" +
      I18n.t('telegram_bot.settings.content_format.label') +
      I18n.t("telegram_bot.settings.content_format.options.#{current_user.content_format}") + "\n\n" +
      I18n.t('telegram_bot.settings.filter_strictness.label') +
      I18n.t("telegram_bot.settings.filter_strictness.options.#{current_user.filter_strictness}")
    end

    # Основная клавиатура настроек
    def settings_keyboard
      kb = [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.button'),
            callback_data: 'delivery_frequency:'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.content_format.button'),
            callback_data: 'content_format:'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.filter_strictness.button'),
            callback_data: 'filter_strictness:'
          )
        ]
      ]
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    end

    # Клавиатура для выбора частоты доставки
    def delivery_frequency_keyboard
      kb = [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.options.real_time'),
            callback_data: current_user.delivery_frequency_real_time? ? 'settings:' : 'set_delivery_frequency:real_time'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.options.three_times_daily'),
            callback_data: current_user.delivery_frequency_three_times_daily? ? 'settings:' : 'set_delivery_frequency:three_times_daily'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.options.twice_daily'),
            callback_data: current_user.delivery_frequency_twice_daily? ? 'settings:' : 'set_delivery_frequency:twice_daily'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.options.once_daily'),
            callback_data: current_user.delivery_frequency_once_daily? ? 'settings:' : 'set_delivery_frequency:once_daily'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.options.every_few_days'),
            callback_data: current_user.delivery_frequency_every_few_days? ? 'settings:' : 'set_delivery_frequency:every_few_days'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.options.weekly'),
            callback_data: current_user.delivery_frequency_weekly? ? 'settings:' : 'set_delivery_frequency:weekly'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.delivery_frequency.options.on_demand'),
            callback_data: current_user.delivery_frequency_on_demand? ? 'settings:' : 'set_delivery_frequency:on_demand'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: '← Назад',
            callback_data: 'settings:'
          )
        ]
      ]
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    end

    # Клавиатура для выбора формата контента
    def content_format_keyboard
      kb = [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.content_format.options.original'),
            callback_data: current_user.content_format_original? ? 'settings:' : 'set_content_format:original'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.content_format.options.summaries'),
            callback_data: current_user.content_format_summaries? ? 'settings:' : 'set_content_format:summaries'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.content_format.options.unified_digest'),
            callback_data: current_user.content_format_unified_digest? ? 'settings:' : 'set_content_format:unified_digest'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.content_format.options.combo'),
            callback_data: current_user.content_format_combo? ? 'settings:' : 'set_content_format:combo'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.content_format.options.headlines'),
            callback_data: current_user.content_format_headlines? ? 'settings:' : 'set_content_format:headlines'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: '← Назад',
            callback_data: 'settings:'
          )
        ]
      ]
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    end

    # Клавиатура для выбора строгости фильтрации
    def filter_strictness_keyboard
      kb = [
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.filter_strictness.options.ultra'),
            callback_data: current_user.filter_strictness_ultra? ? 'settings:' : 'set_filter_strictness:ultra'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.filter_strictness.options.high'),
            callback_data: current_user.filter_strictness_high? ? 'settings:' : 'set_filter_strictness:high'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.filter_strictness.options.medium'),
            callback_data: current_user.filter_strictness_medium? ? 'settings:' : 'set_filter_strictness:medium'
          ),
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.filter_strictness.options.low'),
            callback_data: current_user.filter_strictness_low? ? 'settings:' : 'set_filter_strictness:low'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: I18n.t('telegram_bot.settings.filter_strictness.options.smart'),
            callback_data: current_user.filter_strictness_smart? ? 'settings:' : 'set_filter_strictness:smart'
          )
        ],
        [
          Telegram::Bot::Types::InlineKeyboardButton.new(
            text: '← Назад',
            callback_data: 'settings:'
          )
        ]
      ]
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    end
  end
end