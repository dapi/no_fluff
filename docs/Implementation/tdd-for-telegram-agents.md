# TDD для Telegram агентов: пошаговая инструкция

## Введение

Этот документ описывает подход к разработке Telegram агентов с использованием Test-Driven Development (TDD) - методологии, при которой сначала пишутся тесты, а затем реализация кода для их прохождения.

## Преимущества TDD для Telegram агентов

- **Надежность**: Код гарантированно работает как ожидается
- **Безопасность рефакторинга**: Можно изменять код без боязни сломать функциональность
- **Четкая архитектура**: Тесты强迫 определять четкие интерфейсы
- **Быстрая отладка**: Проблемы выявляются на раннем этапе
- **Документация**: Тесты служат живой документацией к коду

## Пошаговая инструкция

### Шаг 1: Определи требования к агенту

Прежде чем писать код, создай четкую спецификацию того, что должен делать агент:

```ruby
# Пример: Агент для обработки команд настроек
# Должен:
# - Показывать текущие настройки пользователя
# - Обрабатывать изменения настроек с валидацией
# - Отправлять форматированные сообщения с клавиатурами
# - Обрабатывать ошибки и показывать понятные сообщения
# - Работать с локализацией через I18n
```

### Шаг 2: Создай тестовый файл (RED фаза)

Сначала создаем тесты, которые описывают ожидаемое поведение:

```ruby
# spec/services/telegram/settings_agent_spec.rb
RSpec.describe Telegram::SettingsAgent do
  let(:bot) { double('Telegram::Bot::Client') }
  let(:user) { create(:telegram_user) }
  let(:agent) { described_class.new(bot, user) }

  describe '#show_settings' do
    it 'sends message with current settings' do
      expect(bot).to receive(:send_message).with(
        chat_id: user.telegram_id,
        text: include('Частота доставки:'),
        reply_markup: instance_of(Telegram::Bot::Types::InlineKeyboardMarkup)
      )

      agent.show_settings
    end

    it 'includes all setting sections in message' do
      expect(bot).to receive(:send_message).with(
        chat_id: user.telegram_id,
        text: include('delivery_frequency', 'content_format', 'filter_strictness'),
        reply_markup: anything
      )

      agent.show_settings
    end
  end

  describe '#update_setting' do
    context 'with valid frequency' do
      it 'updates user delivery frequency' do
        expect {
          agent.update_setting('delivery_frequency', 'real_time')
        }.to change { user.reload.delivery_frequency }.to('real_time')
      end

      it 'sends success message' do
        expect(bot).to receive(:send_message).with(
          chat_id: user.telegram_id,
          text: include('обновлена')
        )

        agent.update_setting('delivery_frequency', 'real_time')
      end
    end

    context 'with invalid setting name' do
      it 'sends error message' do
        expect(bot).to receive(:send_message).with(
          chat_id: user.telegram_id,
          text: include('Некорректная настройка')
        )

        agent.update_setting('invalid_setting', 'value')
      end
    end

    context 'with invalid setting value' do
      it 'sends error message' do
        expect(bot).to receive(:send_message).with(
          chat_id: user.telegram_id,
          text: include('Некорректное значение')
        )

        agent.update_setting('delivery_frequency', 'invalid')
      end
    end
  end

  describe '#build_keyboard' do
    it 'creates inline keyboard with all settings buttons' do
      keyboard = agent.send(:build_settings_keyboard)

      expect(keyboard.inline_keyboard).not_to be_empty
      expect(keyboard.inline_keyboard.flatten).to include(
        have_attributes(text: include('delivery_frequency')),
        have_attributes(text: include('content_format')),
        have_attributes(text: include('filter_strictness'))
      )
    end
  end
end
```

### Шаг 3: Запусти тесты (должны упасть)

```bash
./bin/rspec spec/services/telegram/settings_agent_spec.rb
```

На этом этапе тесты должны упасть с ошибками, так как класс еще не существует или не реализован полностью.

### Шаг 4: Создай агент с минимальной реализацией (GREEN фаза)

Создай минимальный код, который проходит все тесты:

```ruby
# app/services/telegram/settings_agent.rb
class Telegram::SettingsAgent
  VALID_SETTINGS = %w[delivery_frequency content_format filter_strictness].freeze
  VALID_VALUES = {
    delivery_frequency: %w[real_time three_times_daily twice_daily once_daily every_few_days weekly on_demand],
    content_format: %w[original summaries unified_digest combo headlines],
    filter_strictness: %w[ultra high medium low smart]
  }.freeze

  def initialize(bot, user)
    @bot = bot
    @user = user
  end

  def show_settings
    text = build_settings_text
    keyboard = build_settings_keyboard

    bot.send_message(
      chat_id: @user.telegram_id,
      text: text,
      reply_markup: keyboard
    )
  end

  def update_setting(setting_name, value)
    return send_error(I18n.t('telegram_bot.settings.errors.invalid_setting')) unless VALID_SETTINGS.include?(setting_name)
    return send_error(I18n.t('telegram_bot.settings.errors.invalid_value')) unless valid_value?(setting_name, value)

    @user.update!("#{setting_name}": value)
    send_success(I18n.t('telegram_bot.settings.success.updated', setting: setting_name))
  end

  private

  def build_settings_text
    I18n.t('telegram_bot.settings.title') + "\n\n" +
    I18n.t('telegram_bot.settings.current_settings') + "\n\n" +
    I18n.t('telegram_bot.settings.delivery_frequency.label') +
    I18n.t("telegram_bot.settings.delivery_frequency.options.#{@user.delivery_frequency}") + "\n\n" +
    I18n.t('telegram_bot.settings.content_format.label') +
    I18n.t("telegram_bot.settings.content_format.options.#{@user.content_format}") + "\n\n" +
    I18n.t('telegram_bot.settings.filter_strictness.label') +
    I18n.t("telegram_bot.settings.filter_strictness.options.#{@user.filter_strictness}")
  end

  def build_settings_keyboard
    # используем Telegram::KeyboardHelpers
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

  def valid_value?(setting, value)
    VALID_VALUES[setting.to_sym]&.include?(value)
  end

  def send_error(message)
    bot.send_message(chat_id: @user.telegram_id, text: message)
  end

  def send_success(message)
    bot.send_message(chat_id: @user.telegram_id, text: message)
  end
end
```

### Шаг 5: Запусти тесты снова (должны пройти)

```bash
./bin/rspec spec/services/telegram/settings_agent_spec.rb
```

Теперь все тесты должны проходить.

### Шаг 6: Рефакторинг (REFACTOR фаза)

Теперь, когда тесты проходят, улучши код:

```ruby
# app/services/telegram/settings_agent.rb
class Telegram::SettingsAgent
  include Telegram::KeyboardHelpers

  VALID_SETTINGS = %w[delivery_frequency content_format filter_strictness].freeze
  VALID_VALUES = {
    delivery_frequency: %w[real_time three_times_daily twice_daily once_daily every_few_days weekly on_demand],
    content_format: %w[original summaries unified_digest combo headlines],
    filter_strictness: %w[ultra high medium low smart]
  }.freeze

  def initialize(bot, user)
    @bot = bot
    @user = user
    @logger = Rails.logger
  end

  def show_settings
    log_action('show_settings')

    bot.send_message(
      chat_id: @user.telegram_id,
      text: build_settings_text,
      reply_markup: build_settings_keyboard
    )
  rescue StandardError => e
    log_error('show_settings', e)
    send_error(I18n.t('telegram_bot.errors.general'))
  end

  def update_setting(setting_name, value)
    log_action('update_setting', { setting: setting_name, value: value })

    result = validate_setting(setting_name, value)
    return send_error(result[:error]) unless result[:success]

    @user.update!("#{setting_name}": value)
    send_success(I18n.t('telegram_bot.settings.success.updated', setting: setting_name))
  rescue StandardError => e
    log_error('update_setting', e)
    send_error(I18n.t('telegram_bot.errors.general'))
  end

  private

  def validate_setting(setting_name, value)
    unless VALID_SETTINGS.include?(setting_name)
      return { success: false, error: I18n.t('telegram_bot.settings.errors.invalid_setting') }
    end

    unless valid_value?(setting_name, value)
      return { success: false, error: I18n.t('telegram_bot.settings.errors.invalid_value') }
    end

    { success: true }
  end

  def build_settings_text
    I18n.t('telegram_bot.settings.title') + "\n\n" +
    I18n.t('telegram_bot.settings.current_settings') + "\n\n" +
    build_setting_section('delivery_frequency') +
    build_setting_section('content_format') +
    build_setting_section('filter_strictness')
  end

  def build_setting_section(setting_name)
    current_value = @user.public_send(setting_name)
    I18n.t("telegram_bot.settings.#{setting_name}.label") +
    I18n.t("telegram_bot.settings.#{setting_name}.options.#{current_value}") + "\n\n"
  end

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

  def valid_value?(setting, value)
    VALID_VALUES[setting.to_sym]&.include?(value)
  end

  def send_error(message)
    bot.send_message(chat_id: @user.telegram_id, text: message)
  end

  def send_success(message)
    bot.send_message(chat_id: @user.telegram_id, text: message)
  end

  def log_action(action, data = {})
    @logger.info "[Telegram::SettingsAgent] #{action} for user #{@user.id}: #{data.inspect}"
  end

  def log_error(action, error)
    @logger.error "[Telegram::SettingsAgent] Error in #{action}: #{error.message}"
    @logger.error error.backtrace.join("\n")
  end
end
```

### Шаг 7: Интегрируй агент в контроллер

Используй агент в Telegram контроллере:

```ruby
# app/controllers/telegram_webhook_controller.rb
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def settings!(*)
    agent = Telegram::SettingsAgent.new(bot, current_user)
    agent.show_settings
  end

  def settings_callback_query(*)
    agent = Telegram::SettingsAgent.new(bot, current_user)
    agent.show_settings
    answer_callback_query('')
  end

  def set_delivery_frequency_callback_query(frequency)
    agent = Telegram::SettingsAgent.new(bot, current_user)
    agent.update_setting('delivery_frequency', frequency)
    answer_callback_query('')
  end

  def set_content_format_callback_query(format)
    agent = Telegram::SettingsAgent.new(bot, current_user)
    agent.update_setting('content_format', format)
    answer_callback_query('')
  end

  def set_filter_strictness_callback_query(strictness)
    agent = Telegram::SettingsAgent.new(bot, current_user)
    agent.update_setting('filter_strictness', strictness)
    answer_callback_query('')
  end

  # ... другие методы
end
```

### Шаг 8: Добавь тесты для контроллера

```ruby
# spec/controllers/telegram_webhook_controller_spec.rb
RSpec.describe TelegramWebhookController, type: :telegram_bot_controller do
  describe '#settings!' do
    it 'shows current settings' do
      expect { dispatch_command :settings }.to send_telegram_message(
        bot,
        text: I18n.t('telegram_bot.settings.title')
      )
    end

    it 'sends message with keyboard' do
      expect { dispatch_command :settings }.to send_telegram_message(
        bot,
        reply_markup: kind_of(Telegram::Bot::Types::InlineKeyboardMarkup)
      )
    end
  end

  describe '#set_delivery_frequency_callback_query' do
    let(:frequency) { 'real_time' }

    it 'updates delivery frequency' do
      expect {
        dispatch_callback_query "set_delivery_frequency:#{frequency}"
      }.to change { telegram_user.reload.delivery_frequency }.to(frequency)
    end

    it 'answers callback query' do
      expect { dispatch_callback_query "set_delivery_frequency:#{frequency}" }
        .to answer_callback_query('')
    end
  end

  describe '#set_content_format_callback_query' do
    let(:format) { 'summaries' }

    it 'updates content format' do
      expect {
        dispatch_callback_query "set_content_format:#{format}"
      }.to change { telegram_user.reload.content_format }.to(format)
    end
  end

  describe '#set_filter_strictness_callback_query' do
    let(:strictness) { 'high' }

    it 'updates filter strictness' do
      expect {
        dispatch_callback_query "set_filter_strictness:#{strictness}"
      }.to change { telegram_user.reload.filter_strictness }.to(strictness)
    end
  end
end
```

## Ключевые принципы TDD для Telegram агентов

### 1. Изолируй логику от Telegram API
Используй mock/double для bot в тестах:

```ruby
let(:bot) { double('Telegram::Bot::Client') }
expect(bot).to receive(:send_message).with(...)
```

### 2. Тестируй сообщения
Проверяй текст и структуру сообщений:

```ruby
expect { dispatch_command :help }.to send_telegram_message(
  bot,
  text: include('помощь', 'команды'),
  reply_markup: instance_of(Telegram::Bot::Types::InlineKeyboardMarkup)
)
```

### 3. Тестируй состояния
Проверяй изменения в базе данных:

```ruby
expect {
  dispatch_callback_query "set_value:new_value"
}.to change { user.reload.some_setting }.to('new_value')
```

### 4. Используй фабрики
Создавай тестовые данные с помощью Factory Bot:

```ruby
let(:user) { create(:telegram_user, :with_settings) }
let(:channel) { create(:channel, :active) }
```

### 5. Проверяй ошибки
Тестируй обработку невалидных данных:

```ruby
context 'with invalid data' do
  it 'sends error message' do
    expect { dispatch_callback_query 'invalid:data' }.to send_telegram_message(
      bot,
      text: include('ошибка', 'неверно')
    )
  end
end
```

### 6. Используй I18n
Тестируй локализуемые сообщения через полные ключи:

```ruby
expect(response).to send_telegram_message(
  bot,
  text: I18n.t('telegram_bot.settings.title')
)
```

## Структура тестовых файлов

```
spec/
├── services/
│   └── telegram/
│       ├── settings_agent_spec.rb
│       ├── channel_service_spec.rb
│       └── message_sender_spec.rb
├── controllers/
│   └── telegram_webhook_controller_spec.rb
├── models/
│   └── telegram_user_spec.rb
└── factories/
    └── telegram_users.rb
```

## Пример фабрики для тестов

```ruby
# spec/factories/telegram_users.rb
FactoryBot.define do
  factory :telegram_user do
    username { "user_#{SecureRandom.hex(4)}" }
    first_name { 'Test' }
    last_name { 'User' }
    language_code { 'ru' }
    is_premium { false }
    is_bot { false }
    delivery_frequency { 'real_time' }
    content_format { 'original' }
    filter_strictness { 'medium' }

    trait :admin do
      is_admin { true }
    end

    trait :premium do
      is_premium { true }
    end

    trait :with_subscriptions do
      after(:create) do |user|
        create_list(:subscription, 3, user: user, active: true)
      end
    end
  end
end
```

## Best Practices

### 1. Один агент - одна ответственность
Каждый агент должен отвечать за одну область функциональности:
- `SettingsAgent` - управление настройками
- `ChannelAgent` - работа с каналами
- `SubscriptionAgent` - управление подписками

### 2. Используй Dependency Injection
Передавай зависимости через конструктор:

```ruby
def initialize(bot, user, logger: Rails.logger, cache: Rails.cache)
  @bot = bot
  @user = user
  @logger = logger
  @cache = cache
end
```

### 3. Валидация входных данных
Проверяй все входные данные в агенте:

```ruby
def process_command(command, args)
  return error_response('invalid_command') unless valid_command?(command)
  return error_response('invalid_args') unless valid_args?(command, args)

  # основная логика
end
```

### 4. Обработка ошибок
Обрабатывай все возможные ошибки:

```ruby
def perform_action
  # risky operation
rescue Telegram::Bot::Error => e
  log_telegram_error(e)
  error_response('telegram_error')
rescue StandardError => e
  log_general_error(e)
  error_response('general_error')
end
```

### 5. Логирование
Добавляй логирование для отладки:

```ruby
def process_data(data)
  logger.info "[#{self.class}] Processing data: #{data.inspect}"
  result = expensive_operation(data)
  logger.info "[#{self.class}] Processing completed in #{result[:time]}ms"
  result
end
```

### 6. Кеширование
Используй кеширование для улучшения производительности:

```ruby
def get_cached_data(key)
  @cache.fetch("telegram_agent:#{key}", expires_in: 1.hour) do
    expensive_database_query(key)
  end
end
```

### 7. Тестируй edge cases
Проверяй граничные случаи:

```ruby
context 'when user has no subscriptions' do
  let(:user) { create(:telegram_user, subscriptions: []) }

  it 'shows empty state message' do
    expect { dispatch_command :list }.to send_telegram_message(
      bot,
      text: I18n.t('telegram_bot.subscriptions.empty')
    )
  end
end

context 'when user exceeds subscription limit' do
  before { create_list(:subscription, 11, user: user) }

  it 'shows limit error' do
    expect { dispatch_callback_query 'add:new_channel' }.to send_telegram_message(
      bot,
      text: I18n.t('telegram_bot.channels.add.limit_reached', limit: 10)
    )
  end
end
```

## Заключение

TDD для Telegram агентов помогает создавать надежный, тестируемый и поддерживаемый код. Следуя этим принципам, ты сможешь:

- Писать код, который гарантированно работает
- Быстро находить и исправлять ошибки
- Безопасно рефакторить существующий код
- Создавать понятную архитектуру приложения
- Иметь живую документацию в виде тестов

Начинай с простых агентов, постепенно усложняя функциональность, и всегда следуй циклу RED-GREEN-REFACTOR.