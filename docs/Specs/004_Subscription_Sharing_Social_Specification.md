# Спецификация: Социальное деление подписками (Social Subscription Sharing)

## Обзор
Расширенная социальная система для обмена подписками с элементами комьюнити, рейтингами и персонализированными рекомендациями.

## Цель
Создать социальную платформу внутри бота для обмена качественным контентом, построения комьюнити и повышения удержания пользователей.

## Основные сценарии использования

### 1. Публичные коллекции каналов
**Действие:** Пользователь создает публичную коллекцию каналов по теме

**Flow:**
1. Пользователь создает коллекцию "AI & Machine Learning"
2. Добавляет 15 каналов по теме с описаниями
3. Публикует коллекцию в общем каталоге
4. Другие пользователи могут найти, оценить и подписаться

### 2. Социальные рекомендации
**Действие:** Пользователи рекомендуют каналы друзьям

**Flow:**
1. Пользователь А видит интересный канал
2. Нажимает "Рекомендовать другу"
3. Выбирает друга из списка подписчиков
4. Друг получает персональную рекомендацию
5. Может подписаться одним кликом

### 3. Тематические сообщества
**Действие:** Объединение пользователей по интересам

**Flow:**
1. Пользователи с похожими подписками автоматически группируются
2. Могут обмениваться лучшими каналами внутри группы
3. Создаются топы каналов по темам
4. Появляются лидеры мнений в каждой теме

## Модели данных

### ChannelCollection (новая модель)
```ruby
class ChannelCollection < ApplicationRecord
  belongs_to :telegram_user

  has_many :collection_channels, dependent: :destroy
  has_many :channels, through: :collection_channels
  has_many :collection_subscriptions, dependent: :destroy
  has_many :subscribers, through: :collection_subscriptions, source: :telegram_user

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :category, presence: true

  enum :visibility, { private: 0, public: 1, featured: 2 }
  enum :status, { draft: 0, published: 1, archived: 2 }

  scope :public_visible, -> { where(visibility: [:public, :featured], status: :published) }
  scope :by_category, ->(category) { where(category: category) }
  scope :popular, -> { order(subscribers_count: :desc, created_at: :desc) }
end
```

### CollectionChannel (новая модель)
```ruby
class CollectionChannel < ApplicationRecord
  belongs_to :channel_collection
  belongs_to :channel

  validates :channel_id, uniqueness: { scope: :channel_collection_id }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  acts_as_list scope: :channel_collection
end
```

### CollectionSubscription (новая модель)
```ruby
class CollectionSubscription < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :channel_collection

  validates :telegram_user_id, uniqueness: { scope: :channel_collection_id }
end
```

### ChannelRecommendation (новая модель)
```ruby
class ChannelRecommendation < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :channel
  belongs_to :recommended_to_user, class_name: 'TelegramUser'

  validates :telegram_user_id, uniqueness: { scope: [:channel_id, :recommended_to_user_id] }

  enum :status, { pending: 0, accepted: 1, declined: 2, expired: 3 }
end
```

### UserCommunity (новая модель)
```ruby
class UserCommunity < ApplicationRecord
  belongs_to :telegram_user

  has_many :community_memberships, dependent: :destroy
  has_many :members, through: :community_memberships, source: :telegram_user

  validates :name, presence: true, uniqueness: true
  validates :category, presence: true

  scope :by_category, ->(category) { where(category: category) }
  scope :active, -> { where('member_count > ?', 5) }
end
```

## Telegram интерфейс

### Новые команды
- `/collections` - каталог коллекций каналов
- `/create_collection` - создать свою коллекцию
- `/my_collections` - мои коллекции
- `/recommend` - рекомендовать канал
- `/communities` - тематические сообщества
- `/trending` - трендовые каналы и коллекции

### Интерфейсы

#### 1. Каталог коллекций
```
📚 Каталог коллекций

Категории:
[🤖 AI & ML] [💻 DevOps] [📱 Mobile] [🎨 Design]

🔥 Популярные сегодня:

1. "AI News Daily" от @john_dev
   📊 234 подписчика • ⭐ 4.8/5
   [Посмотреть] [Подписаться]

2. "Ruby on Rails Gems" от @rails_guru
   📊 156 подписчиков • ⭐ 4.9/5
   [Посмотреть] [Подписаться]
```

#### 2. Создание коллекции
```
📝 Создание коллекции

Название: [AI & Machine Learning Weekly]
Описание: [Лучшие каналы про AI и ML за неделю]
Категория: [🤖 Technology]

Добавь каналы (максимум 30):
[+] @openai - Official OpenAI
[+] @ai_news - AI News Digest
[+] @ml_community - ML Community

[Опубликовать] [Сохранить как черновик]
```

#### 3. Социальные рекомендации
```
👥 Рекомендации от друзей

@alex_dev рекомендует тебе:
"Только что нашел отличный канал про Rust!"

🔗 @rust_daily - Daily Rust News
📊 5.2K подписчиков
📝 Ежедневные новости и туториалы по Rust

[Подписаться] [Посмотреть канал] [Спасибо!]
```

#### 4. Тематические сообщества
```
🏘️ Твои сообщества

💻 Ruby Developers (23 чел.)
   Новые каналы: @ruby_weekly, @rails_tips
   [Войти в сообщество]

🤖 AI Enthusiasts (45 чел.)
   Активные участники: @ai_expert, @ml_guru
   [Войти в сообщество]
```

## Business правила

### Ограничения и модерация
1. Максимум каналов в коллекции: 30
2. Максимум публичных коллекций на пользователя: 5
3. Рекомендации только между взаимными подписчиками
4. Автомодерация описаний коллекций
5. Возможность пожаловаться на некачественный контент

### Система рейтингов
1. Оценка коллекций: 1-5 звезд
2. Рейтинг пользователей-авторов
3. Тренды на основе активности подписок
4. Бонусы для популярных авторов

### Алгоритмы рекомендаций
1. Коллаборативная фильтрация на основе подписок
2. Контент-based рекомендации по темам каналов
3. Социальный граф рекомендаций
4. Персонализация на основе истории

## Монетизация (Premium функции)

### Premium коллекции
- Создание приватных коллекций для платной подписки
- Аналитика по просмотрам и подпискам
- Продвижение коллекций в каталоге

### Advanced аналитика
- Детальная статистика по каналам
- Predictive аналитика трендов
- Экспорт данных

## Метрики успеха

### Engagement метрики
- DAU/MAU ratio: >40%
- Среднее время сессии: >5 минут
- Количество созданных коллекций: 1000+/месяц
- Конверсия в подписки через коллекции: 25%+

### Социальные метрики
- Viral coefficient: >0.3
- Среднее количество рекомендаций на пользователя: 3+/месяц
- Процент пользователей в сообществах: 60%+

### Контентные метрики
- Количество уникальных каналов в коллекциях: 5000+
- Среднее качество коллекций (оценка): >4.0/5
- Процент удаленного некачественного контента: <5%

## KPI
1. **Community Engagement** - активность в сообществах
2. **Content Quality Score** - средняя оценка коллекций
3. **Social Sharing Rate** - количество рекомендаций на пользователя
4. **Discovery Efficiency** - как быстро пользователи находят релевантный контент

## Фазы внедрения

### Phase 1 (MVP)
- Базовые коллекции
- Простой каталог
- Базовые рекомендации

### Phase 2 (Social)
- Социальные рекомендации
- Рейтинги и отзывы
- Тематические сообщества

### Phase 3 (Advanced)
- Премиум функции
- Продвинутая аналитика
- API для внешних интеграций