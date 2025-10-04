# frozen_string_literal: true

# Concern для управления сессиями, доступный только администраторам
# Работает напрямую с моделью TelegramUser без использования сессий
module AdminSessionManagement
  extend ActiveSupport::Concern

  # Команда /remember - запомнить данные в сессии (только для админов)
  def remember!(*args)
    return unless require_admin!

    if args.any?
      # Сохраняем первое слово как имя пользователя в session_data
      current_user.set_session('user_name', args.first)
      respond_with :message, text: I18n.t('telegram_bot.admin_sessions.remember.success', name: args.first)
    else
      respond_with :message, text: I18n.t('telegram_bot.admin_sessions.remember.prompt')
    end
  end

  # Команда /recall - вспомнить данные из сессии (только для админов)
  def recall!(*)
    return unless require_admin!

    user_name = current_user.get_session('user_name')
    if user_name
      respond_with :message, text: I18n.t('telegram_bot.admin_sessions.recall.success', name: user_name)
    else
      respond_with :message, text: I18n.t('telegram_bot.admin_sessions.recall.empty')
    end
  end

  # Команда /forget - очистить сессию (только для админов)
  def forget!(*)
    return unless require_admin!

    current_user.clear_session!
    respond_with :message, text: I18n.t('telegram_bot.admin_sessions.forget.success')
  end

  # Команда /session_info - информация о сессии (только для админов)
  def session_info!(*)
    return unless require_admin!

    session_data = current_user.session_data
    if session_data.empty?
      respond_with :message, text: I18n.t('telegram_bot.admin_sessions.info.empty')
    else
      session_data_text = session_data.map { |k, v| "#{k}: #{v}" }.join("\n")
      respond_with :message, text: I18n.t('telegram_bot.admin_sessions.info.data', data: session_data_text)
    end
  end

  private

  # Проверяет, является ли пользователь администратором
  # Если нет - отправляет сообщение об отсутствии прав
  def require_admin!
    return true if current_user&.is_admin?

    respond_with :message, text: I18n.t('telegram_bot.admin_sessions.access_denied')
    false
  end
end