# Sessions в Telegram Bot Ruby

## Обзор

**Sessions** - это механизм хранения состояния между запросами от одного пользователя в Telegram боте. Они позволяют сохранять данные пользователя между взаимодействиями с ботом, что необходимо для создания многошаговых диалогов и сохранения контекста.

## Как использовать сессии в этом проекте

### 1. Подключение модуля сессий

```ruby
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::Session
  # или: use_session!

  def start!(*)
    session[:visits] ||= 0
    session[:visits] += 1
    respond_with :message, text: "Вы посетили бота #{session[:visits]} раз"
  end
end
```

### 2. Настройка хранилища сессий

Для production использовать Redis:
```ruby
# config/environments/production.rb
Telegram::Bot::UpdatesController.session_store = :redis_store, {
  url: ENV['REDIS_URL'],
  expires_in: 1.month
}
```

Для development:
```ruby
# config/environments/development.rb
config.telegram_updates_controller.session_store = :memory_store
```

### 3. Основные операции сессией

```ruby
# Чтение данных
user_language = session[:language]
current_step = session[:registration_step]

# Запись данных
session[:language] = 'ru'
session[:current_channel] = channel_input
session[:registration_data] = { name: 'John', age: 25 }

# Удаление данных
session.delete(:registration_data)

# Очистка всей сессии
session.clear
```

## Практические примеры использования

### Многошаговые диалоги

```ruby
def register!(*)
  session[:registration] = {}
  session[:registration][:step] = 'ask_name'
  respond_with :message, text: 'Как вас зовут?'
end

def message(message)
  case session[:registration][:step]
  when 'ask_name'
    session[:registration][:name] = message['text']
    session[:registration][:step] = 'ask_age'
    respond_with :message, text: 'Сколько вам лет?'
  when 'ask_age'
    # сохраняем возраст и завершаем регистрацию
    complete_registration
  end
end
```

### Временное хранение данных

```ruby
def add_channel(channel_input)
  # Временно сохраняем введенный канал
  session[:pending_channel] = channel_input

  # Показываем подтверждение
  confirm_keyboard = [
    [Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Да, добавить',
      callback_data: 'confirm_add_channel'
    )],
    [Telegram::Bot::Types::InlineKeyboardButton.new(
      text: 'Отмена',
      callback_data: 'cancel_add_channel'
    )]
  ]

  respond_with :message,
    text: "Добавить канал #{channel_input}?",
    reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: confirm_keyboard)
end

def confirm_add_channel_callback_query(*)
  channel_input = session[:pending_channel]
  # Реальная логика добавления канала
  service = Telegram::ChannelService.new(bot)
  result = service.add_channel_for_user(current_user, channel_input)

  session.delete(:pending_channel) # Очищаем временные данные

  answer_callback_query('')
  edit_message :text, text: result[:message]
end
```

### Сохранение контекста меню

```ruby
def list!(*)
  session[:current_menu] = 'subscriptions'
  session[:current_page] = 0

  subscriptions = current_user.subscriptions.active.by_priority
  # ... логика отображения
end

def page_callback_query(page_num)
  return unless session[:current_menu] == 'subscriptions'

  session[:current_page] = page_num.to_i
  show_page(page_num.to_i)
end
```

## Важные особенности

- **Изоляция пользователей**: Ключ сессии строится на основе `bot.username` и ID пользователя
- **Автоматическая очистка**: Сессии истекают через указанное время
- **Типы данных**: Можно хранить строки, числа, массивы, хеши
- **Производительность**: Redis работает быстрее файлового хранилища

## Рекомендации для AI-агента

### Используйте сессии для:
- Многошаговых процессов (регистрация, добавление каналов)
- Временного хранения пользовательского ввода
- Сохранения состояния навигации по меню
- Кеширования часто используемых данных пользователя

### Не используйте сессии для:
- Постоянных данных (используйте БД)
- Больших объемов данных
- Критичной информации (только в зашифрованном виде)

### Лучшие практики:
1. **Всегда очищайте** сессию после завершения процесса
2. **Устанавливайте разумное время жизни** сессии (1 день - 1 месяц)
3. **Используйте осмысленные ключи** для данных сессии
4. **Проверяйте наличие данных** перед использованием

Этот механизм позволяет создавать сложные интерактивные сценарии в Telegram боте с сохранением состояния между сообщениями.