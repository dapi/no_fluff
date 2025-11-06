require 'test_helper'

class Telegram::UserClientMtprotoTest < ActiveSupport::TestCase
  def setup
    # Mock encryption credentials for test environment
    ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] = 'test_key_for_encryption_32_chars_long'

    # Mock ApplicationConfig for telegram_api_configured?
    ApplicationConfig.stubs(:telegram_api_configured?).returns(true)
    ApplicationConfig.stubs(:telegram_api_credentials).returns({
      api_id: 123456,
      api_hash: 'test_hash'
    })

    # Create follower user with proper credentials handling
    @follower_user = follower_users(:one)

    # Mock api_credentials_encrypted to avoid decryption errors
    @follower_user.stubs(:respond_to?).with(:api_credentials_encrypted).returns(true)
    @follower_user.stubs(:respond_to?).with(:api_credentials_encrypted=).returns(true)
    @follower_user.stubs(:api_credentials_encrypted).returns('{"api_id":123456,"api_hash":"test_hash"}')

    # Mock session_string_encrypted methods
    @follower_user.stubs(:respond_to?).with(:session_string_encrypted).returns(true)
    @follower_user.stubs(:respond_to?).with(:session_string_encrypted=).returns(true)
    @follower_user.stubs(:session_string_encrypted).returns(nil)

    @client = Telegram::UserClientMtproto.new(@follower_user)
    @mock_mtproto_client = mock('mtproto_client')
  end

  def teardown
    @client.disconnect if @client&.connected?
    Mocha::Mockery.teardown
  end

  # Client creation tests
  test 'should initialize with follower user' do
    assert_equal @follower_user, @client.follower_user
    assert_equal @follower_user.api_credentials, @client.api_credentials
    assert_nil @client.client
  end

  test 'should create client successfully when API configured' do
    ApplicationConfig.stubs(:telegram_api_configured?).returns(true)
    TelegramMtproto::Client.expects(:new).returns(@mock_mtproto_client)

    result = @client.create_client

    assert result
    assert_equal @mock_mtproto_client, @client.client
  end

  test 'should return false when API not configured' do
    ApplicationConfig.stubs(:telegram_api_configured?).returns(false)

    result = @client.create_client

    assert_not result
    assert_nil @client.client
  end

  test 'should handle client creation failure' do
    ApplicationConfig.stubs(:telegram_api_configured?).returns(true)
    TelegramMtproto::Client.expects(:new).raises(StandardError.new('Client creation failed'))

    result = @client.create_client

    assert_not result
    assert_nil @client.client
  end

  # Connection tests
  test 'should connect successfully with new session' do
    setup_mock_client_for_connection
    @follower_user.stubs(:has_session?).returns(false)

    result = @client.connect

    assert result
    assert @client.connected?
    assert_not @client.authorized?
  end

  test 'should connect successfully and restore existing session' do
    setup_mock_client_for_connection
    @follower_user.stubs(:has_session?).returns(true)
    @follower_user.stubs(:session_string).returns('{"session":"data"}')
    @mock_mtproto_client.expects(:restore_session).with('{"session":"data"}').returns(true)

    result = @client.connect

    assert result
    assert @client.connected?
    assert @client.authorized?
  end

  test 'should return false when connection fails' do
    @client.stubs(:create_client).returns(false)

    result = @client.connect

    assert_not result
    assert_not @client.connected?
  end

  test 'should handle connection exception' do
    @client.stubs(:create_client).returns(true)
    @mock_mtproto_client.stubs(:connect).raises(StandardError.new('Connection failed'))

    result = @client.connect

    assert_not result
    assert_not @client.connected?
  end

  test 'should not reconnect if already connected' do
    setup_mock_client_for_connection
    @client.connect  # First connection

    result = @client.connect  # Second connection

    assert result  # Should return true without reconnecting
  end

  # Disconnection tests
  test 'should disconnect successfully when authorized' do
    setup_mock_client_for_connection
    @mock_mtproto_client.stubs(:get_session_string).returns('{"session":"data"}')
    @client.connect
    @client.instance_variable_set(:@authorized, true)

    result = @client.disconnect

    assert result
    assert_not @client.connected?
    assert_not @client.authorized?
    assert_nil @client.client
  end

  test 'should disconnect successfully when not authorized' do
    setup_mock_client_for_connection
    @client.connect

    result = @client.disconnect

    assert result
    assert_not @client.connected?
    assert_not @client.authorized?
    assert_nil @client.client
  end

  test 'should return true when disconnecting already disconnected client' do
    result = @client.disconnect

    assert result
  end

  test 'should handle disconnection exception' do
    setup_mock_client_for_connection
    @client.connect
    @mock_mtproto_client.stubs(:disconnect).raises(StandardError.new('Disconnect failed'))

    result = @client.disconnect

    assert_not result
  end

  # Authorization tests
  test 'should send code successfully' do
    setup_mock_client_for_connection

    @mock_mtproto_client.expects(:send_code).returns(
      success: true,
      phone_code_hash: 'test_phone_code_hash_123'
    )

    result = @client.send_code

    assert result[:success]
    assert_equal 'test_phone_code_hash_123', result[:phone_code_hash]
    assert result[:expires_at] > Time.current
  end

  test 'should return error when already authorized' do
    setup_mock_client_for_connection
    @client.connect
    @client.instance_variable_set(:@authorized, true)

    result = @client.send_code

    assert_not result[:success]
    assert_equal 'Already authorized', result[:error]
  end

  test 'should handle send_code API failure' do
    setup_mock_client_for_connection

    @mock_mtproto_client.expects(:send_code).returns(
      success: false,
      error: 'API_RATE_LIMITED'
    )

    result = @client.send_code

    assert_not result[:success]
    assert_equal 'API_RATE_LIMITED', result[:error]
  end

  test 'should handle send_code exception' do
    setup_mock_client_for_connection

    @mock_mtproto_client.expects(:send_code).raises(StandardError.new('Network error'))

    result = @client.send_code

    assert_not result[:success]
    assert_equal 'Network error', result[:error]
  end

  test 'should sign in successfully with valid code' do
    setup_mock_client_for_connection
    test_user_info = { id: 123, username: 'testuser', first_name: 'Test', last_name: 'User' }

    @mock_mtproto_client.expects(:sign_in).with(code: '12345').returns(
      success: true,
      user: test_user_info
    )
    @mock_mtproto_client.expects(:get_session_string).returns('{"session":"data"}')
    @follower_user.expects(:update!).with do |args|
      args[:auth_status] == 'authorized' &&
      args[:last_authorized_at].is_a?(Time) &&
      args[:session_string] == '{"session":"data"}'
    end

    result = @client.sign_in('12345')

    assert result[:success]
    assert_equal test_user_info, result[:user]
    assert @client.authorized?
  end

  test 'should return error when signing in already authorized client' do
    setup_mock_client_for_connection
    @client.connect
    @client.instance_variable_set(:@authorized, true)

    result = @client.sign_in('12345')

    assert_not result[:success]
    assert_equal 'Already authorized', result[:error]
  end

  test 'should handle sign_in API failure' do
    setup_mock_client_for_connection

    @mock_mtproto_client.expects(:sign_in).with(code: 'wrong_code').returns(
      success: false,
      error: 'PHONE_CODE_INVALID'
    )

    result = @client.sign_in('wrong_code')

    assert_not result[:success]
    assert_equal 'PHONE_CODE_INVALID', result[:error]
    assert_not @client.authorized?
  end

  test 'should handle sign_in exception' do
    setup_mock_client_for_connection

    @mock_mtproto_client.expects(:sign_in).raises(StandardError.new('Sign in failed'))

    result = @client.sign_in('12345')

    assert_not result[:success]
    assert_equal 'Sign in failed', result[:error]
    assert_not @client.authorized?
  end

  # Channel operations tests
  test 'should join channel successfully' do
    setup_mock_client_for_connection
    @client.connect

    channel_data = {
      id: 12345,
      username: 'testchannel',
      title: 'Test Channel',
      description: 'Test Description',
      participant_count: 1000,
      verified: true
    }

    @mock_mtproto_client.expects(:join_chat).with('testchannel').returns(
      success: true,
      chat: channel_data
    )

    result = @client.join_channel('testchannel')

    assert result[:success]
    assert_equal channel_data[:id], result[:channel_info][:id]
    assert_equal 'testchannel', result[:channel_info][:username]
    assert_equal 1000, result[:channel_info][:member_count]
  end

  test 'should return error when joining channel with blank username' do
    result = @client.join_channel('')

    assert_not result[:success]
  end

  test 'should return error when joining channel without client connection' do
    result = @client.join_channel('testchannel')

    assert_not result[:success]
  end

  test 'should handle join_channel API failure' do
    setup_mock_client_for_connection
    @client.connect

    @mock_mtproto_client.expects(:join_chat).with('privatechannel').returns(
      success: false,
      error: 'CHANNEL_PRIVATE'
    )

    result = @client.join_channel('privatechannel')

    assert_not result[:success]
    assert_equal 'CHANNEL_PRIVATE', result[:error]
  end

  test 'should leave channel successfully' do
    setup_mock_client_for_connection
    @client.connect

    @mock_mtproto_client.expects(:leave_chat).with('testchannel').returns(
      success: true
    )

    result = @client.leave_channel('testchannel')

    assert result[:success]
  end

  test 'should return error when leaving channel with blank username' do
    result = @client.leave_channel('')

    assert_not result[:success]
    assert_equal 'Username cannot be blank', result[:error]
  end

  test 'should get channel info successfully' do
    setup_mock_client_for_connection
    @client.connect

    channel_data = {
      id: 12345,
      username: 'testchannel',
      title: 'Test Channel',
      description: 'Test Description',
      participant_count: 1000,
      verified: true,
      access_hash: 'access_hash_123'
    }

    @mock_mtproto_client.expects(:get_chat_info).with('testchannel').returns(
      success: true,
      chat: channel_data
    )

    result = @client.get_channel_info('testchannel')

    assert_not_nil result
    assert_equal 12345, result[:id]
    assert_equal 'testchannel', result[:username]
    assert_equal 1000, result[:member_count]
    assert_equal true, result[:verified]
  end

  test 'should return nil when getting channel info with blank username' do
    result = @client.get_channel_info('')

    assert_nil result
  end

  test 'should return nil when getting channel info without client connection' do
    result = @client.get_channel_info('testchannel')

    assert_nil result
  end

  test 'should handle get_chat_info API failure' do
    setup_mock_client_for_connection
    @client.connect

    @mock_mtproto_client.expects(:get_chat_info).with('nonexistent').returns(
      success: false,
      error: 'USERNAME_NOT_OCCUPIED'
    )

    result = @client.get_channel_info('nonexistent')

    assert_nil result
  end

  # Messaging tests
  test 'should send message successfully' do
    setup_mock_client_for_connection
    @client.connect

    @mock_mtproto_client.expects(:send_message).with(
      chat_id: 12345,
      text: 'Hello World'
    ).returns(
      success: true,
      message_id: 67890
    )

    result = @client.send_message(12345, 'Hello World')

    assert result[:success]
    assert_equal 67890, result[:message_id]
  end

  test 'should return error when sending message with blank text' do
    result = @client.send_message(12345, '')

    assert_not result[:success]
    assert_equal 'Text cannot be blank', result[:error]
  end

  test 'should return error when sending message without client connection' do
    result = @client.send_message(12345, 'Hello')

    assert_not result[:success]
  end

  test 'should handle send_message API failure' do
    setup_mock_client_for_connection
    @client.connect

    @mock_mtproto_client.expects(:send_message).raises(StandardError.new('Message send failed'))

    result = @client.send_message(12345, 'Hello')

    assert_not result[:success]
    assert_equal 'Message send failed', result[:error]
  end

  # Connection status tests
  test 'should return authorized status from client' do
    setup_mock_client_for_connection
    @client.connect
    @client.instance_variable_set(:@authorized, true)

    assert @client.authorized?
  end

  test 'should return authorized status from follower user' do
    # Create a mock follower user that is authorized
    @authorized_user = mock('authorized_follower_user')
    @authorized_user.stubs(:respond_to?).with(:api_credentials_encrypted).returns(true)
    @authorized_user.stubs(:api_credentials_encrypted).returns('{"api_id":123456,"api_hash":"test_hash"}')
    @authorized_user.stubs(:respond_to?).with(:session_string_encrypted).returns(true)
    @authorized_user.stubs(:session_string_encrypted).returns('{"session":"data"}')
    @authorized_user.stubs(:authorized?).returns(true)
    @authorized_user.stubs(:phone_number).returns('+1234567890')
    @authorized_user.stubs(:username).returns('testuser')
    @authorized_user.stubs(:first_name).returns('Test')
    @authorized_user.stubs(:last_name).returns('User')
    @authorized_user.stubs(:id).returns(2)
    # Add stub for api_credentials method that is called in initialize
    @authorized_user.stubs(:api_credentials).returns({
      api_id: 123456,
      api_hash: 'test_hash'
    })

    client = Telegram::UserClientMtproto.new(@authorized_user)

    assert client.authorized?
    assert_equal @authorized_user, client.follower_user
  end

  test 'should return connected status when client is connected' do
    setup_mock_client_for_connection
    @client.connect

    assert @client.connected?
  end

  test 'should return false for connected status when client is not connected' do
    assert_not @client.connected?
  end

  # Connection test
  test 'should test connection successfully' do
    setup_mock_client_for_connection
    user_data = { id: 123, username: 'testuser', first_name: 'Test', last_name: 'User' }

    @mock_mtproto_client.expects(:get_me).returns(
      success: true,
      user: user_data
    )

    result = @client.test_connection

    assert result[:success]
    assert_equal 123, result[:user_info][:id]
    assert_equal 'testuser', result[:user_info][:username]
    assert_not @client.connected?  # Should disconnect after test
  end

  test 'should test connection and stay connected if authorized' do
    setup_mock_client_for_connection
    user_data = { id: 123, username: 'testuser', first_name: 'Test', last_name: 'User' }

    @mock_mtproto_client.expects(:get_me).returns(
      success: true,
      user: user_data
    )

    # Mock sign_in to set authorized status
    @mock_mtproto_client.stubs(:sign_in).returns(success: true)
    @mock_mtproto_client.stubs(:get_session_string).returns('session_data')
    @follower_user.stubs(:update!)

    @client.sign_in('12345')  # Set authorized status

    result = @client.test_connection

    assert result[:success]
    assert @client.connected?  # Should stay connected if authorized
  end

  test 'should handle connection test failure' do
    setup_mock_client_for_connection

    @mock_mtproto_client.expects(:get_me).returns(
      success: false,
      error: 'Connection test failed'
    )

    result = @client.test_connection

    assert_not result[:success]
    assert_equal 'Connection test failed', result[:error]
  end

  test 'should handle connection test exception' do
    setup_mock_client_for_connection

    @mock_mtproto_client.expects(:get_me).raises(StandardError.new('Test exception'))

    result = @client.test_connection

    assert_not result[:success]
    assert_equal 'Test exception', result[:error]
  end

  private

  def setup_mock_client_for_connection
    ApplicationConfig.stubs(:telegram_api_configured?).returns(true)
    TelegramMtproto::Client.stubs(:new).returns(@mock_mtproto_client)
    @mock_mtproto_client.stubs(:connect)
    @mock_mtproto_client.stubs(:disconnect)
    @mock_mtproto_client.stubs(:get_session_string).returns('{"session":"data"}')
    # Stub create_client method to set up the client properly
    @client.stubs(:create_client).returns(true)
    # Manually set the client instance variable
    @client.instance_variable_set(:@client, @mock_mtproto_client)
  end
end
