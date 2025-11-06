# frozen_string_literal: true

require 'test_helper'

class TelegramCredentialsMtprotoTest < ActiveSupport::TestCase
  def setup
    @user = FollowerUser.new(
      phone_number: '+1234567890'
    )
  end

  def teardown
    @user = nil
  end

  # Test basic session methods
  test 'should create MTProto session with valid credentials' do
    mock_credentials = { api_id: 12345, api_hash: 'test_hash' }
    @user.stubs(:api_credentials).returns(mock_credentials)
    @user.class.stubs(:telegram_api_configured?).returns(true)
    @user.stubs(:session_string=).returns(true)

    session_data = @user.create_mtproto_session

    assert_not_nil session_data
    assert_equal 12345, session_data[:api_id]
    assert_equal 'test_hash', session_data[:api_hash]
    assert_equal '+1234567890', session_data[:phone_number]
    assert session_data[:created_at].present?
  end

  test 'should not create MTProto session without API configuration' do
    @user.class.stubs(:telegram_api_configured?).returns(false)

    session_data = @user.create_mtproto_session

    assert_nil session_data
  end

  test 'should restore valid MTProto session' do
    session_data = {
      'api_id' => 12345,
      'api_hash' => 'test_hash',
      'phone_number' => '+1234567890',
      'created_at' => Time.current.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)

    restored_session = @user.restore_mtproto_session

    assert_not_nil restored_session
    assert_equal 12345, restored_session['api_id']
    assert_equal 'test_hash', restored_session['api_hash']
    assert_equal '+1234567890', restored_session['phone_number']
  end

  test 'should return nil for invalid session string' do
    @user.stubs(:session_string).returns('invalid json')
    @user.stubs(:has_session?).returns(true)

    restored_session = @user.restore_mtproto_session

    assert_nil restored_session
  end

  test 'should save MTProto session data as hash' do
    session_data = {
      api_id: 12345,
      api_hash: 'test_hash',
      phone_number: '+1234567890'
    }
    @user.stubs(:session_string=).returns(true)

    result = @user.save_mtproto_session(session_data)

    assert result
  end

  test 'should save MTProto session data as string' do
    session_string = '{"api_id":12345,"api_hash":"test_hash","phone_number":"+1234567890"}'
    @user.stubs(:session_string=).returns(true)

    result = @user.save_mtproto_session(session_string)

    assert result
  end

  test 'should not save empty session data' do
    result = @user.save_mtproto_session(nil)
    assert_not result

    result = @user.save_mtproto_session('')
    assert_not result
  end

  test 'should clear MTProto session' do
    @user.stubs(:session_string=).returns(nil)

    @user.clear_mtproto_session

    # Test passes if no exception is raised
    assert true
  end

  # Test session validation methods
  test 'should detect valid MTProto session' do
    session_data = {
      'api_id' => 12345,
      'api_hash' => 'test_hash',
      'phone_number' => '+1234567890',
      'created_at' => Time.current.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)

    assert @user.has_valid_mtproto_session?
  end

  test 'should detect invalid MTProto session missing required fields' do
    session_data = {
      'api_id' => 12345,
      # missing api_hash and phone_number
      'created_at' => Time.current.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)

    assert_not @user.has_valid_mtproto_session?
  end

  test 'should detect invalid MTProto session with malformed JSON' do
    @user.stubs(:session_string).returns('invalid json')
    @user.stubs(:has_session?).returns(true)

    assert_not @user.has_valid_mtproto_session?
  end

  test 'should get session creation time' do
    created_time = Time.current
    session_data = {
      'api_id' => 12345,
      'api_hash' => 'test_hash',
      'phone_number' => '+1234567890',
      'created_at' => created_time.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)

    session_created_at = @user.session_created_at

    assert_not_nil session_created_at
    assert_in_delta created_time.to_i, session_created_at.to_i, 1
  end

  test 'should return nil for session creation time when no session exists' do
    @user.stubs(:has_session?).returns(false)

    session_created_at = @user.session_created_at

    assert_nil session_created_at
  end

  test 'should detect expired session' do
    old_time = 25.hours.ago
    session_data = {
      'api_id' => 12345,
      'api_hash' => 'test_hash',
      'phone_number' => '+1234567890',
      'created_at' => old_time.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)

    assert @user.session_expired?
  end

  test 'should detect valid session (not expired)' do
    recent_time = 1.hour.ago
    session_data = {
      'api_id' => 12345,
      'api_hash' => 'test_hash',
      'phone_number' => '+1234567890',
      'created_at' => recent_time.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)

    assert_not @user.session_expired?
  end

  test 'should refresh expired session' do
    old_time = 25.hours.ago
    session_data = {
      'api_id' => 12345,
      'api_hash' => 'test_hash',
      'phone_number' => '+1234567890',
      'created_at' => old_time.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)
    @user.class.stubs(:telegram_api_configured?).returns(true)
    @user.stubs(:api_credentials).returns({ api_id: 12345, api_hash: 'test_hash' })
    @user.stubs(:clear_mtproto_session).returns(true)
    @user.stubs(:create_mtproto_session).returns({ 'api_id' => 12345, 'api_hash' => 'test_hash', 'phone_number' => '+1234567890', 'created_at' => Time.current })

    result = @user.refresh_session_if_needed

    assert_not_nil result
    assert_equal 12345, result['api_id']
  end

  test 'should refresh invalid session' do
    session_data = {
      'api_id' => 12345,
      # missing required fields
      'created_at' => Time.current.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)
    @user.class.stubs(:telegram_api_configured?).returns(true)
    @user.stubs(:api_credentials).returns({ api_id: 12345, api_hash: 'test_hash' })
    @user.stubs(:clear_mtproto_session).returns(true)
    @user.stubs(:create_mtproto_session).returns({ 'api_id' => 12345, 'api_hash' => 'test_hash', 'phone_number' => '+1234567890', 'created_at' => Time.current })

    result = @user.refresh_session_if_needed

    assert_not_nil result
    assert_equal 12345, result['api_id']
  end

  test 'should restore valid existing session' do
    recent_time = 1.hour.ago
    session_data = {
      'api_id' => 12345,
      'api_hash' => 'test_hash',
      'phone_number' => '+1234567890',
      'created_at' => recent_time.iso8601
    }
    @user.stubs(:session_string).returns(session_data.to_json)
    @user.stubs(:has_session?).returns(true)

    result = @user.refresh_session_if_needed

    assert_not_nil result
    assert_equal 12345, result['api_id']
  end

  # Test legacy TDLib methods (backward compatibility)
  test 'legacy TDLib methods should call MTProto equivalents with warning' do
    @user.class.stubs(:telegram_api_configured?).returns(true)
    @user.stubs(:api_credentials).returns({ api_id: 12345, api_hash: 'test_hash' })
    @user.stubs(:session_string).returns('{"api_id":12345}')
    @user.stubs(:has_session?).returns(true)
    @user.stubs(:session_string=).returns(true)

    Rails.logger.expects(:warn).with('create_tdlib_session is deprecated. Use create_mtproto_session instead.')
    @user.create_tdlib_session

    Rails.logger.expects(:warn).with('restore_tdlib_session is deprecated. Use restore_mtproto_session instead.')
    @user.restore_tdlib_session

    Rails.logger.expects(:warn).with('save_tdlib_session is deprecated. Use save_mtproto_session instead.')
    @user.save_tdlib_session({ test: 'data' })

    Rails.logger.expects(:warn).with('clear_tdlib_session is deprecated. Use clear_mtproto_session instead.')
    @user.clear_tdlib_session

    # Test passes if no exceptions are raised
    assert true
  end

  # Test error handling
  test 'should handle save_mtproto_session errors gracefully' do
    @user.stubs(:session_string=).raises(StandardError.new('Database error'))

    result = @user.save_mtproto_session({ test: 'data' })

    assert_not result
  end
end
