# frozen_string_literal: true

module Telegram::FollowerUserCommands
  extend ActiveSupport::Concern

  # Команды управления follower users

  def fadd!(phone_number = nil)
    # Проверяем права доступа
    return unless check_admin_access

    # Валидация и нормализация телефона через Phonelib
    normalized_phone = normalize_and_validate_phone(phone_number)
    return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

    # Проверка на существующего пользователя
    existing_follower = FollowerUser.find_by(phone_number: normalized_phone)
    if existing_follower
      return respond_with_error(I18n.t('telegram_bot.follower.user_exists', phone: normalized_phone))
    end

    # Создание нового пользователя
    follower_user = FollowerUser.new(phone_number: normalized_phone)
    unless follower_user.save
      return respond_with_error(I18n.t('telegram_bot.follower.creation_failed'))
    end

    # Запуск авторизации через существующий метод модели
    if follower_user.start_authorization!
      respond_with :message, text: I18n.t('telegram_bot.follower.authorization_started', phone: normalized_phone)
    else
      respond_with_error(I18n.t('telegram_bot.follower.authorization_failed', phone: normalized_phone))
    end
  end

  def fconfirm!(phone_number = nil, code = nil)
    # Проверяем права доступа
    return unless check_admin_access

    normalized_phone = normalize_and_validate_phone(phone_number)
    return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

    if code.blank?
      return respond_with_error(I18n.t('telegram_bot.follower.code_required'))
    end

    follower_user = FollowerUser.find_by(phone_number: normalized_phone)

    if follower_user.nil?
      respond_with_error(I18n.t('telegram_bot.follower.user_not_found', phone: normalized_phone))
    elsif follower_user.confirm_authorization!(code)
      respond_with :message, text: I18n.t('telegram_bot.follower.authorization_success', phone: normalized_phone)
    else
      respond_with_error(I18n.t('telegram_bot.follower.invalid_code', phone: normalized_phone))
    end
  end

  def fremove!(phone_number = nil)
    # Проверяем права доступа
    return unless check_admin_access

    normalized_phone = normalize_and_validate_phone(phone_number)
    return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

    follower_user = FollowerUser.find_by(phone_number: normalized_phone)

    if follower_user&.destroy
      respond_with :message, text: I18n.t('telegram_bot.follower.removed', phone: normalized_phone)
    else
      respond_with_error(I18n.t('telegram_bot.follower.user_not_found', phone: normalized_phone))
    end
  end

  def flist!
    # Проверяем права доступа
    return unless check_admin_access

    followers = FollowerUser.all.order(:phone_number)

    if followers.empty?
      respond_with :message, text: I18n.t('telegram_bot.follower.no_users')
    else
      message = build_followers_list_message(followers)
      respond_with :message, text: message
    end
  end

  # Вспомогательные методы

  private

  def check_admin_access
    unless current_user&.is_admin?
      Rails.logger.warn "Unauthorized access attempt to follower user command by user #{current_user&.username}"
      respond_with :message, text: I18n.t('telegram_bot.follower.access_denied')
      return false
    end
    true
  end

  def normalize_and_validate_phone(phone_number)
    return nil if phone_number.blank?

    # Использование Phonelib для валидации и нормализации
    phone = Phonelib.parse(phone_number)
    return nil unless phone.valid?

    phone.international
  rescue => e
    Rails.logger.error "Phone validation error: #{e.message}"
    nil
  end

  def build_followers_list_message(followers)
    message = I18n.t('telegram_bot.follower.list_header')
    followers.each_with_index do |follower, index|
      status_icon = get_status_icon(follower)
      status_text = I18n.t("telegram_bot.follower.status.#{follower.auth_status}")
      message += "#{index + 1}. #{status_icon} #{follower.phone_number} | #{status_text}\n"
    end
    message
  end

  def get_status_icon(follower)
    case follower.auth_status.to_sym
    when :authorized
      '✅'
    when :pending
      '⏳'
    when :failed
      '❌'
    when :banned
      '🚫'
    when :revoked
      '🔄'
    else
      '❓'
    end
  end

  def respond_with_error(message)
    respond_with :message, text: "❌ #{message}"
  end
end
