# Телеграм бот "Без шелухи" @bez_sheluhi_bot

Бот написан Ruby On Rails с учетом best practices и SOLID принципов.

Этот бот принимает от пользователя набор телеграм каналов, которые пользователю
интересны. Следит за ними, и выдает пользователю ТОЛЬКО важную информацию из
каналов. Без рекламы. Без шелухи.

Полный список функциональных возможностей доступен в [документации](./docs/Product/features.md).

Таким образом:

1. Пользователь получает контент без шелухи.
2. Создается социальная сеть через которую продвигаются интересные каналы на
   схожую тематику.

## Переменные окружения

Все переменные окружения имеют префикс `NO_FLUFF_`.

### Telegram Bot

| Переменная | Описание | Обязательная | Пример |
|------------|----------|--------------|--------|
| `NO_FLUFF_TELEGRAM_BOT_TOKEN` | API токен Telegram бота от [@BotFather](https://t.me/botfather) | ✅ | `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz` |
| `NO_FLUFF_TELEGRAM_BOT_USERNAME` | Username бота (без @) | ✅ | `bez_sheluhi_bot` |

### AI / LLM

| Переменная | Описание | Обязательная | Пример |
|------------|----------|--------------|--------|
| `NO_FLUFF_OPENAI_API_KEY` | API ключ OpenAI | ❌ | `sk-...` |
| `NO_FLUFF_DEEPSEEK_API_KEY` | API ключ DeepSeek | ❌* | `sk-...` |
| `NO_FLUFF_LLM_DEFAULT_MODEL` | Модель по умолчанию для LLM | ❌ | `deepseek-chat` (по умолчанию) |

*Требуется хотя бы один из AI провайдеров (OpenAI или DeepSeek)

### Background Jobs (Solid Queue)

Настройки количества процессов для разных типов очередей. Подробнее в [документации по фоновым задачам](./docs/background-jobs-queues.md).

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `REALTIME_CONCURRENCY` | Количество процессов для срочных задач (realtime очередь) | `2` |
| `DIGEST_CONCURRENCY` | Количество процессов для дайджестов (digest, default очереди) | `3` |
| `CONTENT_CONCURRENCY` | Количество процессов для обработки контента (content, channels очереди) | `2` |
| `BACKGROUND_CONCURRENCY` | Количество процессов для фоновых задач (ai, low_priority очереди) | `1` |

### Telegram Follower Users (для Spec 046)

| Переменная | Описание | Обязательная | Пример |
|------------|----------|--------------|--------|
| `TELEGRAM_API_ID` | API ID приложения от [my.telegram.org](https://my.telegram.org) | ✅ | `12345678` |
| `TELEGRAM_API_HASH` | API Hash приложения от [my.telegram.org](https://my.telegram.org) | ✅ `abcdef1234567890abcdef1234567890abcdef12345678` |
| `SESSION_ENCRYPTION_KEY` | Ключ для шифрования Telegram сессий (32 hex символа) | ✅ | `1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2` |

#### Как получить TELEGRAM_API_ID и TELEGRAM_API_HASH:

1. **Зайти на [my.telegram.org](https://my.telegram.org)**
2. **Войти с вашим Telegram аккаунтом**
3. **Создать новое приложение** (нажмите "Create new application")
4. **Выбрать тип "Bot"**
5. **Заполнить форму:**
   - App title: "NoFluff Follower User Bot"
   - Short name: `nofluff_follower`
   - Description: "Follower user for NoFluff bot channel monitoring"
6. **Получить `api_id` (цифры) и `api_hash` (символы)**
7. **Добавить в `.env.local` файл**

#### Как сгенерировать SESSION_ENCRYPTION_KEY:

```bash
# Способ 1: OpenSSL (рекомендуется)
openssl rand -hex 32
# Результат: 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2

# Способ 2: Rails консоль
rails console
irb> require 'securerandom'
irb> SecureRandom.hex(32)
# Результат: 9f8e7d6c5b4a3210fedcba9876543210fedcba9876543210
```

**Важно:** Используйте **уникальный ключ** для каждого environment (development, staging, production).

### Другое

| Переменная | Описание | Обязательная | Пример |
|------------|----------|--------------|--------|
| `DATABASE_URL` | URL подключения к PostgreSQL | ✅ | `postgresql://user:pass@localhost/nofluff` |
| `RAILS_ENV` | Окружение Rails | ❌ | `production` |

## Документация

- [Функциональность](./docs/Product/features.md)
- [Фоновые задачи и очереди](./docs/background-jobs-queues.md)
- [Дорожная карта проекта](./docs/ROADMAP.md)
