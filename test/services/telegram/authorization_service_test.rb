require 'test_helper'

class Telegram::AuthorizationServiceTest < ActiveSupport::TestCase
  def setup
    # Mock encryption credentials for test environment
    ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] = 'test_key_for_encryption_32_chars_long'

    @service = Telegram::AuthorizationService.instance
    @follower_user = follower_users(:one)
    @authorized_user = follower_users(:two)
  end

  def teardown
    @service.cleanup_authorization(@follower_user)
    @service.cleanup_authorization(@authorized_user)
  end

  # Start authorization tests
  test 'should return false when follower user is nil' do
    result = @service.start_authorization(nil)
    assert_not result
  end

  # Removed telegram_api_configured? test - API credentials are now required

  test 'should create authorization session and return success' do
    # Telegram API credentials are now required, no need to stub configuration

    result = @service.start_authorization(@follower_user)

    assert result[:success]
    assert result[:phone_code_hash].present?
  end

  test 'should not start duplicate authorization' do
    # Telegram API credentials are now required

    # Start first authorization
    @service.start_authorization(@follower_user)

    # Try to start second
    result = @service.start_authorization(@follower_user)

    assert_not result
  end

  # Confirm authorization tests
  test 'should return error when code is blank' do
    result = @service.confirm_authorization(@follower_user, '')
    assert_not result[:success]
    assert_equal 'Invalid verification code', result[:error]
  end

  test 'should return error when follower user is nil' do
    result = @service.confirm_authorization(nil, '12345')
    assert_not result[:success]
  end

  test 'should return error when authorization not started' do
    result = @service.confirm_authorization(@follower_user, '12345')
    assert_not result[:success]
    assert_equal 'Authorization not started', result[:error]
  end

  test 'should successfully confirm authorization with correct code' do
    # Telegram API credentials are now required

    # Start authorization
    start_result = @service.start_authorization(@follower_user)
    assert start_result[:success]

    # Confirm with demo code
    result = @service.confirm_authorization(@follower_user, '12345')

    assert result[:success]
    assert_equal @follower_user, result[:user]
    assert @follower_user.reload.authorized?
  end

  # Authorization status tests
  test 'should return nil when follower user is nil' do
    result = @service.authorization_status(nil)
    assert_nil result
  end

  test 'should return nil when no authorization in progress' do
    result = @service.authorization_status(@follower_user)
    assert_nil result
  end

  test 'should return authorization status when in progress' do
    # Telegram API credentials are now required

    # Start authorization
    @service.start_authorization(@follower_user)

    result = @service.authorization_status(@follower_user)

    assert result[:in_progress]
    assert result[:expires_at]
    assert result[:phone_code_hash]
  end

  # Cleanup tests
  test 'should cleanup expired authorizations' do
    # Telegram API credentials are now required

    # Create authorization with old expiration
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)
    @service.instance_variable_get(:@pending_authorizations)["auth_#{@follower_user.id}"] = authorization

    # Manually expire it
    authorization.instance_variable_set(:@expires_at, 1.hour.ago)

    initial_count = @service.pending_authorizations.size
    @service.cleanup_expired_authorizations
    final_count = @service.pending_authorizations.size

    assert_equal initial_count - 1, final_count
  end

  test 'should cleanup specific authorization' do
    # Telegram API credentials are now required

    # Start authorization
    @service.start_authorization(@follower_user)

    assert @service.pending_authorizations.key?("auth_#{@follower_user.id}")

    @service.cleanup_authorization(@follower_user)

    assert_not @service.pending_authorizations.key?("auth_#{@follower_user.id}")
  end

  # Statistics tests
  test 'should return authorization statistics' do
    stats = @service.authorization_stats

    assert stats.key?(:pending)
    assert stats.key?(:in_progress)
    assert stats.key?(:expired)
  end

  # FollowerUserAuthorization tests
  test 'should initialize with correct attributes' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)

    assert_equal @follower_user, authorization.follower_user
    assert authorization.created_at
    assert authorization.expires_at > authorization.created_at
    assert authorization.expires_at <= authorization.created_at + 10.minutes
  end

  test 'should be expired after 10 minutes' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)

    # Manually set expiration to past
    authorization.instance_variable_set(:@expires_at, 11.minutes.ago)

    assert authorization.expired?
  end

  test 'should be in progress when authorization started' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)

    authorization.instance_variable_set(:@in_progress, true)

    assert authorization.in_progress?
  end

  test 'should not be in progress when not started' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)

    assert_not authorization.in_progress?
  end

  test 'should return time remaining' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)

    remaining = authorization.time_remaining
    assert remaining > 0
    assert remaining <= 600 # 10 minutes in seconds
  end

  test 'should return 0 time remaining when expired' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)
    authorization.instance_variable_set(:@expires_at, 5.minutes.ago)

    assert_equal 0, authorization.time_remaining
  end
end
