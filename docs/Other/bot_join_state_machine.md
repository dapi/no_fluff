# State Machine для управления вступлением бота в канал

## Обзор

В проекте используется gem `state_machines-activerecord` для управления процессом вступления бота в Telegram каналы. State machine обеспечивает строгий контроль над переходами между состояниями и предоставляет удобные методы для работы со статусами.

## Состояния

- **`not_joined`** - Бот еще не вступал в канал (начальное состояние)
- **`joining`** - Процесс вступления в канал выполняется
- **`joined`** - Бот успешно вступил в канал
- **`join_failed`** - Не удалось вступить в канал

## Переходы (Events)

### `start_joining`
- `not_joined` → `joining`
- `join_failed` → `joining` (повторная попытка)
- `joined` → `joining` (повторное вступление)

### `complete_join`
- `joining` → `joined`

### `fail_join`
- `joining` → `join_failed`

## Методы

### Основные методы

```ruby
# Начать процесс вступления
channel.start_joining!
# Возвращает true/false и логирует результат

# Отметить успешное вступление
channel.mark_as_joined!
# Автоматически устанавливает bot_join_at и очищает ошибки

# Отметить неудачное вступление
channel.mark_as_join_failed!("Ошибка: канал не найден")
# Сохраняет ошибку в bot_join_error

# Проверить статус
channel.not_joined?
channel.joining?
channel.joined?
channel.join_failed?

# Проверить может ли бот мониторить канал
channel.bot_can_monitor?
# true только если active? && joined?
```

### Guards (Защита от неверных переходов)

- Нельзя начать вступление в неактивный канал
- Только определенные переходы разрешены

### Callbacks

- **Перед началом вступления**: очищает предыдущие ошибки
- **После успешного вступления**: устанавливает `bot_join_at`, очищает ошибки
- **После неудачного вступления**: сохраняет сообщение об ошибке

## Примеры использования

```ruby
# Создание нового канала (автоматически в состоянии not_joined)
channel = Channel.create!(
  telegram_id: 12345,
  username: 'my_channel',
  title: 'My Channel'
)
channel.bot_join_status #=> 'not_joined'
# Не нужно вручную устанавливать bot_join_status - state machine сделает это автоматически

# Процесс вступления
if channel.start_joining!
  # Начинаем фоновую задачу для вступления
  BotJoinJob.perform_later(channel.id)
end

# В Job при успешном вступлении
def perform(channel_id)
  channel = Channel.find(channel_id)

  # Логика вступления в канал...

  if success
    channel.mark_as_joined!
  else
    channel.mark_as_join_failed!("Не удалось получить права администратора")
  end
end

# Проверка статуса
Channel.joined        # Все каналы где бот вступил
Channel.joining       # Каналы в процессе вступления
Channel.join_failed   # Каналы с ошибками
Channel.not_joined    # Новые каналы
```

## Преимущества над простым enum

1. **Типизация переходов** - запрещены невозможные переходы
2. **Автоматические callback'и** - очистка данных, логирование
3. **Guards** - защита от неверных действий
4. **История** - можно отслеживать кто и когда изменил состояние
5. **Выразительность** - код более читаемый и понятный

## Интеграция с существующим кодом

State machine полностью обратно совместим с существующим кодом:

```ruby
# Старый код продолжает работать
channel.bot_join_status #=> 'joined'
channel.bot_join_status = 'joining'
```

Но рекомендуется использовать новые методы для лучшего контроля:

```ruby
# Предпочтительный способ
channel.start_joining!
channel.mark_as_joined!
```