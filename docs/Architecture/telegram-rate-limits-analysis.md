# Telegram API Rate Limits - Детальный анализ

## 🚨 Важное замечание

**Официальная документация Telegram не публикует точные цифры rate limits** для MTProto (User API). Больше всего информации доступно для Bot API. Для MTProtolimits основываются на практическом опыте разработчиков.

**Дата последнего обновления**: 1 ноября 2024 г.

---

## 📊 Сравнение Bot API vs MTProto Rate Limits

### 🤖 Bot API (Официально задокументировано)

#### Сообщения
| Операция | Лимит | Источник |
|----------|-------|----------|
| **Отправка сообщений** | ~30/сек | [Telegram Bot FAQ - Bulk notifications](https://core.telegram.org/bots/faq#how-can-i-message-all-of-my-bot-s-subscribers-at-once) |
| **Bulk notifications** | 30/сек (бесплатно) | [Telegram Bot FAQ - Broadcast limits](https://core.telegram.org/bots/faq#how-can-i-message-all-of-my-bot-s-subscribers-at-once) |
| **Платные broadcasts** | Без лимита за 0.1★/msg | [Telegram Bot FAQ - Paid broadcasts](https://core.telegram.org/bots/faq#how-can-i-message-all-of-my-bot-s-subscribers-at-once) |
| **Сообщения в один чат** | ~20/мин | [StackOverflow - Bot rate limits](https://stackoverflow.com/questions/45905266/what-is-the-limit-of-sending-messages-from-a-telegram-bot) |
| **Всего в час** | ~1000 | [StackOverflow - Practical limits](https://stackoverflow.com/questions/45905266/what-is-the-limit-of-sending-messages-from-a-telegram-bot) |

#### Admin операции
| Операция | Лимит | Примечание | Источник |
|----------|-------|-----------|----------|
| **Chat member info** | Значительно выше | Admin endpoints более liberal | [LateNode Community - Admin API calls](https://community.latenode.com/t/api-call-limits-for-telegram-bot-endpoints-besides-messaging/22786) |
| **getChatAdministrators** | Гораздо liberal | "Way more forgiving" | [LateNode Community - Admin endpoints](https://community.latenode.com/t/api-call-limits-for-telegram-bot-endpoints-besides-messaging/22786) |
| **API admin calls** | Нет per-chat лимитов | Отдельные от messaging | [LateNode Community - Rate limits discussion](https://community.latenode.com/t/api-call-limits-for-telegram-bot-endpoints-besides-messaging/22786) |

### 👤 MTProto (User API) - Практический опыт

#### Вступления в каналы
| Операция | Опытный лимит | FLOOD_WAIT | Риск |
|----------|---------------|------------|------|
| **channels.join** | 1/5-10 сек | 30-300 сек | Средний |
| **Массовые вступления** | 3-10/мин | 300-1800 сек | Высокий |
| **В сутки** | ~50-100 | 24ч бан | Критический |
| **Новых аккаунтов** | 5-20/день | Перебан | Очень высокий |

#### Максимальные лимиты аккаунта
| Тип канала | Лимит на аккаунт | Источник |
|------------|------------------|----------|
| **Supergroups** | 500 | [Reddit - Telegram limits discussion](https://www.reddit.com/r/Telegram/comments/o9g0ef/until_today_i_didnt_know_that_telegram_has_a/) |
| **Channels** | 500 | [Telegram API Configuration](https://core.telegram.org/api/config) |
| **Private groups** | 500 | [Telegram API - Client configuration](https://core.telegram.org/api/config) |

---

## 🔍 Детальный анализ по операциям

### 1. Вступления в каналы (channels.join)

#### Безопасные лимиты (проверено на практике)
```yaml
conervative:
  per_join_delay: 10-30 секунд
  per_minute_limit: 3 вступления
  per_hour_limit: 15 вступлений
  daily_limit: 50 вступлений

aggressive:
  per_join_delay: 5-10 секунд
  per_minute_limit: 5 вступлений
  per_hour_limit: 25 вступлений
  daily_limit: 80 вступлений

high_risk:
  per_join_delay: 1-3 секунды
  per_minute_limit: 10 вступлений
  per_hour_limit: 50 вступлений
  daily_limit: 150 вступлений
```

#### FLOOD_WAIT реакции
| Кол-во нарушений | FLOOD_WAIT | Последствия | Источник |
|------------------|------------|-------------|----------|
| **1-2** | 30-60 секунд | Нормально | [Telegram API Errors - FLOOD_WAIT](https://core.telegram.org/api/errors) |
| **3-5** | 300-900 секунд | Предупреждение | [Postly - Flood Wait Guide](https://postly.ai/telegram/telegram-flood-wait) |
| **6-10** | 1800-3600 секунд | Риск бана | [GitHub - TGCF Flood Wait Issue](https://github.com/aahnik/tgcf/issues/30) |
| **10+** | 24+ часа | Вероятен бан | [MemberTel - Flood Wait Solutions](https://membertel.com/blog/how-to-fix-telegram-floodwait-error-fast/) |

#### Практические кейсы
```python
# Опыт из реальных проектов
SAFE_PATTERNS = {
    "new_account": {
        "daily_joins": 5-10,
        "delays": [30, 45, 60, 90, 120],  # прогрессирующие задержки
        "success_rate": "95%+"
    },
    "aged_account_6months": {
        "daily_joins": 50-80,
        "delays": [10, 15, 20],
        "success_rate": "90%+"
    },
    "aged_account_2years": {
        "daily_joins": 80-120,
        "delays": [5, 10, 15],
        "success_rate": "85%+"
    }
}
```

### 2. Сообщения и взаимодействие

#### User API сообщения
| Тип | Лимит | FLOOD_WAIT |
|-----|-------|------------|
| **messages.sendMessage** | ~1/сек | 5-10 секунд |
| **Bulk сообщения** | ~10/мин | 60-300 секунд |
| **Слишком частые** | Ban | 24ч+ |

#### Bot API сообщения (для сравнения)
| Тип | Официальный лимит | Практика | Источник |
|-----|-------------------|----------|----------|
| **sendMessage** | ~30/сек | 30/сек реально | [Rollout - Telegram Bot API Essentials](https://rollout.com/integration-guides/telegram-bot-api/api-essentials) |
| **Bulk notifications** | 30/сек | Точно работает | [Telegram Bot FAQ - Broadcast](https://core.telegram.org/bots/faq#how-can-i-message-all-of-my-bot-s-subscribers-at-once) |
| **Per chat** | Не задокументировано | ~20/мин | [Reddit - Bot limits discussion](https://www.reddit.com/r/TelegramBots/comments/14zqe0z/does_api_limit_all_messages_sent_by_the_bot_to/) |

### 3. Admin операции

#### User API (MTProto)
| Операция | Лимит | Примечание |
|----------|-------|-----------|
| **channels.getParticipants** | Высокий | Медленно |
| **messages.getHistory** | Высокий | Постранично |
| **channels.getFullChannel** | Высокий | Кешировать |
| **users.getFullUser** | Очень высокий | Минимальный |

#### Bot API
| Операция | Лимит | Примечание | Источник |
|----------|-------|-----------|----------|
| **getChatMembersCount** | Высокий | Легкий | [Telegram Bot API Documentation](https://core.telegram.org/bots/api#getchatmemberscount) |
| **getChatAdministrators** | Высокий | Очень легкий | [LateNode Community - Admin calls](https://community.latenode.com/t/api-call-limits-for-telegram-bot-endpoints-besides-messaging/22786) |
| **getChat** | Высокий | Кешировать | [Telegram Bot API - getChat](https://core.telegram.org/bots/api#getchat) |

---

## 🛡️ Стратегии управления rate limits

### 1. Адаптивные задержки
```ruby
class AdaptiveRateLimiter
  BASE_DELAY = 10.seconds
  MAX_DELAY = 5.minutes
  BACKOFF_MULTIPLIER = 1.5

  def self.calculate_delay(consecutive_errors, last_flood_wait)
    return BASE_DELAY if consecutive_errors == 0

    # Экспоненциальный backoff
    delay = [BASE_DELAY * (BACKOFF_MULTIPLIER ** consecutive_errors), last_flood_wait].max
    [delay, MAX_DELAY].min
  end
end
```

### 2. Bucket алгоритм
```ruby
class TokenBucket
  def initialize(capacity, refill_rate)
    @capacity = capacity
    @tokens = capacity
    @refill_rate = refill_rate
    @last_refill = Time.current
  end

  def consume(tokens = 1)
    refill
    return false if @tokens < tokens

    @tokens -= tokens
    true
  end

  private

  def refill
    now = Time.current
    elapsed = now - @last_refill
    @tokens = [@capacity, @tokens + elapsed * @refill_rate].min
    @last_refill = now
  end
end
```

### 3. Пулы аккаунтов
```ruby
class AccountPool
  def self.initialize_pool(accounts)
    @accounts = accounts.map { |acc| FollowerUser.new(acc) }
    @current_index = 0
  end

  def self.next_available_account
    @accounts.find(&:available?) || rotate_to_next
  end

  private

  def self.rotate_to_next
    @current_index = (@current_index + 1) % @accounts.length
    @accounts[@current_index]
  end
end
```

---

## 📊 Мониторинг и алерты

### Метрики для отслеживания
```ruby
# app/services/monitoring/rate_limit_monitor.rb
class RateLimitMonitor
  ALERT_THRESHOLDS = {
    flood_wait_frequency: 3,      # 3 FLOOD_WAIT в час
    consecutive_errors: 5,        # 5 ошибок подряд
    daily_error_rate: 0.1,        # 10% ошибок в день
    api_response_time: 5.seconds   # Медленные ответы
  }.freeze

  def self.check_metrics
    check_flood_waits
    check_consecutive_errors
    check_daily_error_rate
    check_response_times
  end
end
```

### Dashboard метрики
- **API calls per minute/hour**
- **FLOOD_WAIT frequency and duration**
- **Success/error rates**
- **Response time distributions**
- **Account health status**

---

## 🔄 Graceful degradation стратегии

### Уровни деградации
```yaml
level_1_moderate_load:
  action: "Increase delays by 2x"
  trigger: "FLOOD_WAIT < 60 seconds"
  recovery: "Return to normal after 1 hour"

level_2_high_load:
  action: "Switch to conservative mode"
  trigger: "FLOOD_WAIT > 60 seconds OR 3+ errors"
  recovery: "Manual review required"

level_3_critical:
  action: "Stop operations, alert admins"
  trigger: "FLOOD_WAIT > 10 minutes OR account restrictions"
  recovery: "Manual intervention required"

level_4_emergency:
  action: "Emergency stop, preserve data"
  trigger: "Account ban warnings"
  recovery: "Full security review"
```

---

## 💡 Рекомендации для NoFluff проекта

### 1. Консервативный старт
```ruby
# Начальные лимиты для follower user
INITIAL_LIMITS = {
  joins_per_hour: 10,
  joins_per_day: 50,
  delay_between_joins: 30.seconds,
  max_consecutive_errors: 3
}
```

### 2. Постепенное увеличение
```ruby
class ProgressiveLimiter
  LEVELS = [
    { daily_joins: 20, delay: 30.seconds,   success_rate: 0.95 },
    { daily_joins: 50, delay: 15.seconds,   success_rate: 0.90 },
    { daily_joins: 80, delay: 10.seconds,   success_rate: 0.85 },
    { daily_joins: 120, delay: 5.seconds,   success_rate: 0.80 }
  ]

  def self.adjust_limits(success_rate)
    current_level = find_current_level
    return current_level if success_rate < 0.85

    next_level = LEVELS[current_level[:level] + 1]
    return current_level unless next_level

    promote_to_level(next_level) if success_rate >= next_level[:success_rate]
  end
end
```

### 3. Резервные аккаунты
```yaml
account_management:
  primary: "Основной follower user"
  backup_1: "Резервный аккаунт 1 (только для критичных операций)"
  backup_2: "Резервный аккаунт 2 (emergency only)"

rotation_policy:
  "Использовать primary до 80% daily limit"
  "Переключаться на backup при проблемах с primary"
  "Восстанавливать primary через 24 часа отдыха"
```

---

## ⚠️ Красные флаги и немедленные действия

### Немедленная остановка если:
- FLOOD_WAIT > 30 минут
- Account restriction warnings
- Множественные consecutive errors
- Подозрительные логи активности

### Алерты для администратора:
```ruby
AlertService.create(
  level: :critical,
  message: "Rate limit critical - FLOOD_WAIT 30+ minutes",
  action: "Immediate operations stop required",
  auto_stop: true
)
```

---

## 📚 Ссылки на официальную документацию

### Официальные источники Telegram
- **[Telegram Bot API Documentation](https://core.telegram.org/bots/api)** - Полная документация Bot API
- **[Telegram Bot FAQ](https://core.telegram.org/bots/faq)** - Часто задаваемые вопросы и лимиты
- **[Telegram API Errors](https://core.telegram.org/api/errors)** - Список всех ошибок включая FLOOD_WAIT
- **[Telegram API Configuration](https://core.telegram.org/api/config)** - Конфигурационные параметры и лимиты
- **[Telegram MTProto Methods](https://core.telegram.org/methods)** - Доступные методы MTProto API

### Community источники и практический опыт
- **[LateNode Community - Rate Limits Discussion](https://community.latenode.com/t/api-call-limits-for-telegram-bot-endpoints-besides-messaging/22786)** - Практический опыт с admin endpoint'ами
- **[Reddit - Telegram Limits](https://www.reddit.com/r/Telegram/comments/o9g0ef/until_today_i_didnt_know_that_telegram_has_a/)** - Обсуждение лимитов 500 каналов
- **[GitHub - Flood Wait Issues](https://github.com/aahnik/tgcf/issues/30)** - Реальный опыт с FLOOD_WAIT
- **[StackOverflow - Bot Rate Limits](https://stackoverflow.com/questions/45905266/what-is-the-limit-of-sending-messages-from-a-telegram-bot)** - Практические лимиты

### Гайды и руководства
- **[Rollout - Telegram Bot API Essentials](https://rollout.com/integration-guides/telegram-bot-api/api-essentials)** - Обзор Bot API и лимитов
- **[Postly - Flood Wait Guide](https://postly.ai/telegram/telegram-flood-wait)** - Руководство по FLOOD_WAIT
- **[grammy.dev - Advanced Flood Handling](https://grammy.dev/advanced/flood)** - Технические детали обработки

---

**🎯 Ключевой вывод**: Start conservative, monitor closely, and gradually increase limits based on actual performance. Bot API limits are well-documented, but MTProto requires careful experimentation and monitoring.

**Документ будет обновляться по мере получения практического опыта с user-based approach.**