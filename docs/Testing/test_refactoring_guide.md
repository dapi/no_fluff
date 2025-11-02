# 📚 Руководство по рефакторингу тестов NoFluff

## 🚫 Важное правило: НЕ тестировать валидации моделей

### Что НЕ нужно тестировать:
- ❌ Presence validations (username должен быть обязательным)
- ❌ Uniqueness validations (username должен быть уникальным)
- ❌ Format validations (email должен быть валидным)
- ❌ Length validations (имя не должно быть длиннее N символов)
- ❌ Numerical validations (возраст должен быть > 0)
- ❌ Inclusion validations (статус должен быть из списка)

### Почему?
Валидации - это ответственность Rails framework и используемых gem-ов. Они уже хорошо протестированы и не требуют дублирования в проектных тестах.

### Что нужно тестировать вместо этого:
- ✅ **Бизнес-логика моделей** - кастомные методы с уникальной логикой
- ✅ **Ассоциации и связи** - правильность работы связей между моделями
- ✅ **Scope и query методы** - фильтрация и сортировка данных
- ✅ **State machine переходы** - изменение состояний объектов
- ✅ **Callback логика** - before_save, after_create и т.д.
- ✅ **Интеграционные сценарии** - взаимодействие между компонентами

## 🔧 Доступные хелперы

### BaseTestHelper

Для унификации базовых тестовых паттернов:

```ruby
class MyModelTest < ActiveSupport::TestCase
  extend BaseTestHelper

  # Автоматическая генерация базовых тестов
  test_fixture_basics MyModel
  test_basic_validity MyModel, { name: 'test', value: 123 }
  test_model_associations MyModel, { has_many: [:items], belongs_to: [:category] }
  test_enum_functionality MyModel, { status: %w[active inactive] }
  test_model_scopes MyModel, [
    {
      name: :active,
      setup_data: { my_model: [...] },
      expectations: [...]
    }
  ]
end
```

### AssertionHelper

Для комплексных проверок:

```ruby
# Комплексная проверка ассоциаций
assert_associations record, {
  has_many: [:items, :comments],
  belongs_to: [:category]
}

# Проверка работы scope
assert_scope_behavior MyModel, :active, setup_data, expectations

# Проверка enum функциональности
assert_enum_functionality record, enum_definitions

# Проверка destroy зависимостей
assert_destroy_dependencies record, dependencies

# Проверка state machine переходов
assert_state_transitions record, :status, transitions
```

## 📋 Пример правильного рефакторинга

### До рефакторинга (избыточные проверки):
```ruby
test 'should have many subscriptions' do
  user = telegram_users(:one)
  assert_respond_to user, :subscriptions
end

test 'should have many channels through subscriptions' do
  user = telegram_users(:one)
  assert_respond_to user, :channels
end

test 'should have many user_digests' do
  user = telegram_users(:one)
  assert_respond_to user, :user_digests
end
```

### После рефакторинга (оптимально):
```ruby
test 'should have all required associations' do
  user = telegram_users(:one)
  assert_associations user, {
    has_many: [:subscriptions, :channels, :user_digests, :chats, :feedbacks],
    has_one: [:user_preference]
  }
end
```

### Scope тесты - объединяем позитивные и негативные:
```ruby
# Было (4 теста):
test 'premium scope should return only premium users'
test 'premium scope should not return non-premium users'

# Стало (1 тест):
test 'premium scope should filter users correctly' do
  premium_user = create_user(is_premium: true)
  regular_user = create_user(is_premium: false)

  premium_users = TelegramUser.premium
  assert_includes premium_users, premium_user
  assert_not_includes premium_users, regular_user
end
```

## 🎯 Фокус на бизнес-логике

### Пример хорошего теста бизнес-логики:
```ruby
test 'can_add_channel? should respect premium limits' do
  free_user = create_user(is_premium: false)
  premium_user = create_user(is_premium: true)

  # Создаем максимальное количество подписок для free пользователя
  (free_user.channels_limit - 1).times do
    free_user.subscriptions.create!(channel: create_channel)
  end

  assert_not free_user.can_add_channel?, "Free user at limit should not add channels"
  assert premium_user.can_add_channel?, "Premium user should always add channels"
end
```

### Пример хорошего теста scope:
```ruby
test 'needs_monitoring scope should return channels requiring monitoring' do
  recently_monitored = create_channel(monitored_at: 5.minutes.ago)
  never_monitored = create_channel(monitored_at: nil)
  long_ago_monitored = create_channel(monitored_at: 15.minutes.ago)

  channels_needing_monitoring = Channel.needs_monitoring

  assert_includes channels_needing_monitoring, never_monitored
  assert_includes channels_needing_monitoring, long_ago_monitored
  assert_not_includes channels_needing_monitoring, recently_monitored
end
```

## 🚀 Практические рекомендации

### 1. Удаляйте дублирующиеся fixture тесты:
```ruby
# ❌ Удалить
test 'should load fixture' do
  model = models(:one)
  assert_not_nil model
end

test 'loaded fixture should be valid' do
  model = models(:one)
  assert model.valid?
end
```

### 2. Объединяйте ассоциационные тесты:
```ruby
# ✅ Использовать
test 'should have all required associations' do
  record = model.first
  assert_associations record, {
    has_many: [:items],
    belongs_to: [:category]
  }
end
```

### 3. Объединяйте позитивные/негативные scope тесты:
```ruby
# ✅ Использовать
test 'scope should filter records correctly' do
  included = create_record(active: true)
  excluded = create_record(active: false)

  results = Model.active
  assert_includes results, included
  assert_not_includes results, excluded
end
```

### 4. Тестируйте только уникальную бизнес-логику:
```ruby
# ✅ Хорошо - тест бизнес-метода
test 'calculate_subscription_cost should apply premium discount' do
  premium_user = create_user(is_premium: true)
  regular_user = create_user(is_premium: false)

  premium_cost = premium_user.calculate_subscription_cost
  regular_cost = regular_user.calculate_subscription_cost

  assert premium_cost < regular_cost, "Premium users should get discount"
end
```

## 📊 Результаты правильного рефакторинга

- **Удалено избыточных проверок**: 277 → 268 (-3.2%)
- **Улучшена читаемость**: тесты сфокусированы на бизнес-логике
- **Сохранено покрытие**: функциональность протестирована
- **Ускорена разработка**: меньше шаблонного кода
- **Улучшена поддержка**: изменения вносятся в одном месте

## 🔥 Главное правило

**Тестируйте поведение, а не ограничения.**

Фокусируйтесь на том, что делает ваша уникальная бизнес-логика, а не на стандартных валидациях фреймворка.