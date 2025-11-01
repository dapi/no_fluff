# Спецификация 046: User-based Channel Access System (Compact)

## Мета информация

- **Номер:** 046
- **Название:** Bot Channel Join Process
- **Автор:**
- **Создана:** 2025-11-02
- **Статус:** delivered
- **Связанные спецификации:**



## 🚨 Ключевое изменение архитектуры

**Проблема**: Telegram Bot API НЕ позволяет ботам самостоятельно вступать в каналы. Бот может быть добавлен только вручную администратором.

**Решение**: Multi-User Pool Access через MTProto API с пулом FollowerUser аккаунтов.

## Общее описание

Система доступа к каналам через пул follower users для масштабируемого мониторинга контента. Включает управление состоянием доступа, базовое load balancing и обработку ошибок.

## Архитектура

### 1. Multi-User Pool (3-50 аккаунтов)
- **Масштаб**: До 20000 каналов
- **Ограничения**: 500 каналов/аккаунт, 50 вступлений/день
- **Load Balancing**: Автоматическое распределение каналов

### 2. Базовые модели данных

#### Channel Model
```ruby
enum user_access_status: {
  not_joined: 0,    # Пользователь еще не вступал
  joining: 1,       # Процесс вступления
  joined: 2,        # Пользователь успешно вступил
  join_failed: 3,   # Не получилось вступить
  access_revoked: 4 # Доступ отозван
}

reference :follower_user            # Назначенный follower user
enum :assignment_status, default: :unassigned
```

#### FollowerUser Model
```ruby
string :phone_number, null: false
enum auth_status: { pending: 0, authorized: 1, restricted: 2, banned: 3 }

# Capacity и метрики
integer :max_channels, default: 400
integer :daily_joins_limit, default: 50
integer :channels_count, default: 0
decimal :workload_score, precision: 5, scale: 2, default: 0.0

# Health monitoring
decimal :health_score, precision: 5, scale: 2, default: 100.0
integer :consecutive_errors, default: 0
```

### 3. Основной процесс
```ruby
class Channels::UserJoinJob < ApplicationJob
  def perform(channel_id, follower_user_id)
    follower_user = FollowerUser.find(follower_user_id)
    return unless follower_user.authorized?

    client = TelegramUserClient.new(follower_user)
    result = client.join_channel(channel.username)

    if result.success?
      channel.update!(user_access_status: :joined)
      follower_user.increment!(:daily_joins_count)
    else
      handle_join_failure(channel, follower_user, result.error)
    end
  end
end
```

## Процесс работы

### 1. Добавление нового канала
```
1. Администратор добавляет канал
2. ChannelAssignmentService находит лучший follower user
3. Канал назначается пользователю
4. Запускается UserJoinJob
5. Follower user вступает в канал
6. Статус обновляется на joined
```

### 2. Load Balancing
```
1. Pool Manager проверяет нагрузку аккаунтов
2. При дисбалансе >30% запускается ребалансировка
3. Каналы перераспределяются между пользователями
4. Обновляются workload метрики
```

## Критерии успешности

### Функциональные требования
- [ ] Автоматическое вступление в 95% публичных каналов
- [ ] Load balancing между аккаунтами
- [ ] Надежная обработка ошибок
- [ ] Мониторинг статуса доступа

### Масштабирование
- [ ] Поддержка до 50 follower users
- [ ] Мониторинг до 20000 каналов
- [ ] Автоматическая ребалансировка
- [ ] Graceful degradation

### Безопасность
- [ ] Соблюдение Telegram rate limits
- [ ] Безопасное хранение учетных данных
- [ ] Устойчивость к блокировкам
- [ ] Автоматический failover

## Риски и митигация

### 1. Блокировка аккаунтов
- **Риск**: Блокировка одного или нескольких follower users
- **Митигация**: Распределение рисков между аккаунтами, conservative rate limits

### 2. Load Imbalance
- **Риск**: Неравномерное распределение нагрузки
- **Митигация**: Автоматическая ребалансировка, workload метрики

### 3. Отзыв доступа
- **Риск**: Администраторы могут кикнуть пользователей
- **Митигация**: Регулярная проверка доступа, автоматическое переназначение

### 4. Безопасность
- **Риск**: Компрометация учетных данных нескольких аккаунтов
- **Митигация**: Шифрование, регулярная ротация, мониторинг

## Требования к окружению

### 1. Telegram Apps
- Зарегистрированное приложение на my.telegram.org
- api_id и api_hash credentials
- Несколько валидных номеров follower users

### 2. Библиотеки
- MTProto клиент библиотека для Ruby
- Поддержка множественных сессий
- Load balancing utilities

### 3. Безопасность
- Хранилище для зашифрованных сессий
- Мониторинг безопасности пула
- Логирование всех операций

---

## Статус: draft (пересмотренная версия)

**Важное изменение**: Архитектура полностью пересмотрена с учетом ограничений Telegram API. Требуется детальная проработка multi-user approach.

**Phase 1**: Создать FollowerUser модель и базовую функциональность

**Связанные документы**:
- [052 FollowerUser Pool Management](./052_FollowerUser_Pool_Management_Specification.md) - Load balancing, health monitoring
- [053 FollowerUser Lifecycle](./053_FollowerUser_Lifecycle_Specification.md) - Авторизация, session management, security
- [054 Channel Activity System](./054_Channel_Activity_System_Specification.md) - Activity scoring, rebalancing
- [Multi-Follower User Strategy](./Architecture/multi-follower-user-strategy.md)
- [Telegram Rate Limits Analysis](./Architecture/telegram-rate-limits-analysis.md)
- [Telegram ToS Requirements](./Architecture/telegram-tos-requirements.md)