# План миграции с tdlib-ruby на telegram-mtproto-ruby

## 📋 Обзор

**Текущая ситуация:**
- `tdlib-ruby` отключен из-за конфликтов зависимостей (FFI 1.15.0 vs 1.17.2, concurrent-ruby ~> 1.1 vs 1.3.5)
- Используется моковая реализация с заглушкой `phone_code_hash`
- Нет реальной интеграции с Telegram API

**Цель миграции:**
- Заменить `tdlib-ruby` на `telegram-mtproto-ruby`
- Получить рабочую интеграцию с Telegram MTProto 2.0
- Устранить проблемы с зависимостями

## 🎯 Преимущества telegram-mtproto-ruby

- ✅ **Pure Ruby** - нет бинарных зависимостей
- ✅ **Нет конфликтов** - не зависит от FFI, concurrent-ruby
- ✅ **MTProto 2.0** - полная реализация протокола
- ✅ **Активная поддержка** - обновлен 30.08.2025
- ✅ **Все необходимые методы**: auth.sendCode, auth.signIn, messages.sendMessage

## 📊 Анализ текущей архитектуры

### Затронутые файлы:
1. `Gemfile` - добавление нового gem
2. `app/services/telegram/user_client.rb` - основная реализация
3. `app/services/telegram/authorization_service.rb` - авторизация
4. `app/models/concerns/telegram_credentials.rb` - управление сессиями
5. `test/services/telegram/authorization_service_test.rb` - тесты

### Текущие заглушки:
- `"mock_phone_code_hash_#{follower_user.id}"`
- Код верификации: `'12345'`
- Моковая сессия: `"mock_session_string_#{follower_user.id}"`

## 🚀 План миграции

### Этап 1: Подготовка зависимостей
1. **Обновить Gemfile:**
   ```ruby
   # gem 'tdlib-ruby'  # оставить закомментированным
   gem 'telegram-mtproto-ruby', '~> 0.1.0'
   ```

2. **Установить gem:**
   ```bash
   bundle install
   ```

### Этап 2: Адаптация TelegramUserClient
**Заменить моки на реальную реализацию:**

```ruby
# Было (мок):
def create_client
  mock_client = Object.new
  mock_client.define_singleton_method(:connected?) { true }
  mock_client.define_singleton_method(:authorized?) { @follower_user.authorized? }
  @client = mock_client
end

# Станет (реальный MTProto):
def create_client
  @client = TelegramMtproto::Client.new(
    api_id: @api_credentials[:api_id],
    api_hash: @api_credentials[:api_hash],
    phone_number: @follower_user.phone_number,
    session_string: @follower_user.session_string
  )
end
```

### Этап 3: Обновление AuthorizationService
**Заменить заглушки на реальные вызовы:**

```ruby
# Было (заглушка):
def start_authorization(follower_user)
  {
    phone_code_hash: "mock_phone_code_hash_#{follower_user.id}",
    expires_at: authorization.expires_at
  }
end

# Станет (реальный вызов):
def start_authorization(follower_user)
  client = Telegram::UserClient.new(follower_user)
  client.connect

  result = client.send_code
  {
    phone_code_hash: result[:phone_code_hash],  # реальный hash
    expires_at: 10.minutes.from_now
  }
end
```

### Этап 4: Управление сессиями
**Обновить TelegramCredentials:**

```ruby
# Было (мок):
def create_tdlib_session
  Rails.logger.info "Creating TDLib session..."
  nil
end

# Станет (реальная сессия):
def create_tdlib_session
  return nil unless telegram_api_configured?

  session_data = {
    api_id: api_credentials[:api_id],
    api_hash: api_credentials[:api_hash],
    phone_number: phone_number,
    created_at: Time.current
  }

  self.session_string = session_data.to_json
  session_data
end
```

### Этап 5: Тестирование
1. **Написать интеграционные тесты**
2. **Протестировать авторизацию**
3. **Проверить подключение к реальному Telegram API**
4. **Валидировать обработку ошибок**

### Этап 6: Обновление документации
1. Обновить `docs/Architecture/tdlib-ruby-implementation.md`
2. Создать новую документацию для MTProto 2.0
3. Обновить C4 модель архитектуры

## 🔧 Технические детали

### API совместимость
| Метод | tdlib-ruby | telegram-mtproto-ruby | Статус |
|-------|------------|----------------------|--------|
| Авторизация | `client.authorize` | `client.sign_in` | ✅ Требует адаптации |
| Отправка кода | `client.send_code` | `client.send_code` | ✅ Совместим |
| Присоединение к каналу | `client.join_channel` | `client.join_chat` | ⚠️ Требует адаптации |
| Отправка сообщения | `client.send_message` | `client.send_message` | ✅ Совместим |

### Управление ошибками
**Текущая обработка ошибок:**
- FLOOD_WAIT, CHANNEL_PRIVATE, USERNAME_NOT_OCCUPIED

**Новые типы ошибок MTProto:**
- `PHONE_CODE_INVALID`
- `PHONE_NUMBER_INVALID`
- `SESSION_PASSWORD_NEEDED`

### Безопасность
- Шифрование AES-IGE уже встроено в telegram-mtproto-ruby
- Session strings хранятся в encrypted полях
- API credentials в ApplicationConfig

## ⚠️ Риски и митигация

### Риски:
1. **Нестабильность gem** - новый проект, мало тестов
2. **Отличие в API** - методы могут отличаться от tdlib-ruby
3. **Ограниченная функциональность** - может не поддерживать все TDLib фичи

### Митигация:
1. **Поэтапное тестирование** - сначала на dev окружении
2. **Fallback на моки** - оставить возможность отката
3. **Мониторинг ошибок** - расширенное логирование

## 📈 Ожидаемые результаты

### Сразу после миграции:
- ✅ Реальная авторизация Telegram пользователей
- ✅ Настоящие phone_code_hash значения
- ✅ Работающий MTProto 2.0 протокол
- ✅ Отсутствие конфликтов зависимостей

### Долгосрочные преимущества:
- 🚀 Ускорение разработки (не нужны моки)
- 🔧 Упрощение поддержки (pure Ruby)
- 📈 Расширение функциональности (полный MTProto)
- 🛡️ Повышение надежности (официальный протокол)

## 🗓️ Сроки реализации

- **Этап 1-2**: 1 день (подготовка и базовая реализация)
- **Этап 3-4**: 2 дня (авторизация и сессии)
- **Этап 5**: 2 дня (тестирование)
- **Этап 6**: 1 день (документация)

**Итого:** ~6 рабочих дней

## ✅ Критерии успеха

1. ✅ Bundle install проходит без ошибок
2. ✅ Успешная авторизация тестового пользователя
3. ✅ Получение реального phone_code_hash
4. ✅ Отправка тестового сообщения
5. ✅ Все тесты проходят
6. ✅ Документация обновлена

## 🔄 План отката

Если возникнут проблемы:
1. Откатить изменения в Gemfile
2. Восстановить моковую реализацию
3. Оставить tdlib-ruby закомментированным
4. Создать issue для отслеживания проблем