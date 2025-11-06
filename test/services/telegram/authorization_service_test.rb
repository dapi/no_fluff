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
  test 'should return error when follower user is nil' do
    result = @service.start_authorization(nil)
    assert_not result[:success]
    assert_equal 'Invalid user', result[:error]
  end

  test 'should return error when user already authorized' do
    result = @service.start_authorization(@authorized_user)
    assert_not result[:success]
    assert_equal 'Already authorized', result[:error]
  end

  test 'should create authorization session and return success with MTProto' do
    # Mock the MTProto client to avoid real API calls in tests
    mock_client = Minitest::Mock.new
    mock_client.expect(:send_code, { success: true, phone_code_hash: 'real_phone_code_hash_123' })

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      result = @service.start_authorization(@follower_user)

      assert result[:success]
      assert_equal 'real_phone_code_hash_123', result[:phone_code_hash]
      assert result[:expires_at]
    end

    mock_client.verify
  end

  test 'should handle MTProto send_code failure' do
    # Mock the MTProto client to return error
    mock_client = Minitest::Mock.new
    mock_client.expect(:send_code, { success: false, error: 'API rate limit exceeded' })

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      result = @service.start_authorization(@follower_user)

      assert_not result[:success]
      assert_equal 'API rate limit exceeded', result[:error]
    end

    mock_client.verify
  end

  test 'should not start duplicate authorization' do
    # Mock successful first authorization
    mock_client = Minitest::Mock.new
    mock_client.expect(:send_code, { success: true, phone_code_hash: 'real_phone_code_hash_123' })

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      # Start first authorization
      first_result = @service.start_authorization(@follower_user)
      assert first_result[:success]

      # Try to start second
      second_result = @service.start_authorization(@follower_user)
      assert_not second_result[:success]
      assert_equal 'Authorization already in progress', second_result[:error]
    end

    mock_client.verify
  end

  # Confirm authorization tests
  test 'should return error when code is blank' do
    result = @service.confirm_authorization(@follower_user, '')
    assert_not result[:success]
    assert_equal 'Invalid verification code', result[:error]
  end

  test 'should return error when follower user is nil in confirm_authorization' do
    result = @service.confirm_authorization(nil, '12345')
    assert_not result[:success]
    assert_equal 'Invalid user', result[:error]
  end

  test 'should return error when authorization not started' do
    result = @service.confirm_authorization(@follower_user, '12345')
    assert_not result[:success]
    assert_equal 'Authorization not started', result[:error]
  end

  test 'should successfully confirm authorization with MTProto' do
    # Mock MTProto client for both send_code and sign_in
    mock_client = Minitest::Mock.new
    mock_client.expect(:send_code, { success: true, phone_code_hash: 'real_phone_code_hash_123' })
    mock_client.expect(:sign_in, { success: true, user: { id: 123, phone: @follower_user.phone_number } }, [ '54321' ])

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      # Start authorization
      start_result = @service.start_authorization(@follower_user)
      assert start_result[:success]

      # Confirm with real code (no longer hardcoded '12345')
      result = @service.confirm_authorization(@follower_user, '54321')

      assert result[:success]
      assert_equal @follower_user, result[:user]
    end

    mock_client.verify
  end

  test 'should handle MTProto sign_in failure' do
    # Mock MTProto client for send_code success and sign_in failure
    mock_client = Minitest::Mock.new
    mock_client.expect(:send_code, { success: true, phone_code_hash: 'real_phone_code_hash_123' })
    mock_client.expect(:sign_in, { success: false, error: 'Invalid verification code' }, [ 'wrong_code' ])

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      # Start authorization
      start_result = @service.start_authorization(@follower_user)
      assert start_result[:success]

      # Confirm with wrong code
      result = @service.confirm_authorization(@follower_user, 'wrong_code')

      assert_not result[:success]
      assert_equal 'Invalid verification code', result[:error]
    end

    mock_client.verify
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
    # Mock MTProto client
    mock_client = Minitest::Mock.new
    mock_client.expect(:send_code, { success: true, phone_code_hash: 'real_phone_code_hash_123' })

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      # Start authorization
      @service.start_authorization(@follower_user)

      result = @service.authorization_status(@follower_user)

      assert result[:in_progress]
      assert result[:expires_at]
      assert_equal 'real_phone_code_hash_123', result[:phone_code_hash]
    end

    mock_client.verify
  end

  # Cleanup tests
  test 'should cleanup expired authorizations' do
    # Create authorization with old expiration and real phone_code_hash
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user, 'expired_phone_code_hash')
    @service.instance_variable_get(:@pending_authorizations)["auth_#{@follower_user.id}"] = authorization

    # Manually expire it
    authorization.instance_variable_set(:@expires_at, 1.hour.ago)

    initial_count = @service.pending_authorizations.size
    @service.cleanup_expired_authorizations
    final_count = @service.pending_authorizations.size

    assert_equal initial_count - 1, final_count
  end

  test 'should cleanup specific authorization' do
    # Mock MTProto client
    mock_client = Minitest::Mock.new
    mock_client.expect(:send_code, { success: true, phone_code_hash: 'cleanup_test_hash' })

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      # Start authorization
      @service.start_authorization(@follower_user)

      assert @service.pending_authorizations.key?("auth_#{@follower_user.id}")

      @service.cleanup_authorization(@follower_user)

      assert_not @service.pending_authorizations.key?("auth_#{@follower_user.id}")
    end

    mock_client.verify
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
    phone_code_hash = 'test_phone_code_hash_123'
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user, phone_code_hash)

    assert_equal @follower_user, authorization.follower_user
    assert_equal phone_code_hash, authorization.phone_code_hash
    assert authorization.created_at
    assert authorization.expires_at > authorization.created_at
    assert authorization.expires_at <= authorization.created_at + 10.minutes
  end

  test 'should initialize with default phone_code_hash when not provided' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)

    assert_equal @follower_user, authorization.follower_user
    assert authorization.phone_code_hash.include?("default_phone_code_hash_#{@follower_user.id}")
    assert authorization.created_at
    assert authorization.expires_at > authorization.created_at
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

  test 'should calculate progress percentage' do
    authorization = Telegram::FollowerUserAuthorization.new(@follower_user)

    progress = authorization.progress_percentage
    assert progress >= 0
    assert progress <= 100
  end

  test 'should test authorization with MTProto' do
    # Mock MTProto client for test_connection
    mock_client = Minitest::Mock.new
    mock_client.expect(:test_connection, { success: true, user_info: { id: 123, phone: @follower_user.phone_number } })

    Telegram::UserClientMtproto.stub(:new, mock_client) do
      result = @service.test_authorization(@follower_user)

      assert result[:success]
      assert result[:user_info]
    end

    mock_client.verify
  end

  test 'should handle test authorization failure' do
    result = @service.test_authorization(nil)

    assert_not result[:success]
    assert_equal 'Invalid user', result[:error]
  end
end
