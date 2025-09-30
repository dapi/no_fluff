# Telegram Bot Ruby Gem - Руководство разработчика

## Введение

`telegram-bot` (telegram-bot-rb) — это Ruby gem для разработки Telegram-ботов с опциональной интеграцией в Rails. Gem предоставляет мощный фреймворк для создания ботов с поддержкой контроллеров, роутинга, сессий и middleware.

**Основные возможности:**
- Rails-интеграция из коробки
- Webhook и Polling режимы
- Контроллеры в стиле Rails
- Управление сессиями
- Типизированные ответы
- Поддержка inline-клавиатур и callback queries
- Middleware система
- Встроенная поддержка тестирования

**GitHub:** https://github.com/telegram-bot-rb/telegram-bot

---

## Quick Start

### Установка

Добавьте в `Gemfile`:

```ruby
gem 'telegram-bot'
```

Выполните:

```bash
bundle install
```

### Базовая настройка в Rails

#### 1. Конфигурация бота

В `config/secrets.yml` или Rails credentials:

```yaml
default: &default
  telegram:
    bot:
      token: YOUR_BOT_TOKEN
      username: YourBotUsername # опционально

production:
  <<: *default
  telegram:
    bot:
      token: <%= ENV['TELEGRAM_BOT_TOKEN'] %>
```

Для нескольких ботов:

```ruby
# config/initializers/telegram.rb
Telegram.bots_config = {
  default: ENV['DEFAULT_BOT_TOKEN'],
  chat: {
    token: ENV['CHAT_BOT_TOKEN'],
    username: 'ChatBot'
  }
}
```

#### 2. Создание контроллера

Создайте контроллер, наследующийся от `Telegram::Bot::UpdatesController`:

```ruby
# app/controllers/telegram_webhook_controller.rb
class TelegramWebhookController < Telegram::Bot::UpdatesController
  # Обработка команды /start
  def start!(word = nil, *other_words)
    respond_with :message, text: "Привет! Я бот."
  end

  # Обработка обычных текстовых сообщений
  def message(message)
    respond_with :message, text: "Вы написали: #{message['text']}"
  end
end
```

#### 3. Настройка маршрутов

В `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  telegram_webhook TelegramWebhookController

  # Для нескольких ботов:
  # telegram_webhook TelegramWebhookController, :default
  # telegram_webhook TelegramChatController, :chat
end
```

#### 4. Установка webhook

Для production с webhook:

```bash
rake telegram:bot:set_webhook RAILS_ENV=production
```

Для development с polling:

```bash
rake telegram:bot:poller
```

---

## Webhook vs Polling

### Webhook (рекомендуется для production)

**Преимущества:**
- Масштабируемость (работает на нескольких процессах)
- Мгновенная доставка обновлений
- Меньшая нагрузка на сервер

**Настройка:**
```bash
# Установить webhook
rake telegram:bot:set_webhook RAILS_ENV=production

# С самоподписанным сертификатом
rake telegram:bot:set_webhook RAILS_ENV=production CERT=path/to/cert.pem
```

**Важно:** Переустанавливайте webhook при изменении домена, токена или сертификата.

### Polling (удобен для development)

**Преимущества:**
- Не требует публичного URL
- Автоматическая перезагрузка кода в development
- Простая настройка

**Запуск:**
```bash
# Запустить poller для всех ботов
rake telegram:bot:poller

# Для конкретного бота
BOT=chat rake telegram:bot:poller
```

**Ограничения:**
- Только один процесс может опрашивать обновления
- Требует отдельного процесса
- Не масштабируется

---

## Основные концепции

### Структура контроллера

Контроллер наследуется от `Telegram::Bot::UpdatesController` и определяет методы для обработки различных типов обновлений:

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  # Команды (с восклицательным знаком)
  def start!(*)
    respond_with :message, text: 'Привет!'
  end

  def help!(*)
    respond_with :message, text: 'Помощь'
  end

  # Обработка обычных сообщений
  def message(message)
    # message - хеш с данными сообщения
  end

  # Обработка callback queries
  def callback_query(data)
    # data - строка с callback_data
  end

  # Обработка inline queries
  def inline_query(query, offset)
    # query - текст запроса
  end
end
```

### Команды с параметрами

Методы команд автоматически получают параметры:

```ruby
def start!(word = nil, *other_words)
  if word
    respond_with :message, text: "Вы написали: #{word} #{other_words.join(' ')}"
  else
    respond_with :message, text: "Привет! Используйте /start слово"
  end
end

# /start hello world → word='hello', other_words=['world']
```

### Respond With

`respond_with` - основной метод для отправки ответов. Он вызывает `bot.send_#{type}` с автоматически установленным `chat_id`:

```ruby
# Текстовое сообщение
respond_with :message, text: 'Привет!'

# С Markdown разметкой
respond_with :message, text: '__Жирный текст__', parse_mode: :Markdown

# Отправка фото
respond_with :photo, photo: File.open('photo.jpg'), caption: 'Красиво!'

# С клавиатурой
respond_with :message, text: 'Выберите:', reply_markup: markup
```

### Доступ к bot API

Через `bot` можно вызывать любые методы Telegram Bot API:

```ruby
# Прямой вызов API
bot.send_message(chat_id: chat_id, text: 'Привет')

# Получение информации о боте
bot.get_me

# Отправка действия "печатает..."
bot.send_chat_action(chat_id: chat_id, action: 'typing')
```

---

## Роутинг и команды

### Автоматический роутинг команд

Методы с восклицательным знаком (`!`) автоматически обрабатывают команды:

```ruby
def start!(*)      # /start
def help!(*)       # /help
def settings!(*)   # /settings
```

### MessageContext - контекст сообщений

Модуль `MessageContext` позволяет сохранять контекст для следующего сообщения:

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  def rename!(*)
    save_context :rename_from_message
    respond_with :message, text: 'Какое имя вам нравится?'
  end

  # Будет вызван для следующего сообщения
  def rename_from_message(*words)
    update_name(words.first)
    respond_with :message, text: "Имя изменено на #{words.first}!"
  end
end
```

### CallbackQueryContext - роутинг callback'ов

Модуль `CallbackQueryContext` позволяет разделять обработку callback queries по префиксам:

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext

  # Обрабатывает callback_data вида "set_value:something"
  def set_value_callback_query(new_value = nil, *)
    save_value(new_value)
    answer_callback_query('Сохранено!')
  end

  # Обрабатывает callback_data вида "delete:123"
  def delete_callback_query(item_id = nil, *)
    delete_item(item_id)
    answer_callback_query('Удалено!')
  end

  # Остальные callback'и без префикса
  def callback_query(data)
    answer_callback_query('Неизвестная команда')
  end
end
```

**Формат данных:** `prefix:param1:param2:...`

---

## Session Management

### Подключение сессий

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::Session
  # или используйте: use_session!

  def start!(*)
    session[:visits] ||= 0
    session[:visits] += 1
    respond_with :message, text: "Вы посетили бота #{session[:visits]} раз"
  end
end
```

### Настройка хранилища сессий

В `config/environments/production.rb`:

```ruby
# Используйте Redis для production
Telegram::Bot::UpdatesController.session_store = :redis_store, {
  url: ENV['REDIS_URL'],
  expires_in: 1.month
}
```

Доступные хранилища (ActiveSupport::Cache):
- `:memory_store` - для development/testing
- `:file_store` - файловое хранилище
- `:redis_store` - Redis (рекомендуется для production)
- `:mem_cache_store` - Memcached

### API сессий

Сессии работают похоже на Rails сессии:

```ruby
# Чтение
session[:key]

# Запись
session[:key] = value

# Удаление
session.delete(:key)

# Очистка всей сессии
session.clear
```

**Важно:** Ключ сессии строится на основе `bot.username` и ID пользователя/чата, поэтому сессии изолированы для каждого пользователя.

---

## Работа с клавиатурами

### Reply Keyboard (обычная клавиатура)

```ruby
# Простая клавиатура
kb = [['Да', 'Нет'], ['Может быть']]
markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
  keyboard: kb,
  one_time_keyboard: true, # скрыть после использования
  resize_keyboard: true    # адаптировать размер
)

respond_with :message, text: 'Вы согласны?', reply_markup: markup
```

### Клавиатура с запросом контактов/локации

```ruby
kb = [[
  Telegram::Bot::Types::KeyboardButton.new(
    text: 'Поделиться телефоном',
    request_contact: true
  ),
  Telegram::Bot::Types::KeyboardButton.new(
    text: 'Поделиться локацией',
    request_location: true
  )
]]

markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb)
respond_with :message, text: 'Нажмите кнопку:', reply_markup: markup
```

### Скрыть клавиатуру

```ruby
markup = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
respond_with :message, text: 'Клавиатура скрыта', reply_markup: markup
```

---

## Inline-клавиатуры и Callback Queries

### Создание Inline-клавиатуры

```ruby
kb = [
  [
    Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Google',
      url: 'https://google.com'
    ),
    Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Нажми меня',
      callback_data: 'button_clicked'
    )
  ],
  [
    Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Inline запрос',
      switch_inline_query: 'текст запроса'
    )
  ]
]

markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
respond_with :message, text: 'Выберите действие:', reply_markup: markup
```

### Обработка Callback Query

```ruby
def callback_query(data)
  case data
  when 'button_clicked'
    answer_callback_query('Вы нажали кнопку!', show_alert: false)

  when /^delete:(\d+)$/
    item_id = $1
    delete_item(item_id)
    answer_callback_query('Удалено!')

    # Отредактировать сообщение
    edit_message :text, text: 'Элемент удален'
  end
end
```

### Answer Callback Query

```ruby
# Простое уведомление (всплывающее)
answer_callback_query('Готово!')

# Алерт (требует подтверждения)
answer_callback_query('Важное сообщение!', show_alert: true)

# С URL
answer_callback_query(url: 'https://example.com')
```

### Редактирование сообщений

```ruby
# Редактировать текст
edit_message :text, text: 'Новый текст'

# Редактировать текст и клавиатуру
edit_message :text, text: 'Обновлено', reply_markup: new_markup

# Редактировать только клавиатуру
edit_message :reply_markup, reply_markup: new_markup

# Удалить inline-клавиатуру
edit_message :reply_markup,
  reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [])
```

---

## Inline Queries

### Обработка Inline-запросов

```ruby
def inline_query(query, offset)
  results = search_results(query, offset)

  answer_inline_query(
    results.map do |item|
      Telegram::Bot::Types::InlineQueryResultArticle.new(
        id: item.id,
        title: item.title,
        input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(
          message_text: item.text
        ),
        description: item.description
      )
    end
  )
end
```

### Типы результатов Inline Query

```ruby
# Статья
Telegram::Bot::Types::InlineQueryResultArticle.new(
  id: '1',
  title: 'Заголовок',
  input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(
    message_text: 'Текст сообщения'
  )
)

# Фото
Telegram::Bot::Types::InlineQueryResultPhoto.new(
  id: '2',
  photo_url: 'https://example.com/photo.jpg',
  thumbnail_url: 'https://example.com/thumb.jpg'
)

# Видео
Telegram::Bot::Types::InlineQueryResultVideo.new(
  id: '3',
  video_url: 'https://example.com/video.mp4',
  mime_type: 'video/mp4',
  thumbnail_url: 'https://example.com/thumb.jpg',
  title: 'Видео'
)
```

---

## Работа с медиа

### Отправка фото

```ruby
# Из файла
respond_with :photo, photo: File.open('path/to/photo.jpg'), caption: 'Описание'

# По URL (только для некоторых методов)
bot.send_photo(chat_id: chat_id, photo: 'https://example.com/photo.jpg')

# По file_id (уже загруженный файл)
respond_with :photo, photo: 'AgACAgIAAxkBAAI...'
```

### Отправка документов

```ruby
respond_with :document,
  document: File.open('document.pdf'),
  caption: 'Ваш документ'
```

### Отправка голосовых и аудио

```ruby
# Голосовое сообщение
respond_with :voice, voice: File.open('voice.ogg')

# Аудио файл
respond_with :audio,
  audio: File.open('music.mp3'),
  title: 'Название',
  performer: 'Исполнитель'
```

### Отправка локации

```ruby
respond_with :location, latitude: 55.751244, longitude: 37.618423
```

### Отправка контакта

```ruby
respond_with :contact,
  phone_number: '+79001234567',
  first_name: 'Иван',
  last_name: 'Иванов'
```

---

## Типизированные ответы

Для автоматического преобразования ответов API в типизированные объекты:

```ruby
# Для всех ботов
Telegram::Bot::Client.typed_response!

# Или для конкретного бота
bot.extend Telegram::Bot::Client::TypedResponse

# Теперь ответы возвращают объекты типов
message = bot.send_message(chat_id: chat_id, text: 'Hello')
message.class # => Telegram::Bot::Types::Message
message.text  # => "Hello"
```

---

## Middleware

### Создание middleware

```ruby
class LoggingMiddleware
  def initialize(bot)
    @bot = bot
  end

  def call(update)
    Rails.logger.info "Received update: #{update}"
    yield update # передать управление дальше
  end
end
```

### Подключение middleware

```ruby
# В контроллере
class TelegramWebhookController < Telegram::Bot::UpdatesController
  use LoggingMiddleware

  def message(message)
    respond_with :message, text: 'OK'
  end
end
```

### Примеры middleware

#### Middleware для статистики

```ruby
class StatisticsMiddleware
  def initialize(bot)
    @bot = bot
  end

  def call(update)
    user_id = update.dig('message', 'from', 'id') ||
              update.dig('callback_query', 'from', 'id')

    increment_user_stats(user_id) if user_id
    yield update
  end

  private

  def increment_user_stats(user_id)
    # Ваша логика
  end
end
```

#### Middleware для авторизации

```ruby
class AuthorizationMiddleware
  def initialize(bot)
    @bot = bot
  end

  def call(update)
    user_id = extract_user_id(update)

    if authorized?(user_id)
      yield update
    else
      send_unauthorized_message(user_id)
    end
  end

  private

  def authorized?(user_id)
    # Проверка авторизации
  end

  def extract_user_id(update)
    update.dig('message', 'from', 'id') ||
    update.dig('callback_query', 'from', 'id')
  end

  def send_unauthorized_message(user_id)
    @bot.send_message(
      chat_id: user_id,
      text: 'У вас нет доступа к этому боту'
    )
  end
end
```

---

## Тестирование

### Настройка RSpec

В `config/environments/test.rb`:

```ruby
# Важно: выполнить ДО определения маршрутов!
Telegram.reset_bots
Telegram::Bot::ClientStub.stub_all!
```

В `spec/rails_helper.rb`:

```ruby
RSpec.configure do |config|
  # Сброс после каждого теста
  config.after do
    Telegram.bot.reset
  end

  # Или для нескольких ботов:
  config.after do
    Telegram.bots.each_value(&:reset)
  end
end
```

### Тестирование контроллеров

```ruby
require 'telegram/bot/updates_controller/rspec_helpers'

RSpec.describe TelegramWebhookController, type: :telegram_bot_controller do
  describe '#start!' do
    subject { -> { dispatch_command :start } }

    it 'responds with greeting' do
      expect { subject.call }.to send_telegram_message(
        bot,
        text: /Привет/
      )
    end
  end

  describe '#message' do
    let(:message_text) { 'Hello' }

    it 'echoes the message' do
      expect { dispatch_message message_text }.to send_telegram_message(
        bot,
        text: "Вы написали: #{message_text}"
      )
    end
  end

  describe '#callback_query' do
    it 'handles button click' do
      expect { dispatch_callback_query 'button_clicked' }
        .to answer_callback_query('Готово!')
    end
  end
end
```

### Проверка отправленных сообщений

```ruby
# Проверить, что сообщение отправлено
expect { dispatch_command :start }.to send_telegram_message(bot)

# С конкретным текстом
expect { dispatch_command :start }.to send_telegram_message(
  bot,
  text: 'Привет!'
)

# С regexp
expect { dispatch_command :start }.to send_telegram_message(
  bot,
  text: /Привет/
)

# С клавиатурой
expect { dispatch_command :menu }.to send_telegram_message(
  bot,
  text: 'Меню',
  reply_markup: kind_of(Telegram::Bot::Types::InlineKeyboardMarkup)
)
```

### Тестирование с сессиями

```ruby
RSpec.describe TelegramWebhookController, type: :telegram_bot_controller do
  describe 'session handling' do
    it 'counts visits' do
      session[:visits] = 5

      expect { dispatch_command :start }.to send_telegram_message(
        bot,
        text: /6 раз/
      )

      expect(session[:visits]).to eq(6)
    end
  end
end
```

### ClientStub API

```ruby
# Проверить все запросы
Telegram.bot.requests

# Последний запрос
Telegram.bot.requests.last

# Очистить запросы
Telegram.bot.reset
```

---

## API Reference

### Основные методы отправки

#### send_message
```ruby
bot.send_message(
  chat_id: chat_id,
  text: 'Текст',
  parse_mode: 'Markdown', # или 'HTML'
  disable_web_page_preview: true,
  disable_notification: true,
  reply_to_message_id: message_id,
  reply_markup: markup
)
```

#### send_photo
```ruby
bot.send_photo(
  chat_id: chat_id,
  photo: File.open('photo.jpg'),
  caption: 'Описание',
  parse_mode: 'Markdown'
)
```

#### send_document
```ruby
bot.send_document(
  chat_id: chat_id,
  document: File.open('file.pdf'),
  caption: 'Документ'
)
```

#### send_audio
```ruby
bot.send_audio(
  chat_id: chat_id,
  audio: File.open('audio.mp3'),
  caption: 'Описание',
  duration: 243,
  performer: 'Исполнитель',
  title: 'Название'
)
```

#### send_video
```ruby
bot.send_video(
  chat_id: chat_id,
  video: File.open('video.mp4'),
  caption: 'Описание',
  duration: 60,
  width: 1920,
  height: 1080
)
```

#### send_voice
```ruby
bot.send_voice(
  chat_id: chat_id,
  voice: File.open('voice.ogg'),
  caption: 'Голосовое',
  duration: 10
)
```

#### send_location
```ruby
bot.send_location(
  chat_id: chat_id,
  latitude: 55.751244,
  longitude: 37.618423
)
```

#### send_contact
```ruby
bot.send_contact(
  chat_id: chat_id,
  phone_number: '+79001234567',
  first_name: 'Иван',
  last_name: 'Иванов'
)
```

#### send_chat_action
```ruby
bot.send_chat_action(
  chat_id: chat_id,
  action: 'typing' # typing, upload_photo, record_video, upload_video,
                   # record_audio, upload_audio, upload_document,
                   # find_location, record_video_note, upload_video_note
)
```

### Методы редактирования

#### edit_message_text
```ruby
bot.edit_message_text(
  chat_id: chat_id,
  message_id: message_id,
  text: 'Новый текст',
  parse_mode: 'Markdown',
  reply_markup: markup
)
```

#### edit_message_caption
```ruby
bot.edit_message_caption(
  chat_id: chat_id,
  message_id: message_id,
  caption: 'Новое описание',
  reply_markup: markup
)
```

#### edit_message_reply_markup
```ruby
bot.edit_message_reply_markup(
  chat_id: chat_id,
  message_id: message_id,
  reply_markup: markup
)
```

#### delete_message
```ruby
bot.delete_message(
  chat_id: chat_id,
  message_id: message_id
)
```

### Методы для callback queries

#### answer_callback_query
```ruby
bot.answer_callback_query(
  callback_query_id: callback_query_id,
  text: 'Уведомление',
  show_alert: false, # true для алерта
  url: 'https://example.com' # опционально
)
```

### Методы для inline queries

#### answer_inline_query
```ruby
bot.answer_inline_query(
  inline_query_id: inline_query_id,
  results: [result1, result2],
  cache_time: 300,
  is_personal: true,
  next_offset: 'next_page_token'
)
```

### Информационные методы

#### get_me
```ruby
bot_info = bot.get_me
# => { "id" => 123456, "is_bot" => true, "first_name" => "MyBot", ... }
```

#### get_chat
```ruby
chat_info = bot.get_chat(chat_id: chat_id)
```

#### get_chat_member
```ruby
member = bot.get_chat_member(chat_id: chat_id, user_id: user_id)
```

#### get_chat_administrators
```ruby
admins = bot.get_chat_administrators(chat_id: chat_id)
```

---

## Примеры кода для типовых задач

### Бот с меню

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def start!(*)
    show_menu
  end

  def menu!(*)
    show_menu
  end

  private

  def show_menu
    kb = [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: 'Настройки',
          callback_data: 'settings'
        ),
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: 'Помощь',
          callback_data: 'help'
        )
      ],
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: 'О боте',
          callback_data: 'about'
        )
      ]
    ]

    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    respond_with :message, text: 'Главное меню:', reply_markup: markup
  end

  def callback_query(data)
    case data
    when 'settings'
      edit_message :text, text: 'Настройки бота'
    when 'help'
      edit_message :text, text: 'Раздел помощи'
    when 'about'
      edit_message :text, text: 'О боте: версия 1.0'
    end

    answer_callback_query
  end
end
```

### Пагинация с inline-кнопками

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::CallbackQueryContext

  def list!(*)
    show_page(0)
  end

  def page_callback_query(page_num = '0')
    show_page(page_num.to_i)
    answer_callback_query
  end

  private

  def show_page(page)
    items = get_items_for_page(page)
    total_pages = get_total_pages

    kb = items.map do |item|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text: item.name,
        callback_data: "item:#{item.id}"
      )]
    end

    # Кнопки навигации
    nav_buttons = []
    nav_buttons << Telegram::Bot::Types::InlineKeyboardButton.new(
      text: '◀️ Назад',
      callback_data: "page:#{page - 1}"
    ) if page > 0

    nav_buttons << Telegram::Bot::Types::InlineKeyboardButton.new(
      text: "#{page + 1}/#{total_pages}",
      callback_data: 'noop'
    )

    nav_buttons << Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Вперед ▶️',
      callback_data: "page:#{page + 1}"
    ) if page < total_pages - 1

    kb << nav_buttons

    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)

    if payload['callback_query']
      edit_message :text, text: "Страница #{page + 1}", reply_markup: markup
    else
      respond_with :message, text: "Страница #{page + 1}", reply_markup: markup
    end
  end

  def get_items_for_page(page)
    # Ваша логика
  end

  def get_total_pages
    # Ваша логика
  end
end
```

### Многошаговый диалог с сессиями

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::Session
  include Telegram::Bot::UpdatesController::MessageContext

  def register!(*)
    session[:registration] = {}
    save_context :ask_name
    respond_with :message, text: 'Как вас зовут?'
  end

  def ask_name(name)
    session[:registration][:name] = name
    save_context :ask_age
    respond_with :message, text: 'Сколько вам лет?'
  end

  def ask_age(age)
    session[:registration][:age] = age.to_i
    save_context :ask_city
    respond_with :message, text: 'В каком городе вы живете?'
  end

  def ask_city(city)
    session[:registration][:city] = city

    # Завершаем регистрацию
    user = create_user(session[:registration])
    session.delete(:registration)

    respond_with :message, text: "Спасибо за регистрацию, #{user.name}!"
  end

  private

  def create_user(data)
    User.create!(data)
  end
end
```

### Отправка файлов с прогрессом

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def report!(*)
    # Показываем "typing..."
    bot.send_chat_action(chat_id: chat['id'], action: 'upload_document')

    # Генерируем отчет
    report_path = generate_report

    # Отправляем файл
    respond_with :document,
      document: File.open(report_path),
      caption: "Отчет от #{Date.today}"

    # Удаляем временный файл
    File.delete(report_path)
  end

  private

  def generate_report
    # Ваша логика генерации отчета
    '/tmp/report.pdf'
  end
end
```

### Обработка фото от пользователя

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def photo(photo_sizes)
    # photo_sizes - массив размеров фото
    largest_photo = photo_sizes.max_by { |p| p['file_size'] }

    # Получаем информацию о файле
    file = bot.get_file(file_id: largest_photo['file_id'])

    # URL для скачивания
    file_url = "https://api.telegram.org/file/bot#{bot.token}/#{file['result']['file_path']}"

    respond_with :message, text: "Получено фото. Размер: #{largest_photo['file_size']} байт"

    # Можно скачать файл
    # download_and_save(file_url)
  end

  private

  def download_and_save(url)
    require 'open-uri'
    URI.open(url) do |file|
      File.open("downloaded_photo.jpg", "wb") do |out|
        out.write(file.read)
      end
    end
  end
end
```

---

## Best Practices

### 1. Структура проекта

```
app/
  controllers/
    telegram/
      base_controller.rb         # Базовый контроллер с общей логикой
      webhook_controller.rb      # Основной контроллер
      admin_controller.rb        # Админ команды
  services/
    telegram/
      message_sender.rb          # Сервис для отправки сообщений
      keyboard_builder.rb        # Построение клавиатур
  models/
    telegram_user.rb             # Модель пользователя бота
```

### 2. Используйте базовый контроллер

```ruby
# app/controllers/telegram/base_controller.rb
module Telegram
  class BaseController < Telegram::Bot::UpdatesController
    include Session

    private

    def current_user
      @current_user ||= TelegramUser.find_or_create_by(
        telegram_id: from['id']
      ) do |user|
        user.username = from['username']
        user.first_name = from['first_name']
        user.last_name = from['last_name']
      end
    end

    def authorized?
      current_user.active?
    end

    def check_authorization!
      unless authorized?
        respond_with :message, text: 'У вас нет доступа'
        throw :abort
      end
    end
  end
end
```

### 3. Выносите логику в сервисы

```ruby
# app/services/telegram/message_sender.rb
module Telegram
  class MessageSender
    def initialize(bot, chat_id)
      @bot = bot
      @chat_id = chat_id
    end

    def send_welcome
      @bot.send_message(
        chat_id: @chat_id,
        text: welcome_text,
        reply_markup: welcome_keyboard
      )
    end

    private

    def welcome_text
      "Добро пожаловать! 👋\n\nЧто вы хотите сделать?"
    end

    def welcome_keyboard
      # Логика построения клавиатуры
    end
  end
end
```

### 4. Обрабатывайте ошибки

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  rescue_from StandardError do |exception|
    Rails.logger.error "Bot error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    respond_with :message,
      text: 'Произошла ошибка. Попробуйте позже.'
  end

  rescue_from ActiveRecord::RecordNotFound do
    respond_with :message, text: 'Запись не найдена'
  end
end
```

### 5. Используйте константы для callback_data

```ruby
module TelegramCallbacks
  SETTINGS = 'settings'
  HELP = 'help'
  BACK_TO_MENU = 'back_to_menu'

  module Settings
    LANGUAGE = 'settings:language'
    NOTIFICATIONS = 'settings:notifications'
  end
end

def callback_query(data)
  case data
  when TelegramCallbacks::SETTINGS
    show_settings
  when TelegramCallbacks::HELP
    show_help
  end
end
```

### 6. Логируйте действия пользователей

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  before_action :log_user_action

  private

  def log_user_action
    TelegramLog.create!(
      user_id: current_user.id,
      action: action_name,
      payload: payload.to_json
    )
  end
end
```

### 7. Кешируйте данные

```ruby
def get_categories
  Rails.cache.fetch('telegram_categories', expires_in: 1.hour) do
    Category.active.order(:name).to_a
  end
end
```

### 8. Используйте фоновые задачи для долгих операций

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def generate_report!(*)
    respond_with :message, text: 'Генерирую отчет, это может занять время...'

    GenerateReportJob.perform_later(
      bot_token: bot.token,
      chat_id: chat['id']
    )
  end
end

# app/jobs/generate_report_job.rb
class GenerateReportJob < ApplicationJob
  def perform(bot_token:, chat_id:)
    bot = Telegram::Bot::Client.new(bot_token)

    report_path = generate_report

    bot.send_document(
      chat_id: chat_id,
      document: File.open(report_path),
      caption: 'Ваш отчет готов'
    )
  end
end
```

### 9. Валидируйте входные данные

```ruby
def set_age_callback_query(age_str)
  age = age_str.to_i

  if age < 18 || age > 120
    answer_callback_query('Укажите корректный возраст', show_alert: true)
    return
  end

  current_user.update!(age: age)
  answer_callback_query('Возраст сохранен')
  edit_message :text, text: "Ваш возраст: #{age}"
end
```

### 10. Ограничивайте частоту запросов

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  before_action :check_rate_limit

  private

  def check_rate_limit
    key = "telegram_rate_limit:#{from['id']}"
    count = Rails.cache.read(key) || 0

    if count > 30 # максимум 30 запросов в минуту
      respond_with :message, text: 'Слишком много запросов. Подождите.'
      throw :abort
    end

    Rails.cache.write(key, count + 1, expires_in: 1.minute)
  end
end
```

---

## Troubleshooting

### Проблема: Бот не отвечает

**Решение:**
1. Проверьте, что webhook установлен: `rake telegram:bot:set_webhook RAILS_ENV=production`
2. Убедитесь, что URL доступен извне (проверьте через curl)
3. Проверьте логи Rails на наличие ошибок
4. Убедитесь, что токен бота правильный

### Проблема: "Poller not found for :default"

**Решение:**
Убедитесь, что конфигурация бота выполняется ДО определения маршрутов:

```ruby
# config/environments/development.rb
Rails.application.configure do
  # Конфигурация бота должна быть здесь
  config.telegram_updates_controller.session_store = :memory_store
end
```

### Проблема: Сессии не работают

**Решение:**
1. Убедитесь, что подключили модуль Session:
   ```ruby
   include Telegram::Bot::UpdatesController::Session
   ```
2. Проверьте конфигурацию хранилища сессий
3. Для Redis убедитесь, что Redis запущен и доступен

### Проблема: Callback queries не отвечают

**Решение:**
Всегда вызывайте `answer_callback_query`, даже если не показываете уведомление:

```ruby
def callback_query(data)
  # Ваша логика

  # ОБЯЗАТЕЛЬНО ответить
  answer_callback_query
end
```

### Проблема: Файлы не загружаются

**Решение:**
1. Убедитесь, что файл существует и доступен для чтения
2. Используйте `File.open` для файлов:
   ```ruby
   respond_with :photo, photo: File.open('path/to/file.jpg')
   ```
3. Проверьте размер файла (есть ограничения Telegram)

### Проблема: Webhook получает дублированные обновления

**Решение:**
Убедитесь, что:
1. У вас нет запущенного poller одновременно с webhook
2. Не запущено несколько инстансов приложения с одним токеном
3. Webhook URL установлен только один раз

### Проблема: Не работают inline-кнопки

**Решение:**
1. Проверьте, что используете `InlineKeyboardMarkup`, а не `ReplyKeyboardMarkup`
2. Убедитесь, что `callback_data` не превышает 64 байта
3. Реализуйте метод `callback_query` в контроллере

### Проблема: Тесты падают с ошибкой про бота

**Решение:**
Добавьте в `test.rb`:
```ruby
Telegram.reset_bots
Telegram::Bot::ClientStub.stub_all!
```

---

## Полезные ссылки

### Документация

- **GitHub репозиторий:** https://github.com/telegram-bot-rb/telegram-bot
- **RubyDoc:** https://www.rubydoc.info/gems/telegram-bot
- **Telegram Bot API:** https://core.telegram.org/bots/api
- **Telegram Bot Features:** https://core.telegram.org/bots/features

### Примеры

- **Sample Rails App:** https://github.com/telegram-bot-rb/telegram_bot_app
- **Telegram Bot API Examples:** https://core.telegram.org/bots/samples

### Связанные gems

- **telegram-bot-types:** Типы для Telegram Bot API
- **activesupport:** Для кеширования и других утилит
- **redis:** Рекомендуется для хранения сессий в production

### Инструменты

- **BotFather:** @BotFather - создание и управление ботами
- **Bot API Tester:** Для тестирования API методов
- **ngrok:** Для тестирования webhook локально

### Сообщество

- **GitHub Issues:** https://github.com/telegram-bot-rb/telegram-bot/issues
- **Stack Overflow:** тег `telegram-bot`
- **Telegram Bots Group:** Сообщество разработчиков Telegram ботов

---

## Заключение

Gem `telegram-bot` предоставляет мощный и гибкий фреймворк для создания Telegram-ботов на Ruby с отличной интеграцией в Rails. Следуя best practices и используя предоставленные модули (Session, MessageContext, CallbackQueryContext), вы можете создавать сложные боты с минимальным количеством кода.

**Ключевые преимущества:**
- Rails-подобная архитектура (контроллеры, роутинг)
- Встроенная поддержка сессий
- Простое тестирование с RSpec
- Гибкая система middleware
- Типизированные ответы API

**Рекомендации для начала:**
1. Начните с простого бота с несколькими командами
2. Добавьте inline-клавиатуры для улучшения UX
3. Используйте сессии для многошаговых диалогов
4. Покройте код тестами
5. Оптимизируйте производительность с помощью кеширования и фоновых задач

Удачи в разработке ботов!
