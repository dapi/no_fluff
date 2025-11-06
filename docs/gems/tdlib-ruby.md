# TDLib-ruby Gem

## ⚠️ ВАЖНО: ИСПОЛЬЗОВАНИЕ ПРЕКРАЩЕНО

**Статус:** ❌ **ЗАМЕНЕН** на telegram-mtproto-ruby (Ноябрь 2025)
**Причина:** Конфликты зависимостей с Rails 8 (FFI, concurrent-ruby)
**Решение:** Полная миграция на telegram-mtproto-ruby

---

### ⚠️ Этот документ архивирован

Данная документация оставлена для исторических целей. **TDLib-ruby больше не используется в проекте NoFluff.**

**Актуальная реализация:** Смотрите [telegram-mtproto-ruby](./telegram-bot.md#mtproto-реализация) и [MTProto Implementation](../Architecture/mtproto-ruby-implementation.md)

---

## Исторический обзор

**TDLib-ruby** - это Ruby библиотека для работы с [TDLib](https://github.com/tdlib/td) (Telegram Database Library), официальной библиотеки от Telegram для создания клиентов. Позволяет использовать полный User API Telegram, включая возможности, недоступные через Bot API.

**❌ Почему был заменен:**
- Конфликты зависимостей с Rails 8
- FFI 1.15.0 vs 1.17.2
- concurrent-ruby ~> 1.1 vs 1.3.5
- Невозможность использования в production

**✅ Что используется вместо:**
- telegram-mtproto-ruby (pure Ruby)
- Полная совместимость с Rails 8
- Production-ready решение

## Основные возможности

### ✅ Доступные возможности через User API:
- 📱 **Получение контента из любых каналов** - включая приватные
- 🔓 **Автоматическое вступление в каналы** - без ограничений Bot API
- 👥 **Работа с группами и чатами** - полный доступ
- 💬 **Отправка сообщений от имени пользователя** - все типы контента
- 🔍 **Поиск пользователей и каналов** - глобальный поиск
- 📊 **Статистика и аналитика** - детальная информация о каналах
- 🎭 **Управление профилем** - смена имени, описания, фото
- 🔐 **Безопасность** - 2FA, сессии, управление устройствами

### 🚫 Ограничения по сравнению с Bot API:
- ⚠️ **Нужно получать API credentials** - регистрация на my.telegram.org
- ⚠️ **Требуется управление сессиями** - авторизация по номеру телефона
- ⚠️ **Rate limiting** - такие же ограничения как у обычных пользователей
- ⚠️ **Ответственность** - нужно следовать правилам Telegram

## Установка

### 1. Требования к системе

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    gperf \
    php-dev  # для некоторых зависимостей

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install -y \
    cmake3 \
    git \
    openssl-devel \
    readline-devel \
    zlib-devel \
    gperf
```

### 2. Компиляция TDLib

```bash
# Клонируем репозиторий
git clone https://github.com/tdlib/td.git
cd td

# Выбираем стабильную версию
git checkout v1.8.0

# Компилируем
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local ..
cmake --build .

# Устанавливаем систему
sudo cmake --build . --target install
```

### 3. Добавление в проект

```ruby
# Gemfile
gem 'tdlib-ruby', '~> 3.0'

# Для конкретной версии TDLib
gem 'tdlib-schema', '~> 1.8.0'
```

```bash
bundle install
```

## Конфигурация

### Базовая конфигурация

```ruby
# config/initializers/tdlib.rb
require 'tdlib-ruby'

# Конфигурация TDLib клиента
TD.configure do |config|
  # API credentials (получить на https://my.telegram.org/apps)
  config.client.api_id = Rails.application.credentials.tdlib[:api_id]
  config.client.api_hash = Rails.application.credentials.tdlib[:api_hash]

  # Настройки клиента
  config.client.database_directory = Rails.root.join('tmp', 'tdlib', 'db')
  config.client.files_directory = Rails.root.join('tmp', 'tdlib', 'files')
  config.client.use_test_dc = Rails.env.development?

  # Информация о приложении
  config.client.device_model = 'NoFluff Bot'
  config.client.system_version = '1.0'
  config.client.application_version = NoFluff::VERSION

  # Настройки производительности
  config.client.use_file_database = true
  config.client.use_chat_info_database = true
  config.client.use_message_database = true
  config.client.enable_storage_optimizer = true
end

# Уровень логирования
TD::Api.set_log_verbosity_level(Rails.env.development? ? 2 : 1)

# Лог файл для production
if Rails.env.production?
  TD::Api.set_log_file_path(Rails.root.join('log', 'tdlib.log'))
end
```

### Хранение API ключей

```bash
# Создание credentials
rails credentials:edit

# Добавить в credentials.yml.enc
tdlib:
  api_id: 12345678
  api_hash: "abcdef1234567890abcdef1234567890"
  phone_number: "+79991234567"
  # Эти поля только для development
  verification_code: "12345"
  password: "my_2fa_password"
```

## Использование

### 1. Клиент менеджер

```ruby
# app/services/tdlib/client_manager.rb
class TDLib::ClientManager
  include Singleton

  def initialize
    @client = nil
    @authorized = false
    @phone_number = Rails.application.credentials.tdlib[:phone_number]
  end

  def connect
    return @client if @client&.connected?

    @client = TD::Client.new

    # Настройка обработчиков
    setup_authorization_handler
    setup_message_handlers

    @client.connect
    wait_for_authorization

    @client
  end

  def disconnect
    @client&.dispose
    @client = nil
    @authorized = false
  end

  def client
    connect unless @client&.connected?
    @client
  end

  def authorized?
    @authorized
  end

  private

  def setup_authorization_handler
    client.on(TD::Types::Update::AuthorizationState) do |update|
      case update.authorization_state
      when TD::Types::AuthorizationState::WaitPhoneNumber
        client.set_authentication_phone_number(phone_number: @phone_number).wait
      when TD::Types::AuthorizationState::WaitCode
        code = Rails.application.credentials.tdlib[:verification_code]
        client.check_authentication_code(code: code).wait
      when TD::Types::AuthorizationState::WaitPassword
        password = Rails.application.credentials.tdlib[:password]
        client.check_authentication_password(password: password).wait
      when TD::Types::AuthorizationState::Ready
        @authorized = true
        Rails.logger.info "TDLib client authorized"
      end
    end
  end

  def setup_message_handlers
    client.on(TD::Types::Update::NewMessage) do |update|
      handle_new_message(update.message)
    end
  end

  def wait_for_authorization
    timeout = 30
    start_time = Time.now

    while !@authorized && (Time.now - start_time) < timeout
      sleep 0.1
    end

    raise "TDLib authorization timeout" unless @authorized
  end

  def handle_new_message(message)
    # Обработка новых сообщений
    Rails.logger.info "New message: #{message.content.text&.text}"
  end
end
```

### 2. Работа с каналами

```ruby
# app/services/tdlib/channel_service.rb
class TDLib::ChannelService
  def initialize(client_manager: TDLib::ClientManager.instance)
    @client_manager = client_manager
  end

  # Поиск канала
  def find_channel(username)
    result = client.search_public_chat(username: username).wait

    if result.ok?
      chat = result.value
      {
        id: chat.id,
        title: chat.title,
        username: chat.username,
        type: chat.type.class.name.split('::').last,
        member_count: chat.member_count
      }
    else
      { error: result.error.message }
    end
  end

  # Вступление в канал
  def join_channel(chat_id)
    result = client.join_chat(chat_id: chat_id).wait

    if result.ok?
      { success: true, message: "Joined channel successfully" }
    else
      { success: false, error: result.error.message }
    end
  end

  # Вступление по инвайт-ссылке
  def join_by_invite_link(invite_link)
    result = client.join_chat_by_invite_link(invite_link: invite_link).wait

    if result.ok?
      { success: true, chat_id: result.value.chat.id }
    else
      { success: false, error: result.error.message }
    end
  end

  # Получение истории сообщений
  def get_chat_history(chat_id, limit: 100)
    result = client.get_chat_history(
      chat_id: chat_id,
      limit: limit,
      offset: 0,
      only_local: false
    ).wait

    if result.ok?
      messages = result.value.map do |message|
        {
          id: message.id,
          text: message.content.text&.text,
          date: Time.at(message.date),
          views: message.interaction_info&.view_count,
          forwards: message.interaction_info&.forward_count
        }
      end

      { success: true, messages: messages }
    else
      { success: false, error: result.error.message }
    end
  end

  # Получение информации о канале
  def get_chat_info(chat_id)
    result = client.get_chat(chat_id: chat_id).wait

    if result.ok?
      chat = result.value
      {
        id: chat.id,
        title: chat.title,
        username: chat.username,
        description: chat.description,
        member_count: chat.member_count,
        is_verified: chat.is_verified,
        type: chat.type.class.name.split('::').last
      }
    else
      { success: false, error: result.error.message }
    end
  end

  private

  def client
    @client_manager.client
  end
end
```

### 3. Пример использования в контроллере

```ruby
# app/controllers/telegram/tdlib_controller.rb
class Telegram::TdlibController < Telegram::BaseController
  def join_channel
    channel_identifier = params[:channel_identifier] # @username или invite_link

    begin
      service = TDLib::ChannelService.new

      if channel_identifier.start_with?('https://t.me/')
        result = service.join_by_invite_link(channel_identifier)
      else
        # Сначала ищем канал
        channel_info = service.find_channel(channel_identifier.gsub('@', ''))
        return respond_with_error("Channel not found") if channel_info[:error]

        result = service.join_channel(channel_info[:id])
      end

      if result[:success]
        respond_with_message("✅ Successfully joined channel!")
      else
        respond_with_error("❌ Failed to join: #{result[:error]}")
      end

    rescue => e
      Rails.logger.error "TDLib join channel error: #{e.message}"
      respond_with_error("❌ System error. Please try again later.")
    end
  end

  def channel_info
    channel_identifier = params[:channel_identifier]

    begin
      service = TDLib::ChannelService.new

      if channel_identifier.start_with?('@')
        channel_info = service.find_channel(channel_identifier.gsub('@', ''))
      else
        # Ищем по инвайт-ссылке или ID
        channel_info = service.get_chat_info(channel_identifier.to_i)
      end

      if channel_info[:error]
        respond_with_error("Channel not found: #{channel_info[:error]}")
      else
        info_text = format_channel_info(channel_info)
        respond_with_message(info_text)
      end

    rescue => e
      Rails.logger.error "TDLib channel info error: #{e.message}"
      respond_with_error("❌ Failed to get channel info")
    end
  end

  private

  def format_channel_info(info)
    <<~TEXT
      📊 **Channel Information**

      **Title:** #{info[:title]}
      **Username:** @#{info[:username]} if info[:username]
      **Type:** #{info[:type]}
      **Members:** #{info[:member_count]&.to_s&.reverse&.gsub(/(\d{3})(?=\d)/, '\\1,')&.reverse || 'Unknown'}
      **Verified:** #{info[:is_verified] ? '✅' : '❌'}

      **Description:** #{info[:description] || 'No description'}
    TEXT
  end

  def respond_with_message(message)
    respond_to do |format|
      format.json { render json: { message: message } }
      format.html { render plain: message }
    end
  end

  def respond_with_error(error_message)
    respond_to do |format|
      format.json { render json: { error: error_message }, status: :unprocessable_entity }
      format.html { render plain: error_message, status: :unprocessable_entity }
    end
  end
end
```

## Background Jobs

### Channel Monitor Job

```ruby
# app/jobs/tdlib/channel_monitor_job.rb
class TDLib::ChannelMonitorJob < ApplicationJob
  queue_as :tdlib

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(channel_identifier)
    service = TDLib::ChannelService.new

    # Поиск или вступление в канал
    if channel_identifier.start_with?('https://t.me/')
      result = service.join_by_invite_link(channel_identifier)
    else
      channel_info = service.find_channel(channel_identifier.gsub('@', ''))
      return if channel_info[:error]

      result = service.join_channel(channel_info[:id])
    end

    if result[:success]
      # Получаем последнюю активность
      chat_id = result[:chat_id] || channel_info[:id]
      latest_posts = service.get_chat_history(chat_id, limit: 10)

      if latest_posts[:success]
        process_posts(latest_posts[:messages], channel_identifier)
      end

      Rails.logger.info "Successfully monitored channel: #{channel_identifier}"
    else
      Rails.logger.error "Failed to monitor channel #{channel_identifier}: #{result[:error]}"
    end
  end

  private

  def process_posts(messages, channel_identifier)
    messages.each do |message|
      # Сохраняем посты в базу
      Post.find_or_create_by(
        telegram_message_id: message[:id],
        channel_identifier: channel_identifier
      ) do |post|
        post.update!(
          text: message[:text],
          published_at: message[:date],
          views_count: message[:views],
          forwards_count: message[:forwards]
        )
      end

      # Запускаем AI-классификацию
      Content::ClassifyJob.perform_later(message[:id])
    end
  end
end
```

## Тестирование

### RSpec тесты

```ruby
# spec/services/tdlib/channel_service_spec.rb
RSpec.describe TDLib::ChannelService do
  let(:client_manager) { instance_double(TDLib::ClientManager) }
  let(:client) { instance_double(TD::Client) }
  let(:service) { described_class.new(client_manager: client_manager) }

  before do
    allow(client_manager).to receive(:client).and_return(client)
  end

  describe '#find_channel' do
    it 'finds channel by username' do
      mock_chat = instance_double(TD::Types::Chat,
        id: 12345,
        title: 'Test Channel',
        username: 'testchannel',
        member_count: 1000
      )

      mock_result = double(ok?: true, value: mock_chat)
      allow(client).to receive(:search_public_chat)
        .with(username: 'testchannel')
        .and_return(mock_result)

      result = service.find_channel('testchannel')

      expect(result).to include(
        id: 12345,
        title: 'Test Channel',
        username: 'testchannel',
        member_count: 1000
      )
    end

    it 'handles channel not found' do
      mock_result = double(ok?: false, error: double(message: 'Not found'))
      allow(client).to receive(:search_public_chat)
        .and_return(mock_result)

      result = service.find_channel('nonexistent')

      expect(result).to include(error: 'Not found')
    end
  end

  describe '#join_channel' do
    it 'joins channel successfully' do
      mock_result = double(ok?: true)
      allow(client).to receive(:join_chat)
        .with(chat_id: 12345)
        .and_return(mock_result)

      result = service.join_channel(12345)

      expect(result).to include(success: true)
    end
  end
end
```

### Factory для тестов

```ruby
# spec/factories/tdlib.rb
FactoryBot.define do
  factory :tdlib_chat, class: TD::Types::Chat do
    initialize_with do
      TD::Types::Chat.new(
        id: 12345,
        title: 'Test Channel',
        username: 'testchannel',
        type: TD::Types::ChatType::Channel.new,
        member_count: 1000,
        is_verified: false
      )
    end
  end

  factory :tdlib_message, class: TD::Types::Message do
    initialize_with do
      TD::Types::Message.new(
        id: 67890,
        chat_id: 12345,
        content: TD::Types::MessageText.new(
          text: TD::Types::FormattedText.new(
            text: 'Test message',
            entities: []
          )
        ),
        date: Time.current.to_i
      )
    end
  end
end
```

## Мониторинг и отладка

### Проверка соединения

```ruby
# app/services/tdlib/health_check.rb
class TDLib::HealthCheck
  def self.status
    client_manager = TDLib::ClientManager.instance

    {
      client_connected: client_manager.client&.connected?,
      authorized: client_manager.authorized?,
      last_check: Time.current
    }
  end

  def self.test_channel_search
    service = TDLib::ChannelService.new
    result = service.find_channel('telegram')

    {
      success: !result[:error],
      result: result,
      timestamp: Time.current
    }
  end
end
```

### Логирование

```ruby
# app/services/tdlib/logging_service.rb
class TDLib::LoggingService
  def self.log_operation(operation, params, result)
    log_entry = {
      operation: operation,
      params: params,
      result: result,
      timestamp: Time.current
    }

    Rails.logger.info "[TDLib] #{log_entry.to_json}"
  end

  def self.log_error(operation, error, params = {})
    error_entry = {
      operation: operation,
      error: error.message,
      backtrace: error.backtrace.first(5),
      params: params,
      timestamp: Time.current
    }

    Rails.logger.error "[TDLib Error] #{error_entry.to_json}"
  end
end
```

## Советы и лучшие практики

### 1. Управление сессиями

```ruby
# Сохранение и восстановление сессий
class TDLib::SessionManager
  def self.save_session
    client = TDLib::ClientManager.instance.client
    session_data = client.export_session if client.respond_to?(:export_session)

    # Шифрование и сохранение
    encrypted_data = Rails.application.message_verifier.encrypt(session_data)
    Rails.cache.write('tdlib_session', encrypted_data, expires_in: 7.days)
  end

  def self.restore_session
    encrypted_data = Rails.cache.read('tdlib_session')
    return false unless encrypted_data

    session_data = Rails.application.message_verifier.verify(encrypted_data)
    client = TDLib::ClientManager.instance.client
    client.import_session(session_data) if client.respond_to?(:import_session)
  end
end
```

### 2. Rate Limiting

```ruby
# app/services/tdlib/rate_limiter.rb
class TDLib::RateLimiter
  def self.check_limit(operation)
    key = "tdlib_rate_limit_#{operation}"
    count = Rails.cache.increment(key, 1, expires_in: 1.minute)

    if count > 10 # 10 операций в минуту
      raise TDLib::RateLimitExceeded, "Too many #{operation} operations"
    end

    true
  end
end
```

### 3. Обработка ошибок

```ruby
# app/services/tdlib/error_handler.rb
class TDLib::ErrorHandler
  ERROR_MAPPING = {
    429 => :rate_limit,
    401 => :unauthorized,
    403 => :forbidden,
    404 => :not_found,
    500 => :server_error
  }.freeze

  def self.handle_error(error)
    error_code = extract_error_code(error)
    error_type = ERROR_MAPPING[error_code] || :unknown

    case error_type
    when :rate_limit
      sleep(5) # Ждем 5 секунд
      :retry
    when :unauthorized
      TDLib::ClientManager.instance.reauthorize
      :retry
    when :forbidden, :not_found
      :fail
    else
      :retry
    end
  end

  private

  def self.extract_error_code(error)
    return 500 unless error.respond_to?(:code)

    error.code
  end
end
```

## Альтернативы

| Библиотека | Преимущества | Недостатки | Когда использовать |
|-----------|-------------|-----------|------------------|
| **tdlib-ruby** | ✅ Официальная поддержка<br>✅ Полный User API<br>✅ Стабильность | ⚠️ Требует компиляции TDLib<br>⚠️ Больше настроек | **Production приложения** |
| telegram-mtproto-ruby | ✅ Чистый MTProto<br>✅ Легковесная | ⚠️ Низкоуровневая<br>⚠️ Меньше документации | Эксперименты, кастомные решения |
| mtproto gem | ✅ Простая | ❌ Устаревшая<br>❌ Ограниченная функциональность | Простые задачи, прототипы |

## Заключение

**TDLib-ruby** является лучшим выбором для production Ruby приложений, которым нужен полный доступ к User API Telegram. Несмотря на более сложную установку, она предоставляет:

- 🛡️ **Надежность** - официальная поддержка от Telegram
- 🚀 **Производительность** - оптимизированная библиотека
- 🔧 **Полный функционал** - все возможности Telegram API
- 📚 **Документация** - хорошая поддержка и примеры

Для проекта "Без шелухи" TDLib-ruby позволяет преодолеть ограничения Bot API и предоставить пользователям доступ к более широкому спектру Telegram каналов, включая приватные.