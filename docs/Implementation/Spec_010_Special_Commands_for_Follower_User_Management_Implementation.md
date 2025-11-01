# Spec_010_Special_Commands_for_Follower_User_Management_Implementation

**Статус:** need_plan
**Дата создания:** 2025-01-02
**Автор:** NoFluff Bot Team
**Версия:** 2.0 (Переписано под существующую архитектуру)
**Основана на спецификации:** [010_Special_Commands_for_Follower_User_Management_Specification](../Specs/010_Special_Commands_for_Follower_User_Management_Specification.md)

## План имплементации (обновленный под существующую архитектуру)

### Этап 1: Подготовка (TDD - RED фаза)
- [ ] 1.1 Добавить gem 'phonelib' в Gemfile и запустить bundle install
- [ ] 1.2 Создать config/initializers/phonelib.rb для настройки валидации
- [ ] 1.3 Создать тесты для команд /fadd, /fremove, /flist, /fconfirm
- [ ] 1.4 Создать тесты для валидации и нормализации телефонов через Phonelib
- [ ] 1.5 Создать тесты для проверки прав доступа администратора

### Этап 2: Создание FollowerUserCommands concern (TDD - GREEN фаза)
- [ ] 2.1 Создать `app/controllers/concerns/telegram/follower_user_commands.rb`
- [ ] 2.2 Добавить before_action :check_admin_access для всех команд
- [ ] 2.3 Добавить команду `/fadd <phone_number>` с использованием `FollowerUser.start_authorization!`
- [ ] 2.4 Добавить команду `/fconfirm <phone_number> <code>` с использованием `FollowerUser.confirm_authorization!`
- [ ] 2.5 Добавить команду `/fremove <phone_number>` для удаления пользователя
- [ ] 2.6 Добавить команду `/flist` для отображения списка всех пользователей (без пагинации)
- [ ] 2.7 Подключить новый concern к `TelegramWebhookController`

### Этап 3: Тестирование и отладка
- [ ] 3.1 Запустить тесты и убедиться что все проходят (GREEN фаза TDD)
- [ ] 3.2 Провести интеграционное тестирование полного цикла: add → confirm → list → remove
- [ ] 3.3 Провести ручное тестирование команд в Telegram боте
- [ ] 3.4 Протестировать обработку ошибок (невалидные телефоны, пользователь не найден, неверный код)

### Этап 4: Финализация (TDD - REFACTOR фаза)
- [ ] 4.1 Проверить код через RuboCop и исправить нарушения стиля
- [ ] 4.2 Добавить сообщения в локализационные файлы (config/locales)
- [ ] 4.3 Создать инструкцию по использованию для администраторов
- [ ] 4.4 Обновить README.md с описанием новых команд

---

## Детальная реализация с использованием существующей архитектуры

### Структура файлов:

**`app/controllers/concerns/telegram/follower_user_commands.rb`**
```ruby
# frozen_string_literal: true

module Telegram::FollowerUserCommands
  extend ActiveSupport::Concern

  included do
    before_action :check_admin_access, only: [
      :fadd!, :fconfirm!, :fremove!, :flist!
    ]
  end

  private

  def check_admin_access
    unless current_user.is_admin?
      respond_with :message, text: I18n.t('telegram_bot.follower.access_denied')
      throw :abort
    end
  end

  # Команды управления follower users

  def fadd!(phone_number = nil)
    # Валидация и нормализация телефона через Phonelib
    normalized_phone = normalize_and_validate_phone(phone_number)
    return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

    # Создание или поиск пользователя
    follower_user = FollowerUser.find_or_create_by(phone_number: normalized_phone)

    # Использование существующего метода модели
    if follower_user.start_authorization!
      respond_with :message, text: I18n.t('telegram_bot.follower.authorization_started', phone: normalized_phone)
    else
      respond_with :message, text: I18n.t('telegram_bot.follower.authorization_failed', phone: normalized_phone)
    end
  end

  def fconfirm!(phone_number = nil, code = nil)
    normalized_phone = normalize_and_validate_phone(phone_number)
    return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

    follower_user = FollowerUser.find_by(phone_number: normalized_phone)

    if follower_user.nil?
      respond_with :message, text: I18n.t('telegram_bot.follower.user_not_found', phone: normalized_phone)
    elsif follower_user.confirm_authorization!(code)
      respond_with :message, text: I18n.t('telegram_bot.follower.authorization_success', phone: normalized_phone)
    else
      respond_with :message, text: I18n.t('telegram_bot.follower.invalid_code', phone: normalized_phone)
    end
  end

  def fremove!(phone_number = nil)
    normalized_phone = normalize_and_validate_phone(phone_number)
    return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

    follower_user = FollowerUser.find_by(phone_number: normalized_phone)

    if follower_user&.destroy
      respond_with :message, text: I18n.t('telegram_bot.follower.removed', phone: normalized_phone)
    else
      respond_with :message, text: I18n.t('telegram_bot.follower.user_not_found', phone: normalized_phone)
    end
  end

  def flist!
    followers = FollowerUser.all.order(:phone_number)

    if followers.empty?
      respond_with :message, text: I18n.t('telegram_bot.follower.no_users')
    else
      message = build_followers_list_message(followers)
      respond_with :message, text: message
    end
  end

  # Вспомогательные методы

  def normalize_and_validate_phone(phone_number)
    return nil if phone_number.blank?

    # Использование Phonelib для валидации и нормализации
    phone = Phonelib.parse(phone_number)
    return nil unless phone.valid?

    phone.full_international_format
  rescue => e
    Rails.logger.error "Phone validation error: #{e.message}"
    nil
  end

  def build_followers_list_message(followers)
    message = I18n.t('telegram_bot.follower.list_header')
    followers.each_with_index do |follower, index|
      status_icon = follower.authorized? ? '✅' : '⏳'
      message += "#{index + 1}. #{status_icon} #{follower.phone_number} | #{I18n.t("telegram_bot.follower.status.#{follower.auth_status}")}\n"
    end
    message
  end

  def respond_with_error(message)
    respond_with :message, text: "❌ #{message}"
  end
end
```

**Подключение в `TelegramWebhookController`:**
```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::AdminCommands
  include Telegram::FollowerUserCommands  # <- Новое подключение

  # ... существующий код ...
end
```

### Реализация команд:

#### `/fadd <phone_number>`
```ruby
def fadd!(phone_number = nil)
  # Валидация и нормализация телефона через Phonelib
  normalized_phone = normalize_and_validate_phone(phone_number)
  return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

  # Создание или поиск пользователя
  follower_user = FollowerUser.find_or_create_by(phone_number: normalized_phone)

  # Использование существующего метода модели
  if follower_user.start_authorization!
    respond_with :message, text: I18n.t('telegram_bot.follower.authorization_started', phone: normalized_phone)
  else
    respond_with :message, text: I18n.t('telegram_bot.follower.authorization_failed', phone: normalized_phone)
  end
end
```

#### `/fconfirm <phone_number> <code>`
```ruby
def fconfirm!(phone_number = nil, code = nil)
  normalized_phone = normalize_and_validate_phone(phone_number)
  return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

  follower_user = FollowerUser.find_by(phone_number: normalized_phone)

  if follower_user.nil?
    respond_with :message, text: I18n.t('telegram_bot.follower.user_not_found', phone: normalized_phone)
  elsif follower_user.confirm_authorization!(code)
    respond_with :message, text: I18n.t('telegram_bot.follower.authorization_success', phone: normalized_phone)
  else
    respond_with :message, text: I18n.t('telegram_bot.follower.invalid_code', phone: normalized_phone)
  end
end
```

#### `/fremove <phone_number>`
```ruby
def fremove!(phone_number = nil)
  normalized_phone = normalize_and_validate_phone(phone_number)
  return respond_with_error(I18n.t('telegram_bot.follower.invalid_phone')) unless normalized_phone

  follower_user = FollowerUser.find_by(phone_number: normalized_phone)

  if follower_user&.destroy
    respond_with :message, text: I18n.t('telegram_bot.follower.removed', phone: normalized_phone)
  else
    respond_with :message, text: I18n.t('telegram_bot.follower.user_not_found', phone: normalized_phone)
  end
end
```

#### `/flist`
```ruby
def flist!
  followers = FollowerUser.all.order(:phone_number)

  if followers.empty?
    respond_with :message, text: I18n.t('telegram_bot.follower.no_users')
  else
    message = build_followers_list_message(followers)
    respond_with :message, text: message
  end
end
```

### Вспомогательные методы:

```ruby
private

def normalize_and_validate_phone(phone_number)
  return nil if phone_number.blank?

  # Использование Phonelib для валидации и нормализации
  phone = Phonelib.parse(phone_number)
  return nil unless phone.valid?

  phone.full_international_format
rescue => e
  Rails.logger.error "Phone validation error: #{e.message}"
  nil
end

def build_followers_list_message(followers)
  message = I18n.t('telegram_bot.follower.list_header')
  followers.each_with_index do |follower, index|
    status_icon = follower.authorized? ? '✅' : '⏳'
    message += "#{index + 1}. #{status_icon} #{follower.phone_number} | #{I18n.t("telegram_bot.follower.status.#{follower.auth_status}")}\n"
  end
  message
end
```

---

## Детальная реализация

### Этап 1: Создание тестов (TDD - RED фаза)

#### 1.1 Создать Minitest тесты для команд управления follower users
```ruby
# test/controllers/telegram_webhook_controller_test.rb
require 'test_helper'

class TelegramWebhookControllerTest < ActionDispatch::IntegrationTest
  test 'non-admin cannot access follower commands' do
    post '/telegram_webhook', params: {
      message: {
        text: '/fadd +79123456789',
        from: { id: 123, is_bot: false },
        chat: { id: 123 }
      }
    }
    assert_response :success
    # Проверяем что ответ содержит сообщение об отказе в доступе
  end

  test 'admin can access follower commands' do
    admin_user = create(:telegram_user, is_admin: true)
    post '/telegram_webhook', params: {
      message: {
        text: '/flist',
        from: { id: admin_user.id, is_bot: false },
        chat: { id: 123 }
      }
    }
    assert_response :success
  end

  test 'fadd validates phone number format' do
    admin_user = create(:telegram_user, is_admin: true)
    post '/telegram_webhook', params: {
      message: {
        text: '/fadd invalid_phone',
        from: { id: admin_user.id, is_bot: false },
        chat: { id: 123 }
      }
    }
    assert_response :success
    # Проверяем сообщение о неверном формате телефона
  end
end
```

#### 1.2 Создать тесты для валидации телефонных номеров с Phonelib
```ruby
# test/services/phone_number_validator_test.rb
require 'test_helper'

class PhoneNumberValidatorTest < ActiveSupport::TestCase
  test 'validates Russian phone numbers with Phonelib' do
    assert Phonelib.valid?('+79123456789')
    assert Phonelib.valid_for_country?('+79123456789', 'RU')
    assert Phonelib.valid_for_country?('89123456789', 'RU')
  end

  test 'validates phone numbers with different formats' do
    assert Phonelib.valid?('+1 (555) 123-4567')
    assert Phonelib.valid?('+44 20 1234 5678')
    refute Phonelib.valid?('invalid_number')
  end

  test 'normalizes phone numbers using Phonelib' do
    phone = Phonelib.parse('89123456789', 'RU')
    assert_equal '+79123456789', phone.international
    assert_equal '89123456789', phone.national
  end
end

#### 1.3 Создать тесты для авторизации follower users
```ruby
# test/services/telegram/follower_authorization_manager_test.rb
require 'test_helper'

class Telegram::FollowerAuthorizationManagerTest < ActiveSupport::TestCase
  test 'starts authorization for valid phone number' do
    admin_user = create(:telegram_user, is_admin: true)
    manager = Telegram::FollowerAuthorizationManager.instance

    result = manager.start_authorization('+79123456789', admin_user)

    assert result[:success]
    assert result[:follower_user]
    assert result[:phone_code_hash]
  end

  test 'confirms authorization with correct code' do
    follower_user = create(:follower_user, :pending)
    manager = Telegram::FollowerAuthorizationManager.instance

    # Mock successful authorization
    Telegram::AuthorizationService.any_instance.stubs(:confirm_authorization).returns(
      { success: true, follower_user: follower_user }
    )

    result = manager.confirm_authorization(follower_user.id, '123456')

    assert result[:success]
  end
end
```

### Этап 2: Расширение AdminCommands concern

#### 2.1 Добавить команды в существующий AdminCommands concern
```ruby
# В app/controllers/concerns/telegram/admin_commands.rb добавить:

# Команда /fadd <phone_number> - добавление follower user с авторизацией
def fadd!(phone_number = nil)
  check_admin_access!

  if phone_number.blank?
    respond_with :message, text: "📱 Пожалуйста, укажите номер телефона пользователя\n\nПример: /fadd +79123456789"
    return
  end

  # Проверяем формат номера телефона
  unless valid_phone_number?(phone_number)
    respond_with :message, text: '❌ Неверный формат номера телефона. Используйте формат: +79123456789'
    return
  end

  # Начинаем процесс авторизации
  result = Telegram::FollowerAuthorizationManager.instance.start_authorization(phone_number, current_user)

  if result[:success]
    follower_user = result[:follower_user]
    respond_with :message,
      text: "📱 Начинаю авторизацию для #{phone_number}\n\n" +
            "📋 Код подтверждения: #{result[:phone_code_hash]}\n" +
            "⏰ Время на ввод: 15 минут\n\n" +
            "Используйте команду:\n/fconfirm #{follower_user.id} <код>",
      reply_markup: build_follower_authorization_keyboard(follower_user)
  else
    error_msg = result[:error] || 'Неизвестная ошибка'
    respond_with :message, text: "❌ Ошибка: #{error_msg}"
  end
rescue => e
  Bugsnag.notify(e, metadata: { command: '/fadd', user: current_user&.username, phone: phone_number })
  respond_with :message, text: '❌ Произошла ошибка при добавлении follower user'
end

# Команда /fconfirm <phone_number> <code> - подтверждение авторизации
def fconfirm!(phone_number = nil, code = nil)
  check_admin_access!

  if phone_number.blank? || code.blank?
    respond_with :message, text: "📝 Пожалуйста, укажите номер телефона и код подтверждения\n\nПример: /fconfirm +79123456789 123456"
    return
  end

  # Форматируем номер телефона
  phone_number = normalize_phone_number(phone_number)

  follower_user = FollowerUser.find_by(phone_number: phone_number)
  unless follower_user
    respond_with :message, text: "❌ Follower user с телефоном #{phone_number} не найден"
    return
  end

  result = Telegram::FollowerAuthorizationManager.instance.confirm_authorization(follower_user.id, code)

  if result[:success]
    respond_with :message,
      text: "✅ Follower user успешно авторизован!\n\n" +
            "📱 Телефон: #{follower_user.phone_number}\n" +
            "📊 Статус: #{follower_user.auth_status}\n" +
            '🏥 Готов к работе!'
  else
    error_msg = result[:error] || 'Неверный код подтверждения'
    respond_with :message, text: "❌ Ошибка авторизации: #{error_msg}\n\nПроверьте код и попробуйте снова."
  end
rescue => e
  Bugsnag.notify(e, metadata: { command: '/fconfirm', user: current_user&.username, phone: phone_number })
  respond_with :message, text: '❌ Произошла ошибка при подтверждении авторизации'
end

# Команда /flist [page] - список follower users
def flist!(page = nil)
  check_admin_access!

  page = [ page.to_i, 1 ].max if page.present?
  page ||= 1
  per_page = 10

  follower_users = FollowerUser
                     .order(:created_at)
                     .offset((page - 1) * per_page)
                     .limit(per_page)

  total_count = FollowerUser.count
  total_pages = (total_count.to_f / per_page).ceil

  if follower_users.empty?
    respond_with :message, text: '📋 В системе нет follower users'
    return
  end

  message_text = build_follower_users_list(follower_users, page, total_pages)
  reply_markup = total_pages > 1 ? build_follower_list_keyboard(page, total_pages) : nil

  respond_with :message, text: message_text, reply_markup: reply_markup
rescue => e
  Bugsnag.notify(e, metadata: { command: '/flist', user: current_user&.username })
  respond_with :message, text: '❌ Произошла ошибка при загрузке списка follower users'
end

# Команда /fremove <phone_number> - удаление follower user
def fremove!(phone_number = nil)
  check_admin_access!

  if phone_number.blank?
    respond_with :message, text: "🔍 Пожалуйста, укажите номер телефона для удаления\n\nПример: /fremove +79123456789"
    return
  end

  # Форматируем номер телефона
  phone_number = normalize_phone_number(phone_number)

  follower_user = FollowerUser.find_by(phone_number: phone_number)
  unless follower_user
    respond_with :message, text: "❌ Follower user с телефоном #{phone_number} не найден"
    return
  end

  # Отменяем авторизацию если она в процессе
  if follower_user.pending?
    Telegram::FollowerAuthorizationManager.instance.cancel_authorization(follower_user.id)
  end

  follower_user.destroy

  respond_with :message, text: "✅ Follower user удален из системы\n📱 Телефон: #{phone_number}"
rescue => e
  Bugsnag.notify(e, metadata: { command: '/fremove', user: current_user&.username, phone: phone_number })
  respond_with :message, text: '❌ Произошла ошибка при удалении follower user'
end

# Команда /fstatus <phone_number> - статус авторизации follower user
def fstatus!(phone_number = nil)
  check_admin_access!

  if phone_number.blank?
    respond_with :message, text: "🔍 Пожалуйста, укажите номер телефона\n\nПример: /fstatus +79123456789"
    return
  end

  # Форматируем номер телефона
  phone_number = normalize_phone_number(phone_number)

  follower_user = FollowerUser.find_by(phone_number: phone_number)
  unless follower_user
    respond_with :message, text: "❌ Follower user с телефоном #{phone_number} не найден"
    return
  end

  status = Telegram::FollowerAuthorizationManager.instance.authorization_status(follower_user.id)
  respond_with :message, text: build_follower_status_message(follower_user, status)
rescue => e
  Bugsnag.notify(e, metadata: { command: '/fstatus', user: current_user&.username, phone: phone_number })
  respond_with :message, text: '❌ Произошла ошибка при получении статуса'
end
```

### Этап 3: Интеграция с AuthorizationService

#### 3.1 Создать FollowerAuthorizationManager сервис
```ruby
# app/services/telegram/follower_authorization_manager.rb
module Telegram
  class FollowerAuthorizationManager
    include Singleton

    def initialize
      @pending_authorizations = {}
      @authorization_states = {}
    end

    # Start authorization process with phone number
    def start_authorization(phone_number, admin_user)
      return { success: false, error: 'Invalid phone number' } unless valid_phone_number?(phone_number)

      # Create or update follower user
      follower_user = FollowerUser.find_or_create_by(phone_number: phone_number) do |user|
        user.auth_status = :pending
      end

      # Store authorization state
      auth_key = auth_key_for(follower_user)
      @authorization_states[auth_key] = {
        follower_user: follower_user,
        admin_user: admin_user,
        stage: :phone_entered,
        created_at: Time.current,
        expires_at: Time.current + 15.minutes
      }

      # Start TDLib authorization
      result = Telegram::AuthorizationService.instance.start_authorization(follower_user)

      if result[:success]
        {
          success: true,
          follower_user: follower_user,
          phone_code_hash: result[:phone_code_hash],
          message: "Authorization started. Verification code sent to #{phone_number}"
        }
      else
        cleanup_authorization(follower_user)
        result
      end
    rescue StandardError => e
      Rails.logger.error "Failed to start authorization: #{e.message}"
      cleanup_authorization(follower_user)
      { success: false, error: e.message }
    end

    # Confirm authorization with verification code
    def confirm_authorization(follower_user_id, code)
      follower_user = FollowerUser.find_by(id: follower_user_id)
      return { success: false, error: 'Invalid follower user' } unless follower_user
      return { success: false, error: 'Invalid verification code' } if code.blank?

      auth_key = auth_key_for(follower_user)
      auth_state = @authorization_states[auth_key]
      return { success: false, error: 'Authorization not found' } unless auth_state

      # Verify code through AuthorizationService
      result = Telegram::AuthorizationService.instance.confirm_authorization(follower_user, code)

      if result[:success]
        cleanup_authorization(follower_user)
        Rails.logger.info "Successfully authorized #{follower_user.phone_number}"
        { success: true, follower_user: follower_user.reload }
      else
        Rails.logger.error "Authorization failed for #{follower_user.phone_number}: #{result[:error]}"
        result
      end
    rescue StandardError => e
      Rails.logger.error "Failed to confirm authorization: #{e.message}"
      { success: false, error: e.message }
    end

    # Cancel authorization
    def cancel_authorization(follower_user_id)
      follower_user = FollowerUser.find_by(id: follower_user_id)
      return { success: false, error: 'Invalid follower user' } unless follower_user

      auth_key = auth_key_for(follower_user)
      auth_state = @authorization_states[auth_key]

      # Cleanup TDLib authorization
      Telegram::AuthorizationService.instance.cleanup_authorization(follower_user)

      # Update follower user status
      if follower_user.pending?
        follower_user.update!(auth_status: :failed)
      end

      cleanup_authorization(follower_user)
      { success: true }
    rescue StandardError => e
      Rails.logger.error "Failed to cancel authorization: #{e.message}"
      { success: false, error: e.message }
    end

    # Get authorization status
    def authorization_status(follower_user_id)
      follower_user = FollowerUser.find_by(id: follower_user_id)
      return nil unless follower_user

      auth_key = auth_key_for(follower_user)
      auth_state = @authorization_states[auth_key]

      if auth_state
        tdlib_status = Telegram::AuthorizationService.instance.authorization_status(follower_user)

        {
          stage: auth_state[:stage],
          created_at: auth_state[:created_at],
          expires_at: auth_state[:expires_at],
          tdlib_status: tdlib_status,
          time_remaining: [ auth_state[:expires_at] - Time.current, 0 ].max
        }
      else
        {
          stage: follower_user.auth_status,
          status: follower_user.auth_status,
          authorized: follower_user.authorized?
        }
      end
    end

    private

    def valid_phone_number?(phone_number)
      phone_number.to_s.match?(/^\+?\d{10,15}$/)
    end

    def auth_key_for(follower_user)
      "auth_#{follower_user.id}"
    end

    def cleanup_authorization(follower_user)
      auth_key = auth_key_for(follower_user)
      @authorization_states.delete(auth_key)
      Telegram::AuthorizationService.instance.cleanup_authorization(follower_user)
    end
  end
end
```

### Этап 4: Создание callback handlers

#### 4.1 Добавить callback handlers в AdminCommands concern
```ruby
# Callback query для статуса follower user
def fstatus_callback_query(phone_number = nil)
  check_admin_access!

  if phone_number.blank?
    answer_callback_query('❌ Номер телефона не указан')
    return
  end

  answer_callback_query('')
  fstatus!(phone_number)
rescue => e
  Bugsnag.notify(e, metadata: { command: 'fstatus_callback', user: current_user&.username, phone: phone_number })
  answer_callback_query('❌ Произошла ошибка при получении статуса')
end

# Callback query для отмены авторизации
def fcancel_callback_query(phone_number = nil)
  check_admin_access!

  if phone_number.blank?
    answer_callback_query('❌ Номер телефона не указан')
    return
  end

  phone_number = normalize_phone_number(phone_number)
  follower_user = FollowerUser.find_by(phone_number: phone_number)
  unless follower_user
    answer_callback_query('❌ Follower user не найден')
    return
  end

  result = Telegram::FollowerAuthorizationManager.instance.cancel_authorization(follower_user.id)

  if result[:success]
    answer_callback_query('✅ Авторизация отменена')
  else
    answer_callback_query('❌ Ошибка при отмене авторизации')
  end
rescue => e
  Bugsnag.notify(e, metadata: { command: 'fcancel_callback', user: current_user&.username, phone: phone_number })
  answer_callback_query('❌ Произошла ошибка при отмене авторизации')
end

# Callback query для обновления списка follower users
def frefresh_callback_query(*)
  check_admin_access!
  answer_callback_query('🔄 Обновляю список...')
  flist!(1)
rescue => e
  Bugsnag.notify(e, metadata: { command: 'frefresh_callback', user: current_user&.username })
  answer_callback_query('❌ Произошла ошибка при обновлении списка')
end

# Callback query для пагинации списка follower users
def follower_list_page_callback_query(page = nil)
  check_admin_access!
  answer_callback_query('')
  flist!(page.to_i)
rescue => e
  Bugsnag.notify(e, metadata: { command: 'follower_list_page', user: current_user&.username })
  answer_callback_query('❌ Произошла ошибка при загрузке страницы')
end
```

#### 4.2 Helper методы для форматирования и клавиатур
```ruby
private

# Нормализация номера телефона с использованием Phonelib
def normalize_phone_number(phone_number)
  phone = Phonelib.parse(phone_number.to_s, 'RU') # Россия по умолчанию

  # Если парсинг не удался, возвращаем оригинал
  phone&.international || phone_number.to_s
end

# Валидация номера телефона с использованием Phonelib
def valid_phone_number?(phone_number)
  Phonelib.valid?(phone_number.to_s)
end

# Формирование списка follower users
def build_follower_users_list(follower_users, current_page, total_pages)
  header = "📋 Follower users в системе (#{current_page}/#{total_pages}):\n\n"

  users_list = follower_users.map.with_index(1) do |follower, index|
    global_index = (current_page - 1) * 10 + index
    status_icon = get_follower_status_icon(follower)
    "#{global_index}. #{status_icon} 📱 #{follower.phone_number} | 📊 #{follower.channels_count} каналов"
  end.join("\n")

  footer = total_pages > 1 ? "\n\n[Страница #{current_page} из #{total_pages}]" : ''
  header + users_list + footer
end

# Формирование статуса follower user
def build_follower_status_message(follower_user, status)
  status_icon = get_follower_status_icon(follower_user)

  message = "#{status_icon} Статус Follower User\n\n"
  message += "📱 Телефон: #{follower_user.phone_number}\n"
  message += "🆔 ID: #{follower_user.id}\n"
  message += "📊 Статус: #{follower_user.auth_status}\n"
  message += "🏥 Каналов: #{follower_user.channels_count}/#{follower_user.max_channels}\n"
  message += "💪 Health: #{follower_user.health_score.round(1)}%\n"
  message += "⏰ Авторизован: #{follower_user.last_authorized_at ? time_ago_in_words(follower_user.last_authorized_at) : 'Никогда'}"

  if status && status[:stage] == :phone_entered
    message += "\n\n🔄 Процесс авторизации активен"
    message += "\n⏰ Осталось времени: #{format_time_remaining(status[:time_remaining])}"
  end

  message
end

# Получение иконки статуса
def get_follower_status_icon(follower_user)
  case follower_user.auth_status.to_sym
  when :authorized then '✅'
  when :pending then '⏳'
  when :failed then '❌'
  when :banned then '🚫'
  when :revoked then '🚫'
  else '❓'
  end
end

# Форматирование оставшегося времени
def format_time_remaining(seconds)
  return '0 минут' if seconds <= 0
  minutes = (seconds / 60).floor
  hours = (minutes / 60).floor
  minutes = minutes % 60
  hours > 0 ? "#{hours}ч #{minutes}мин" : "#{minutes}мин"
end

# Создание клавиатуры для процесса авторизации
def build_follower_authorization_keyboard(follower_user)
  buttons = [
    [
      callback_button('📊 Статус', "fstatus:#{follower_user.phone_number}"),
      callback_button('❌ Отмена', "fcancel:#{follower_user.phone_number}")
    ]
  ]
  inline_keyboard(*buttons)
end

# Создание клавиатуры для списка follower users
def build_follower_list_keyboard(current_page, total_pages)
  buttons = []
  nav_buttons = []

  # Кнопка "Предыдущая"
  if current_page > 1
    nav_buttons << callback_button('◀️ Предыдущая', "follower_list_page:#{current_page - 1}")
  end

  # Кнопка "Следующая"
  if current_page < total_pages
    nav_buttons << callback_button('Следующая ➡️', "follower_list_page:#{current_page + 1}")
  end

  buttons << nav_buttons if nav_buttons.any?
  buttons << [ callback_button('🔄 Обновить', 'frefresh:') ]

  inline_keyboard(*buttons)
end
```

### Этап 5: Обновление структуры файлов

#### 5.1 Финальная структура необходимых файлов
```
# НОВЫЕ файлы:
app/services/telegram/follower_authorization_manager.rb
test/services/phone_number_validator_test.rb (тесты Phonelib)
test/services/telegram/follower_authorization_manager_test.rb (тесты сервиса)

# ИЗМЕНЕНИЯ в существующих файлах:
Gemfile (добавить gem 'phonelib')
config/initializers/phonelib.rb (конфигурация Phonelib)
app/controllers/concerns/telegram/admin_commands.rb (добавить команды и callbacks)
test/controllers/telegram_webhook_controller_test.rb (добавить тесты)

# ИСПОЛЬЗУЕМЫЕ существующие файлы:
app/models/follower_user.rb (уже существует)
app/services/telegram/authorization_service.rb (уже существует)
```

### Этап 6: Финализация

#### 6.1 TDD подход соблюден:
1. **RED фаза:** Созданы тесты перед реализацией
2. **GREEN фаза:** Реализация под существующие тесты
3. **REFACTOR фаза:** Оптимизация и улучшение кода

#### 6.2 Code review checklist:
- [ ] Все тесты проходят (RED → GREEN → REFACTOR)
- [ ] Использована существующая архитектура FollowerUser
- [ ] Интеграция с AuthorizationService
- [ ] Права доступа работают корректно через AdminCommands
- [ ] Bugsnag интеграция для отладки
- [ ] Код соответствует стилю проекта (.rubocop.yml)
- [ ] Используются Minitest тесты
- [ ] Нет конфликтов с TDLib-ruby архитектурой

#### 6.3 Интеграция с существующей архитектурой:
- [ ] Используется существующая модель FollowerUser с phone_number
- [ ] Команды добавлены в AdminCommands concern
- [ ] Интеграция с существующим AuthorizationService для TDLib
- [ ] Соответствует C4 модели системы

---

## Риски и митигация

### ✅ **Устраненные риски:**
- **Конфликт с существующей архитектурой** - план переписан под существующую систему
- **Несоответствие спецификации** - исправлено на работу с phone_number
- **Нарушение TDD подхода** - исправлено, тесты первыми (Minitest)
- **Дублирование кода** - используются существующие паттерны

### 🔄 **Остальные риски:**
1. **Безопасность** - несанкционированный доступ к командам
   - **Митигация:** Проверка прав доступа и логирование в Bugsnag

2. **Производительность** - запросы при загрузке списка follower users
   - **Митигация:** Пагинация и оптимизированные запросы

3. **UX авторизации** - сложность интерактивного процесса
   - **Митигация:** Ясные сообщения, клавиатуры, таймауты

---

**Дата начала имплементации:** TBD
**Предполагаемая длительность:** 3-4 дня
**Ответственный разработчик:** TBD