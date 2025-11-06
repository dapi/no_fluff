require 'test_helper'

class Telegram::AuthorizationServiceMtprotoTest < ActiveSupport::TestCase
  def setup
    # Mock encryption credentials for test environment
    ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] = 'test_key_for_encryption_32_chars_long'

    @service = Telegram::AuthorizationServiceMtproto.instance
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

  test 'should return error when authorization already in progress' do
    # Mock successful first authorization
    mock_client = mock('client')
    mock_client.expects(:send_code).returns(
      success: true,
      phone_code_hash: 'test_hash_12345'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    # Start first authorization
    result1 = @service.start_authorization(@follower_user)
    assert result1[:success]

    # Try to start second (should not create new client)
    result2 = @service.start_authorization(@follower_user)
    assert_not result2[:success]
    assert_equal 'Authorization already in progress', result2[:error]
  end

  test 'should create authorization session and return success with real phone_code_hash' do
    mock_client = mock('client')
    mock_client.expects(:send_code).returns(
      success: true,
      phone_code_hash: 'real_phone_code_hash_abc123'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    result = @service.start_authorization(@follower_user)

    assert result[:success]
    assert_equal 'real_phone_code_hash_abc123', result[:phone_code_hash]
    assert result[:expires_at].present?
    assert result[:expires_at] > Time.current
  end

  test 'should handle MTProto client creation failure' do
    Telegram::UserClientMtproto.expects(:new).raises(StandardError.new('Client creation failed'))

    result = @service.start_authorization(@follower_user)

    assert_not result[:success]
    assert_equal 'Client creation failed', result[:error]
  end

  test 'should handle send_code API failure' do
    mock_client = mock('client')
    mock_client.expects(:send_code).returns(
      success: false,
      error: 'API_RATE_LIMITED'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    result = @service.start_authorization(@follower_user)

    assert_not result[:success]
    assert_equal 'API_RATE_LIMITED', result[:error]
  end

  # Confirm authorization tests
  test 'should return error when confirmation code is blank' do
    result = @service.confirm_authorization(@follower_user, '')

    assert_not result[:success]
    assert_equal 'Invalid verification code', result[:error]
  end

  test 'should return error when user is nil' do
    result = @service.confirm_authorization(nil, '12345')

    assert_not result[:success]
    assert_equal 'Invalid user', result[:error]
  end

  test 'should return error when authorization not started' do
    result = @service.confirm_authorization(@follower_user, '12345')

    assert_not result[:success]
    assert_equal 'Authorization not started', result[:error]
  end

  test 'should return error when authorization expired' do
    # Start authorization first
    mock_client_send = mock('client_send')
    mock_client_send.expects(:send_code).returns(
      success: true,
      phone_code_hash: 'test_hash'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_send)

    @service.start_authorization(@follower_user)

    # Mock expired authorization
    authorization = @service.pending_authorizations["auth_#{@follower_user.id}"]
    authorization.instance_variable_set(:@expires_at, 1.minute.ago)

    result = @service.confirm_authorization(@follower_user, '12345')

    assert_not result[:success]
    assert_equal 'Authorization expired', result[:error]
  end

  test 'should successfully confirm authorization with valid code' do
    phone_code_hash = 'test_phone_code_hash_12345'

    # Start authorization
    mock_client_send = mock('client_send')
    mock_client_send.expects(:send_code).returns(
      success: true,
      phone_code_hash: phone_code_hash
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_send)

    result_start = @service.start_authorization(@follower_user)
    assert result_start[:success]

    # Confirm authorization
    mock_client_sign = mock('client_sign')
    mock_client_sign.expects(:sign_in).with('12345').returns(
      success: true,
      user: { id: @follower_user.id, username: @follower_user.username }
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_sign)

    result_confirm = @service.confirm_authorization(@follower_user, '12345')

    assert result_confirm[:success]
    assert_equal @follower_user, result_confirm[:user]

    # Check authorization was cleaned up
    assert_nil @service.authorization_status(@follower_user)
  end

  test 'should return error for invalid verification code' do
    phone_code_hash = 'test_phone_code_hash_12345'

    # Start authorization
    mock_client_send = mock('client_send')
    mock_client_send.expects(:send_code).returns(
      success: true,
      phone_code_hash: phone_code_hash
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_send)

    @service.start_authorization(@follower_user)

    # Try invalid code
    mock_client_sign = mock('client_sign')
    mock_client_sign.expects(:sign_in).with('wrong_code').returns(
      success: false,
      error: 'PHONE_CODE_INVALID'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_sign)

    result = @service.confirm_authorization(@follower_user, 'wrong_code')

    assert_not result[:success]
    assert_equal 'PHONE_CODE_INVALID', result[:error]
  end

  test 'should handle sign_in API failure' do
    phone_code_hash = 'test_phone_code_hash_12345'

    # Start authorization
    mock_client_send = mock('client_send')
    mock_client_send.expects(:send_code).returns(
      success: true,
      phone_code_hash: phone_code_hash
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_send)

    @service.start_authorization(@follower_user)

    # API failure during sign_in
    mock_client_sign = mock('client_sign')
    mock_client_sign.expects(:sign_in).with('12345').raises(StandardError.new('Network error'))
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_sign)

    result = @service.confirm_authorization(@follower_user, '12345')

    assert_not result[:success]
    assert_equal 'Network error', result[:error]
  end

  # Authorization status tests
  test 'should return nil for non-existent authorization' do
    status = @service.authorization_status(@follower_user)
    assert_nil status
  end

  test 'should return authorization status for active session' do
    phone_code_hash = 'test_phone_code_hash_12345'

    # Start authorization
    mock_client = mock('client')
    mock_client.expects(:send_code).returns(
      success: true,
      phone_code_hash: phone_code_hash
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    @service.start_authorization(@follower_user)

    status = @service.authorization_status(@follower_user)

    assert_not_nil status
    assert status[:in_progress]
    assert_equal phone_code_hash, status[:phone_code_hash]
    assert status[:expires_at] > Time.current
  end

  test 'should return nil for expired authorization' do
    phone_code_hash = 'test_phone_code_hash_12345'

    # Start authorization
    mock_client = mock('client')
    mock_client.expects(:send_code).returns(
      success: true,
      phone_code_hash: phone_code_hash
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    @service.start_authorization(@follower_user)

    # Mock expired authorization
    authorization = @service.pending_authorizations["auth_#{@follower_user.id}"]
    authorization.instance_variable_set(:@expires_at, 1.minute.ago)

    status = @service.authorization_status(@follower_user)
    assert_nil status
  end

  # Cleanup tests
  test 'should cleanup authorization successfully' do
    phone_code_hash = 'test_phone_code_hash_12345'

    # Start authorization
    mock_client = mock('client')
    mock_client.expects(:send_code).returns(
      success: true,
      phone_code_hash: phone_code_hash
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    @service.start_authorization(@follower_user)
    assert_not_nil @service.authorization_status(@follower_user)

    # Cleanup
    @service.cleanup_authorization(@follower_user)

    assert_nil @service.authorization_status(@follower_user)
  end

  test 'should reset user status to failed when cleaning up pending user' do
    # Set user to pending status
    @follower_user.update!(auth_status: 'pending')

    @service.cleanup_authorization(@follower_user)

    @follower_user.reload
    assert_equal 'failed', @follower_user.auth_status
  end

  test 'should not reset status for non-pending user during cleanup' do
    # Set user to authorized status
    @authorized_user.update!(auth_status: 'authorized')

    @service.cleanup_authorization(@authorized_user)

    @authorized_user.reload
    assert_equal 'authorized', @authorized_user.auth_status
  end

  test 'should cleanup all expired authorizations' do
    # Create one active authorization
    mock_client_active = mock('client_active')
    mock_client_active.expects(:send_code).returns(
      success: true,
      phone_code_hash: 'active_hash'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_active)

    @service.start_authorization(@follower_user)

    # Create expired authorization manually
    expired_user = follower_users(:three)
    expired_authorization = Telegram::FollowerUserAuthorizationMtproto.new(expired_user, 'expired_hash')
    expired_authorization.start! # Mark as in progress
    expired_authorization.instance_variable_set(:@expires_at, 1.minute.ago)
    @service.instance_variable_get(:@pending_authorizations)["auth_#{expired_user.id}"] = expired_authorization

    # Set user status to pending before cleanup
    expired_user.update!(auth_status: 'pending')

    # Cleanup
    @service.cleanup_expired_authorizations

    # Check expired authorization was removed
    assert_nil @service.authorization_status(expired_user)
    assert_not_nil @service.authorization_status(@follower_user)

    # Check user status was updated to failed
    expired_user.reload
    assert_equal 'failed', expired_user.auth_status
  end

  # Statistics tests
  test 'should return correct authorization statistics' do
    # Start active authorization
    mock_client_active = mock('client_active')
    mock_client_active.expects(:send_code).returns(
      success: true,
      phone_code_hash: 'active_hash'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client_active)
    @service.start_authorization(@follower_user)

    # Create expired authorization manually
    expired_user = follower_users(:three)
    expired_authorization = Telegram::FollowerUserAuthorizationMtproto.new(expired_user, 'expired_hash')
    expired_authorization.start! # Mark as in progress
    expired_authorization.instance_variable_set(:@expires_at, 1.minute.ago)
    @service.instance_variable_get(:@pending_authorizations)["auth_#{expired_user.id}"] = expired_authorization

    stats = @service.authorization_stats

    assert_equal 2, stats[:pending]  # Both authorizations still in memory
    assert_equal 1, stats[:in_progress]  # Only active one
    assert_equal 1, stats[:expired]  # Expired one
  end

  test 'should return all pending authorizations' do
    # Start authorization for first user
    mock_client = mock('client')
    mock_client.expects(:send_code).returns(
      success: true,
      phone_code_hash: 'hash_1'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    @service.start_authorization(@follower_user)

    # Create second authorization manually
    second_user = follower_users(:three)
    second_authorization = Telegram::FollowerUserAuthorizationMtproto.new(second_user, 'hash_2')
    second_authorization.start! # Mark as in progress
    @service.instance_variable_get(:@pending_authorizations)["auth_#{second_user.id}"] = second_authorization

    pending = @service.pending_authorizations

    assert_equal 2, pending.length
    assert pending.key?("auth_#{@follower_user.id}")
    assert pending.key?("auth_#{second_user.id}")
  end

  # Test authorization test method
  test 'should test authorization flow successfully' do
    mock_client = mock('client')
    mock_client.expects(:test_connection).returns(
      success: true,
      user_info: { id: @follower_user.id, username: @follower_user.username }
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    result = @service.test_authorization(@follower_user)

    assert result[:success]
    assert_equal @follower_user.id, result[:user_info][:id]
  end

  test 'should handle authorization test failure' do
    mock_client = mock('client')
    mock_client.expects(:test_connection).returns(
      success: false,
      error: 'Connection failed'
    )
    Telegram::UserClientMtproto.expects(:new).returns(mock_client)

    result = @service.test_authorization(@follower_user)

    assert_not result[:success]
    assert_equal 'Connection failed', result[:error]
  end

  test 'should handle authorization test with nil user' do
    result = @service.test_authorization(nil)

    assert_not result[:success]
    assert_equal 'Invalid user', result[:error]
  end

  test 'should handle authorization test exception' do
    Telegram::UserClientMtproto.expects(:new).raises(StandardError.new('Test failed'))

    result = @service.test_authorization(@follower_user)

    assert_not result[:success]
    assert_equal 'Test failed', result[:error]
  end
end
