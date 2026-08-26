require 'test_helper'

class TelegramUserTest < ActiveSupport::TestCase
  # Validation tests
  test 'should be valid with valid attributes' do
    user = TelegramUser.new(
      username: 'new_user',
      timezone: 'UTC',
      language_code: 'en'
    )
    assert user.valid?
  end

  test 'should require username' do
    user = TelegramUser.new(
      timezone: 'UTC',
      language_code: 'en'
    )
    assert_not user.valid?
    assert user.errors[:username].present?
  end

  test 'should require unique username' do
    existing_user = telegram_users(:one)
    user = TelegramUser.new(
      username: existing_user.username,
      timezone: 'UTC',
      language_code: 'en'
    )
    assert_not user.valid?
    assert user.errors[:username].present?
  end

  test 'should use default timezone if not provided' do
    user = TelegramUser.new(
      username: 'new_user',
      language_code: 'en'
    )
    assert user.valid?
    assert_equal 'UTC', user.timezone
  end

  test 'should use default language_code if not provided' do
    user = TelegramUser.new(
      username: 'new_user',
      timezone: 'UTC'
    )
    assert user.valid?
    assert_equal 'ru', user.language_code
  end

  test 'binds Telegram identity to the existing username record' do
    existing = telegram_users(:one)
    user = TelegramUser.from_telegram(
      'id' => 943_084_337,
      'username' => existing.username,
      'first_name' => 'Danil',
      'language_code' => 'ru'
    )

    assert_equal existing.id, user.id
    assert_equal 943_084_337, user.telegram_id
    assert_equal 'Danil', user.first_name
  end

  # Association tests
  test 'should have all required associations' do
    user = telegram_users(:one)
    # has_many associations
    assert_respond_to user, :subscriptions
    assert_respond_to user, :channels
    assert_respond_to user, :user_digests
    assert_respond_to user, :chats
    assert_respond_to user, :feedbacks
    # has_one association
    assert_respond_to user, :user_preference
  end

  test 'should destroy associated subscriptions when destroyed' do
    user = TelegramUser.create!(
      username: 'test_user_destroy',
      timezone: 'UTC',
      language_code: 'en'
    )
    subscription = user.subscriptions.create!(
      channel: channels(:one)
    )
    assert_difference 'Subscription.count', -1 do
      user.destroy
    end
  end

  test 'should destroy associated user_digests when destroyed' do
    user = TelegramUser.create!(
      username: 'test_user_destroy2',
      timezone: 'UTC',
      language_code: 'en'
    )
    user_digest = user.user_digests.create!(
      posts_analyzed_count: 0,
      posts_included_count: 0
    )
    assert_difference 'UserDigest.count', -1 do
      user.destroy
    end
  end

  # Enum tests - оптимизированы через рефлексию
  test 'should have and work with all enum types' do
    user = telegram_users(:one)

    # Проверяем все enum типы через рефлексию
    enum_definitions = {
      delivery_frequency: %w[real_time three_times_daily twice_daily once_daily every_few_days weekly on_demand],
      content_format: %w[original summaries unified_digest combo headlines],
      filter_strictness: %w[ultra high medium low smart]
    }

    enum_definitions.each do |enum_name, enum_values|
      # Проверяем наличие самого enum
      assert_respond_to user, enum_name, "Should have #{enum_name} enum"

      # Проверяем наличие query методов для всех значений
      enum_values.each do |enum_value|
        query_method = "#{enum_name}_#{enum_value}?"
        assert_respond_to user, query_method, "Should have #{query_method} query method"
      end

      # Проверяем работу с enum значениями
      test_values = [ enum_values.first, enum_values.last ].uniq
      test_values.each do |enum_value|
        # Устанавливаем значение
        user.send("#{enum_name}=", enum_value.to_sym)

        # Проверяем query метод
        query_method = "#{enum_name}_#{enum_value}?"
        assert user.send(query_method), "Should return true for #{enum_value} in #{enum_name}"

        # Проверяем сохраненное значение
        assert_equal enum_value, user.send(enum_name), "Should store #{enum_value} in #{enum_name}"
      end
    end
  end

  # Scope tests
  test 'premium scope should filter users correctly' do
    premium_user = telegram_users(:one)
    premium_user.update(is_premium: true)

    regular_user = telegram_users(:two)
    regular_user.update(is_premium: false)

    premium_users = TelegramUser.premium
    assert_includes premium_users, premium_user
    assert_not_includes premium_users, regular_user
  end

  test 'non_bots scope should filter users correctly' do
    regular_user = telegram_users(:one)
    regular_user.update(is_bot: false)

    bot_user = telegram_users(:two)
    bot_user.update(is_bot: true)

    non_bot_users = TelegramUser.non_bots
    assert_includes non_bot_users, regular_user
    assert_not_includes non_bot_users, bot_user
  end

  test 'by_delivery_time scope should filter by delivery frequency' do
    user1 = telegram_users(:one)
    user1.update(delivery_frequency: :once_daily)

    user2 = telegram_users(:two)
    user2.update(delivery_frequency: :weekly)

    daily_users = TelegramUser.by_delivery_time(:once_daily)
    assert_includes daily_users, user1
    assert_not_includes daily_users, user2
  end

  # Edge case tests
  test 'should handle nil values for optional boolean fields' do
    user = TelegramUser.new(
      username: 'test_user',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: nil,
      is_bot: nil
    )
    assert user.valid?
  end

  test 'should handle different timezone formats' do
    user = TelegramUser.new(
      username: 'test_user',
      timezone: 'America/New_York',
      language_code: 'en'
    )
    assert user.valid?
  end

  test 'should handle different language codes' do
    user = TelegramUser.new(
      username: 'test_user',
      timezone: 'UTC',
      language_code: 'ru'
    )
    assert user.valid?
  end

  test 'should allow username with special characters' do
    user = TelegramUser.new(
      username: 'test_user_123',
      timezone: 'UTC',
      language_code: 'en'
    )
    assert user.valid?
  end


  # Session data integration tests (базовые проверки интеграции с Sessionable)
  test 'should include Sessionable concern' do
    user = TelegramUser.new(
      username: 'test_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    assert user.respond_to?(:get_session)
    assert user.respond_to?(:set_session)
    assert user.respond_to?(:delete_session)
    assert user.respond_to?(:clear_session!)
    assert TelegramUser.supports_sessions?
  end

  test 'should work with session through concern' do
    user = TelegramUser.create!(
      username: 'session_integration_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Проверяем базовую функциональность через concern
    assert user.set_session('test_key', 'test_value')
    user.reload
    assert_equal 'test_value', user.get_session('test_key')

    assert user.session_has_key?('test_key')
    assert_equal 1, user.session_size
    assert_not user.session_empty?

    assert user.delete_session('test_key')
    user.reload
    assert_nil user.get_session('test_key')
    assert user.session_empty?
  end

  test 'should support multiple session operations' do
    user = TelegramUser.create!(
      username: 'multi_session_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Проверяем массовые операции
    result = user.set_session_data({
      'name' => 'John',
      'age' => 30,
      'preferences' => { theme: 'dark' }
    })
    assert result

    user.reload
    assert_equal 'John', user.get_session('name')
    assert_equal 30, user.get_session('age')
    assert_equal({ 'theme' => 'dark' }, user.get_session('preferences'))

    # Проверяем работу с ключами
    keys = user.session_keys
    assert_includes keys, 'name'
    assert_includes keys, 'age'
    assert_includes keys, 'preferences'

    # Проверяем копию данных
    copy = user.session_data_copy
    copy['new_key'] = 'new_value'
    assert_not user.session_has_key?('new_key')
  end
end
