require 'test_helper'

class TelegramUser::AdminTest < ActiveSupport::TestCase
  include TelegramHelper
  include MocksHelper

  def setup
    @admin_user = telegram_users(:admin_user)
    @regular_user = telegram_users(:one)
  end

  # Admin functionality tests
  test 'admin user should have admin flag set to true' do
    assert @admin_user.is_admin?
  end

  test 'regular user should not have admin flag set to true' do
    assert_not @regular_user.is_admin?
  end

  test 'should identify admin users correctly' do
    assert TelegramUser.admins.include?(@admin_user)
    assert_not TelegramUser.admins.include?(@regular_user)
  end

  test 'should check if any admins exist' do
    assert TelegramUser.any_admins?
  end

  test 'should return first admin' do
    first_admin = TelegramUser.first_admin!
    assert_equal @admin_user, first_admin
    assert first_admin.is_admin?
  end

  # Admin session management tests (using Sessionable concern)
  test 'should start admin session' do
    result = @admin_user.set_session('admin_session', { started_at: Time.current })
    assert result
    assert @admin_user.session_has_key?('admin_session')
  end

  test 'should end admin session' do
    @admin_user.set_session('admin_session', { started_at: Time.current })
    assert @admin_user.session_has_key?('admin_session')

    @admin_user.delete_session('admin_session')
    assert_not @admin_user.session_has_key?('admin_session')
  end

  test 'should check active admin session' do
    assert_not @admin_user.session_has_key?('admin_session')

    @admin_user.set_session('admin_session', { active: true })
    assert @admin_user.session_has_key?('admin_session')
  end

  # Admin preferences tests
  test 'should store admin preferences in session data' do
    preferences = {
      'notification_level' => 'high',
      'auto_reply' => false,
      'debug_mode' => true
    }

    result = @admin_user.set_session('admin_preferences', preferences)
    assert result
    assert_equal preferences, @admin_user.get_session('admin_preferences')
  end

  test 'should retrieve admin preferences from session data' do
    preferences = {
      'notification_level' => 'low',
      'auto_reply' => true,
      'debug_mode' => false
    }

    @admin_user.set_session('admin_preferences', preferences)
    retrieved = @admin_user.get_session('admin_preferences')
    assert_equal 'low', retrieved['notification_level']
  end

  # Admin statistics tests
  test 'should track admin interactions through sessions' do
    initial_session_size = @admin_user.session_size

    @admin_user.set_session('admin_action', { action: 'test', timestamp: Time.current })
    assert_equal initial_session_size + 1, @admin_user.session_size
  end

  test 'should get admin statistics based on session data and subscriptions' do
    @admin_user.set_session('admin_stats', { actions_count: 5, last_login: Time.current })

    stats = {
      session_size: @admin_user.session_size,
      subscriptions_count: @admin_user.subscriptions.count,
      channels_count: @admin_user.channels_count,
      is_premium: @admin_user.is_premium?
    }

    assert stats.key?(:session_size)
    assert stats.key?(:subscriptions_count)
    assert stats.key?(:channels_count)
    assert stats.key?(:is_premium)
  end

  # Premium admin functionality tests
  test 'admin user should be premium and have unlimited channels' do
    assert @admin_user.is_premium?
    assert @admin_user.can_add_channel?
  end

  test 'admin user should have premium delivery settings' do
    assert_equal 'once_daily', @admin_user.delivery_frequency
    assert_equal 'combo', @admin_user.content_format
    assert_equal 'low', @admin_user.filter_strictness
  end

  # Edge cases tests
  test 'should handle multiple admin sessions' do
    result1 = @admin_user.set_session('admin_session', { started_at: Time.current })
    result2 = @admin_user.set_session('debug_session', { started_at: Time.current })

    assert result1
    assert result2
    assert @admin_user.session_has_key?('admin_session')
    assert @admin_user.session_has_key?('debug_session')
  end

  test 'should handle session termination gracefully' do
    @admin_user.set_session('admin_session', { started_at: Time.current })

    assert_nothing_raised do
      @admin_user.delete_session('nonexistent_session')
    end
  end

  # Admin user management tests
  test 'should create new admin user' do
    new_admin = TelegramUser.create!(
      username: 'new_admin',
      first_name: 'New',
      last_name: 'Admin',
      language_code: 'en',
      timezone: 'UTC',
      is_admin: true,
      is_premium: true
    )

    assert new_admin.persisted?
    assert new_admin.is_admin?
    assert new_admin.is_premium?
  end

  test 'should promote regular user to admin' do
    regular_user = telegram_users(:two)
    assert_not regular_user.is_admin?

    regular_user.update!(is_admin: true)
    assert regular_user.is_admin?
    assert TelegramUser.admins.include?(regular_user)
  end

  test 'should demote admin user to regular user' do
    @admin_user.update!(is_admin: false)

    assert_not @admin_user.is_admin?
    assert_not TelegramUser.admins.include?(@admin_user)
  end
end
