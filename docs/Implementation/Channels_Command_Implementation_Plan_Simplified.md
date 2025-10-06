# Упрощенный план реализации команды /channels

## Этап 1: Подготовка
- [x] Изучить архитектуру проекта
- [x] Создать спецификацию команды

## Этап 2: Создание тестов (Tests First)

### 2.1 Unit тесты для сервиса
- [ ] Создать `test/services/telegram/channels_list_service_test.rb`
- [ ] Написать тест для проверки прав администратора
- [ ] Написать тест для получения списка каналов
- [ ] Написать тест для сортировки каналов

### 2.2 Интеграционные тесты для контроллера
- [ ] Создать тест в `test/controllers/telegram_webhook_controller_test.rb`
- [ ] Написать тест для команды `channels!`
- [ ] Написать тест для обработки ошибки доступа

### 2.3 Фикстуры
- [ ] Создать тестовые данные в `test/fixtures/channels.yml`
- [ ] Создать тестовые данные в `test/fixtures/subscriptions.yml`

## Этап 3: Реализация сервиса

### 3.1 Создание простого сервиса
- [ ] Создать файл `app/services/telegram/channels_list_service.rb`
- [ ] Реализовать базовую структуру класса

### 3.2 Основные методы
- [ ] `execute` - основной метод выполнения
- [ ] `admin_access_allowed?` - проверка прав доступа
- [ ] `build_channels_list` - построение списка каналов
- [ ] `format_channel_line` - форматирование одной строки канала

## Этап 4: Реализация контроллера

### 4.1 Добавление команды
- [ ] Добавить метод `channels!` в `TelegramWebhookController`
- [ ] Добавить проверку прав администратора
- [ ] Создать экземпляр сервиса и вызвать его

### 4.2 Обработка ошибок
- [ ] Обработка отсутствия прав доступа
- [ ] Обработка ошибок базы данных

## Этап 5: Локализация

### 5.1 Добавление текстов в локаль
- [ ] Добавить тексты в `config/locales/ru.yml`:
  - `telegram_bot.channels.list.title`
  - `telegram_bot.channels.list.total_channels`
  - `telegram_bot.channels.list.active_channels`
  - `telegram_bot.channels.list.no_channels`
  - `telegram_bot.channels.list.access_denied`
  - `telegram_bot.channels.list.channel_format`
  - `telegram_bot.channels.list.status.active`
  - `telegram_bot.channels.list.status.inactive`
  - `telegram_bot.channels.list.verified`
  - `telegram_bot.channels.list.not_verified`
  - `telegram_bot.channels.list.last_post.never`
  - `telegram_bot.channels.list.errors.general`

## Этап 6: Тестирование

### 6.1 Запуск тестов
- [ ] Запустить все созданные тесты
- [ ] Убедиться, что все тесты проходят

## Детальная реализация

### Сервис ChannelsListService

```ruby
module Telegram
  class ChannelsListService
    attr_reader :bot, :current_user

    def initialize(bot, current_user)
      @bot = bot
      @current_user = current_user
    end

    def execute
      return access_denied_response unless admin_access_allowed?

      channels = fetch_channels_with_stats

      if channels.any?
        success_response(channels)
      else
        empty_response
      end
    end

    private

    def admin_access_allowed?
      current_user&.is_admin? || false
    end

    def fetch_channels_with_stats
      Channel.left_joins(:subscriptions)
            .select('channels.*, COUNT(subscriptions.id) as subscribers_count')
            .group('channels.id')
            .order('subscribers_count DESC')
    end

    def format_channel_line(channel)
      verification = channel.is_verified ? '✅' : '⭕'
      status = channel.active? ? '🟢' : '🔴'
      last_post = channel.last_post_at ? time_ago_in_words(channel.last_post_at) : 'Постов пока не было'

      "#{verification} @#{channel.username} — #{channel.subscribers_count} подписчиков\n#{status} #{last_post}"
    end
  end
end
```

### Метод в контроллере

```ruby
# Команда /channels
def channels!(*args)
  service = Telegram::ChannelsListService.new(bot, current_user)
  result = service.execute

  respond_with :message, text: result[:message]
end
```

## Критерии готовности

- [ ] Все тесты проходят
- [ ] Команда работает только для администраторов
- [ ] Список каналов корректно отображается
- [ ] Каналы отсортированы по количеству подписчиков
- [ ] Ошибки обрабатываются корректно
- [ ] Локализация работает
- [ ] Производительность < 2 секунд

## Упрощенная структура

1. **Без пагинации** - все каналы в одном сообщении
2. **Без кеширования** - прямые запросы к БД
3. **Минимальные тесты** - только базовые проверки
4. **Простой сервис** - 2-3 основных метода
5. **Без ручного тестирования** - только автоматические тесты