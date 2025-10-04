# Контроллер для обработки команд настроек
module Telegram::Commands
  class SettingsController < Telegram::Bot::UpdatesController
    include Telegram::Bot::UpdatesController::CallbackQueryContext
    include Telegram::KeyboardHelpers

    # Выполняем перед каждым действием
    before_action :find_or_create_user

    # Команда /settings - показать текущие настройки
    def settings!(*)
      respond_with :message,
        text: build_settings_text,
        reply_markup: settings_keyboard
    end

    # Callback query: показать меню настроек
    def settings_callback_query(*)
      answer_callback_query("")

      if payload["message"]
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
      answer_callback_query("")
      if payload["message"]
        edit_message :text,
          text: I18n.t("telegram_bot.settings.delivery_frequency.title"),
          reply_markup: delivery_frequency_keyboard
      else
        respond_with :message,
          text: I18n.t("telegram_bot.settings.delivery_frequency.title"),
          reply_markup: delivery_frequency_keyboard
      end
    end

    # Callback query: изменить формат контента
    def content_format_callback_query(*)
      answer_callback_query("")
      if payload["message"]
        edit_message :text,
          text: I18n.t("telegram_bot.settings.content_format.title"),
          reply_markup: content_format_keyboard
      else
        respond_with :message,
          text: I18n.t("telegram_bot.settings.content_format.title"),
          reply_markup: content_format_keyboard
      end
    end

    # Callback query: изменить строгость фильтрации
    def filter_strictness_callback_query(*)
      answer_callback_query("")
      if payload["message"]
        edit_message :text,
          text: I18n.t("telegram_bot.settings.filter_strictness.title"),
          reply_markup: filter_strictness_keyboard
      else
        respond_with :message,
          text: I18n.t("telegram_bot.settings.filter_strictness.title"),
          reply_markup: filter_strictness_keyboard
      end
    end

    # Callback query: установить частоту доставки
    def set_delivery_frequency_callback_query(frequency)
      answer_callback_query("")

      if current_user.delivery_frequency != frequency.to_sym
        current_user.update!(delivery_frequency: frequency)

        if payload["message"]
          edit_message :text,
            text: I18n.t("telegram_bot.settings.delivery_frequency.success",
                         value: I18n.t("telegram_bot.settings.delivery_frequency.options.#{frequency}")),
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: I18n.t("telegram_bot.settings.delivery_frequency.success",
                         value: I18n.t("telegram_bot.settings.delivery_frequency.options.#{frequency}")),
            reply_markup: settings_keyboard
        end
      else
        # Если значение уже установлено, просто возвращаемся к настройкам
        if payload["message"]
          edit_message :text,
            text: build_settings_text,
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: build_settings_text,
            reply_markup: settings_keyboard
        end
      end
    end

    # Callback query: установить формат контента
    def set_content_format_callback_query(format)
      answer_callback_query("")

      if current_user.content_format != format.to_sym
        current_user.update!(content_format: format)

        if payload["message"]
          edit_message :text,
            text: I18n.t("telegram_bot.settings.content_format.success",
                         value: I18n.t("telegram_bot.settings.content_format.options.#{format}")),
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: I18n.t("telegram_bot.settings.content_format.success",
                         value: I18n.t("telegram_bot.settings.content_format.options.#{format}")),
            reply_markup: settings_keyboard
        end
      else
        # Если значение уже установлено, просто возвращаемся к настройкам
        if payload["message"]
          edit_message :text,
            text: build_settings_text,
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: build_settings_text,
            reply_markup: settings_keyboard
        end
      end
    end

    # Callback query: установить строгость фильтрации
    def set_filter_strictness_callback_query(strictness)
      answer_callback_query("")

      if current_user.filter_strictness != strictness.to_sym
        current_user.update!(filter_strictness: strictness)

        if payload["message"]
          edit_message :text,
            text: I18n.t("telegram_bot.settings.filter_strictness.success",
                         value: I18n.t("telegram_bot.settings.filter_strictness.options.#{strictness}")),
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: I18n.t("telegram_bot.settings.filter_strictness.success",
                         value: I18n.t("telegram_bot.settings.filter_strictness.options.#{strictness}")),
            reply_markup: settings_keyboard
        end
      else
        # Если значение уже установлено, просто возвращаемся к настройкам
        if payload["message"]
          edit_message :text,
            text: build_settings_text,
            reply_markup: settings_keyboard
        else
          respond_with :message,
            text: build_settings_text,
            reply_markup: settings_keyboard
        end
      end
    end

    private

    # Находит или создаёт пользователя в БД
    def find_or_create_user
      user_data = from
      # Используем username если есть, иначе используем id в качестве username
      username = user_data["username"] || "user_#{user_data['id']}"

      @current_user ||= TelegramUser.find_or_create_by(username: username) do |user|
        user.first_name = user_data["first_name"]
        user.last_name = user_data["last_name"]
        user.language_code = user_data["language_code"] || "ru"
        user.is_premium = user_data["is_premium"] || false
      end
    end

    # Возвращает текущего пользователя
    def current_user
      @current_user
    end

    # Построить текст с текущими настройками
    def build_settings_text
      I18n.t("telegram_bot.settings.title") + "\n\n" +
      I18n.t("telegram_bot.settings.current_settings") + "\n\n" +
      I18n.t("telegram_bot.settings.delivery_frequency.label") +
      I18n.t("telegram_bot.settings.delivery_frequency.options.#{current_user.delivery_frequency}") + "\n\n" +
      I18n.t("telegram_bot.settings.content_format.label") +
      I18n.t("telegram_bot.settings.content_format.options.#{current_user.content_format}") + "\n\n" +
      I18n.t("telegram_bot.settings.filter_strictness.label") +
      I18n.t("telegram_bot.settings.filter_strictness.options.#{current_user.filter_strictness}")
    end

    # Основная клавиатура настроек
    def settings_keyboard
      inline_keyboard(
        keyboard_row(
          callback_button(I18n.t("telegram_bot.settings.delivery_frequency.button"), "delivery_frequency:"),
          callback_button(I18n.t("telegram_bot.settings.content_format.button"), "content_format:")
        ),
        keyboard_row(
          callback_button(I18n.t("telegram_bot.settings.filter_strictness.button"), "filter_strictness:")
        )
      )
    end

    # Клавиатура для выбора частоты доставки
    def delivery_frequency_keyboard
      inline_keyboard(
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.delivery_frequency.options.real_time"),
            current_user.delivery_frequency_real_time? ? "settings:" : "set_delivery_frequency:real_time"
          ),
          callback_button(
            I18n.t("telegram_bot.settings.delivery_frequency.options.three_times_daily"),
            current_user.delivery_frequency_three_times_daily? ? "settings:" : "set_delivery_frequency:three_times_daily"
          )
        ),
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.delivery_frequency.options.twice_daily"),
            current_user.delivery_frequency_twice_daily? ? "settings:" : "set_delivery_frequency:twice_daily"
          ),
          callback_button(
            I18n.t("telegram_bot.settings.delivery_frequency.options.once_daily"),
            current_user.delivery_frequency_once_daily? ? "settings:" : "set_delivery_frequency:once_daily"
          )
        ),
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.delivery_frequency.options.every_few_days"),
            current_user.delivery_frequency_every_few_days? ? "settings:" : "set_delivery_frequency:every_few_days"
          ),
          callback_button(
            I18n.t("telegram_bot.settings.delivery_frequency.options.weekly"),
            current_user.delivery_frequency_weekly? ? "settings:" : "set_delivery_frequency:weekly"
          )
        ),
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.delivery_frequency.options.on_demand"),
            current_user.delivery_frequency_on_demand? ? "settings:" : "set_delivery_frequency:on_demand"
          )
        ),
        keyboard_row(
          callback_button("← Назад", "settings:")
        )
      )
    end

    # Клавиатура для выбора формата контента
    def content_format_keyboard
      inline_keyboard(
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.content_format.options.original"),
            current_user.content_format_original? ? "settings:" : "set_content_format:original"
          ),
          callback_button(
            I18n.t("telegram_bot.settings.content_format.options.summaries"),
            current_user.content_format_summaries? ? "settings:" : "set_content_format:summaries"
          )
        ),
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.content_format.options.unified_digest"),
            current_user.content_format_unified_digest? ? "settings:" : "set_content_format:unified_digest"
          ),
          callback_button(
            I18n.t("telegram_bot.settings.content_format.options.combo"),
            current_user.content_format_combo? ? "settings:" : "set_content_format:combo"
          )
        ),
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.content_format.options.headlines"),
            current_user.content_format_headlines? ? "settings:" : "set_content_format:headlines"
          )
        ),
        keyboard_row(
          callback_button("← Назад", "settings:")
        )
      )
    end

    # Клавиатура для выбора строгости фильтрации
    def filter_strictness_keyboard
      inline_keyboard(
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.filter_strictness.options.ultra"),
            current_user.filter_strictness_ultra? ? "settings:" : "set_filter_strictness:ultra"
          ),
          callback_button(
            I18n.t("telegram_bot.settings.filter_strictness.options.high"),
            current_user.filter_strictness_high? ? "settings:" : "set_filter_strictness:high"
          )
        ),
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.filter_strictness.options.medium"),
            current_user.filter_strictness_medium? ? "settings:" : "set_filter_strictness:medium"
          ),
          callback_button(
            I18n.t("telegram_bot.settings.filter_strictness.options.low"),
            current_user.filter_strictness_low? ? "settings:" : "set_filter_strictness:low"
          )
        ),
        keyboard_row(
          callback_button(
            I18n.t("telegram_bot.settings.filter_strictness.options.smart"),
            current_user.filter_strictness_smart? ? "settings:" : "set_filter_strictness:smart"
          )
        ),
        keyboard_row(
          callback_button("← Назад", "settings:")
        )
      )
    end
  end
end
