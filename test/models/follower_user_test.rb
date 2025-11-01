require 'test_helper'

class FollowerUserTest < ActiveSupport::TestCase
  def setup
    @follower_user = follower_users(:one)
    @authorized_user = follower_users(:two)
  end

  # Basic validations tests
  test 'should be valid with valid attributes' do
    assert @follower_user.valid?
  end

  test 'should require phone number' do
    follower_user = FollowerUser.new
    assert_not follower_user.valid?
    assert_includes follower_user.errors[:phone_number], 'не может быть пустым'
  end

  test 'should require unique phone number' do
    duplicate_user = FollowerUser.new(phone_number: @follower_user.phone_number)
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:phone_number], 'уже занят'
  end

  # Auth status tests
  test 'should have correct auth status methods' do
    assert @follower_user.pending?
    assert_not @follower_user.authorized?
    assert_not @follower_user.failed?
    assert_not @follower_user.banned?
    assert_not @follower_user.revoked?
  end

  test 'should identify authorized user correctly' do
    assert @authorized_user.authorized?
    assert_not @authorized_user.pending?
  end

  # Authorization flow tests
  test 'should start authorization when phone number present' do
    # Mock ApplicationConfig to return true for API configuration
    ApplicationConfig.stubs(:telegram_api_configured?).returns(true)

    # Mock AuthorizationService to return success
    mock_service = mock('authorization_service')
    mock_service.expects(:start_authorization).with(@follower_user).returns(success: true, phone_code_hash: 'test_hash')
    Telegram::AuthorizationService.stubs(:instance).returns(mock_service)

    result = @follower_user.start_authorization!
    assert_equal({ success: true, phone_code_hash: 'test_hash' }, result)
  end

  test 'should not start authorization when no phone number' do
    @follower_user.phone_number = nil
    result = @follower_user.start_authorization!
    assert_not result
  end

  test 'should not start authorization when already authorized' do
    result = @authorized_user.start_authorization!
    assert_not result
  end

  # Channel capability tests
  test 'should check if user can join channel' do
    assert @authorized_user.can_join_channel?
    assert_not @follower_user.can_join_channel?
  end

  test 'should check user health status' do
    assert @follower_user.healthy?
    assert @authorized_user.healthy?
  end

  test 'should check user overload status' do
    assert_not @follower_user.overloaded?

    # Set high workload
    @follower_user.workload_score = 0.9
    assert @follower_user.overloaded?
  end

  # Session management tests
  test 'should check if session is active' do
    assert_not @follower_user.session_active?
    assert @authorized_user.session_active?
  end

  test 'should check if user needs reauthorization' do
    assert @follower_user.needs_reauthorization?
    assert_not @authorized_user.needs_reauthorization?
  end

  # Health and metrics tests
  test 'should update health score correctly' do
    @follower_user.update!(health_score: 50.0)
    @follower_user.update_health_score(10.0)

    @follower_user.reload
    assert_equal 60.0, @follower_user.health_score
  end

  test 'should not exceed maximum health score' do
    @follower_user.update_health_score(200.0)
    assert_equal 100.0, @follower_user.health_score
  end

  test 'should not go below minimum health score' do
    @follower_user.update_health_score(-200.0)
    assert_equal 0.0, @follower_user.health_score
  end

  # Daily counter tests
  test 'should reset daily counter correctly' do
    @follower_user.daily_joins_count = 25
    old_date = 2.days.ago.to_date
    @follower_user.update!(last_reset_date: old_date)

    @follower_user.reset_daily_counter

    assert_equal 0, @follower_user.daily_joins_count
    assert_equal Date.current, @follower_user.last_reset_date
    assert_not_equal old_date, @follower_user.last_reset_date
  end

  # Channel operations tests
  test 'should increment joins when joining channel' do
    original_joins = @authorized_user.daily_joins_count
    original_channels = @authorized_user.channels_count

    @authorized_user.join_channel!

    assert_equal original_joins + 1, @authorized_user.daily_joins_count
    assert_equal original_channels + 1, @authorized_user.channels_count
  end

  test 'should decrement channels when leaving channel' do
    @authorized_user.channels_count = 5

    @authorized_user.leave_channel!

    assert_equal 4, @authorized_user.channels_count
  end

  # Class method tests
  test 'should get next available user' do
    # Clear existing users
    FollowerUser.where.not(id: @authorized_user.id).delete_all

    assert_equal @authorized_user, FollowerUser.next_available
  end

  test 'should reset daily counters for all users' do
    # Set some users to old date
    old_date = 2.days.ago
    FollowerUser.where(id: @follower_user.id).update(last_reset_date: old_date)

    assert_difference('FollowerUser.where(last_reset_date: Date.current).count', 1) do
      FollowerUser.reset_daily_counters_for_all
    end
  end

  # Scope tests
  test 'should find authorized users' do
    authorized_users = FollowerUser.authorized
    assert_includes authorized_users, @authorized_user
    assert_not_includes authorized_users, @follower_user
  end

  test 'should find healthy users' do
    healthy_users = FollowerUser.healthy
    assert_includes healthy_users, @follower_user
    assert_includes healthy_users, @authorized_user
  end

  test 'should find users available for join' do
    available_users = FollowerUser.available_for_join
    assert_includes available_users, @authorized_user
    assert_not_includes available_users, @follower_user
  end

  # Encryption tests
  test 'should encrypt session string' do
    # This test ensures the encrypts macro is working
    assert_respond_to @follower_user, :session_string_encrypted
    assert_respond_to @follower_user, :api_credentials_encrypted
  end

  # TelegramCredentials module tests
  test 'should include TelegramCredentials functionality' do
    assert_respond_to @follower_user, :has_session?
    assert_respond_to @follower_user, :has_custom_credentials?
  end
end
