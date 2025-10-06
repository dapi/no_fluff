require 'test_helper'

class TelegramUserTest < ActiveSupport::TestCase
  # Fixture tests
  test 'should load fixture' do
    telegram_user = telegram_users(:one)
    assert_not_nil telegram_user
  end

  test 'loaded fixture should be valid' do
    telegram_user = telegram_users(:one)
    assert telegram_user.valid?
  end

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

  # Association tests
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

  test 'should have many chats' do
    user = telegram_users(:one)
    assert_respond_to user, :chats
  end

  test 'should have many feedbacks' do
    user = telegram_users(:one)
    assert_respond_to user, :feedbacks
  end

  test 'should have one user_preference' do
    user = telegram_users(:one)
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

  # Enum tests
  test 'should have delivery_frequency enum' do
    user = telegram_users(:one)
    assert_respond_to user, :delivery_frequency
    assert_respond_to user, :delivery_frequency_real_time?
    assert_respond_to user, :delivery_frequency_three_times_daily?
    assert_respond_to user, :delivery_frequency_twice_daily?
    assert_respond_to user, :delivery_frequency_once_daily?
    assert_respond_to user, :delivery_frequency_every_few_days?
    assert_respond_to user, :delivery_frequency_weekly?
    assert_respond_to user, :delivery_frequency_on_demand?
  end

  test 'should set delivery_frequency enum values' do
    user = telegram_users(:one)

    user.delivery_frequency = :real_time
    assert user.delivery_frequency_real_time?
    assert_equal 'real_time', user.delivery_frequency

    user.delivery_frequency = :three_times_daily
    assert user.delivery_frequency_three_times_daily?
    assert_equal 'three_times_daily', user.delivery_frequency

    user.delivery_frequency = :weekly
    assert user.delivery_frequency_weekly?
    assert_equal 'weekly', user.delivery_frequency
  end

  test 'should have content_format enum' do
    user = telegram_users(:one)
    assert_respond_to user, :content_format
    assert_respond_to user, :content_format_original?
    assert_respond_to user, :content_format_summaries?
    assert_respond_to user, :content_format_unified_digest?
    assert_respond_to user, :content_format_combo?
    assert_respond_to user, :content_format_headlines?
  end

  test 'should set content_format enum values' do
    user = telegram_users(:one)

    user.content_format = :original
    assert user.content_format_original?
    assert_equal 'original', user.content_format

    user.content_format = :summaries
    assert user.content_format_summaries?
    assert_equal 'summaries', user.content_format

    user.content_format = :headlines
    assert user.content_format_headlines?
    assert_equal 'headlines', user.content_format
  end

  test 'should have filter_strictness enum' do
    user = telegram_users(:one)
    assert_respond_to user, :filter_strictness
    assert_respond_to user, :filter_strictness_ultra?
    assert_respond_to user, :filter_strictness_high?
    assert_respond_to user, :filter_strictness_medium?
    assert_respond_to user, :filter_strictness_low?
    assert_respond_to user, :filter_strictness_smart?
  end

  test 'should set filter_strictness enum values' do
    user = telegram_users(:one)

    user.filter_strictness = :ultra
    assert user.filter_strictness_ultra?
    assert_equal 'ultra', user.filter_strictness

    user.filter_strictness = :medium
    assert user.filter_strictness_medium?
    assert_equal 'medium', user.filter_strictness

    user.filter_strictness = :smart
    assert user.filter_strictness_smart?
    assert_equal 'smart', user.filter_strictness
  end

  # Scope tests
  test 'premium scope should return only premium users' do
    user = telegram_users(:one)
    user.update(is_premium: true)

    premium_users = TelegramUser.premium
    assert_includes premium_users, user
  end

  test 'premium scope should not return non-premium users' do
    user = telegram_users(:one)
    user.update(is_premium: false)

    premium_users = TelegramUser.premium
    assert_not_includes premium_users, user
  end

  test 'non_bots scope should return only non-bot users' do
    user = telegram_users(:one)
    user.update(is_bot: false)

    non_bot_users = TelegramUser.non_bots
    assert_includes non_bot_users, user
  end

  test 'non_bots scope should not return bot users' do
    user = telegram_users(:one)
    user.update(is_bot: true)

    non_bot_users = TelegramUser.non_bots
    assert_not_includes non_bot_users, user
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

  # Tests for is_admin functionality
  test 'should have is_admin field with default false' do
    user = TelegramUser.create!(
      username: 'test_admin',
      timezone: 'UTC',
      language_code: 'en'
    )
    assert_equal false, user.is_admin
  end

  test 'admins scope should return only admin users' do
    admin_user = TelegramUser.create!(
      username: 'admin_user',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: true
    )

    regular_user = TelegramUser.create!(
      username: 'regular_user',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: false
    )

    admin_users = TelegramUser.admins
    assert_includes admin_users, admin_user
    assert_not_includes admin_users, regular_user
  end

  test 'any_admins? should return false when no admins exist' do
    # Create only regular users
    TelegramUser.create!(
      username: 'regular_user1',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: false
    )

    assert_not TelegramUser.any_admins?
  end

  test 'any_admins? should return true when at least one admin exists' do
    # Create regular users
    TelegramUser.create!(
      username: 'regular_user1',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: false
    )

    # Create admin user
    TelegramUser.create!(
      username: 'admin_user',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: true
    )

    assert TelegramUser.any_admins?
  end

  test 'first_admin! should return first admin when admins exist' do
    admin1 = TelegramUser.create!(
      username: 'admin_user1',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: true
    )

    admin2 = TelegramUser.create!(
      username: 'admin_user2',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: true
    )

    first_admin = TelegramUser.first_admin!
    assert_includes [ admin1, admin2 ], first_admin
  end

  test 'first_admin! should return nil when no admins exist' do
    assert_nil TelegramUser.first_admin!
  end

  test 'can promote user to admin' do
    user = TelegramUser.create!(
      username: 'test_user_promote',
      timezone: 'UTC',
      language_code: 'en',
      is_admin: false
    )

    user.update!(is_admin: true)
    user.reload

    assert user.is_admin?
    assert TelegramUser.any_admins?
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
