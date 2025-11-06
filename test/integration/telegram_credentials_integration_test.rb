# frozen_string_literal: true

require 'test_helper'

class TelegramCredentialsIntegrationTest < ActiveSupport::TestCase
  def setup
    @user = FollowerUser.new(
      phone_number: '+1234567890'
    )
  end

  def teardown
    @user = nil
  end

  test 'should create and restore MTProto session integration test' do
    # Mock ApplicationConfig to provide API credentials
    mock_credentials = { api_id: 12345, api_hash: 'test_hash' }
    ApplicationConfig.stubs(:telegram_api_credentials).returns(mock_credentials)
    ApplicationConfig.stubs(:telegram_api_configured?).returns(true)

    # Create session
    session_data = @user.create_mtproto_session

    assert_not_nil session_data
    assert_equal 12345, session_data[:api_id]
    assert_equal 'test_hash', session_data[:api_hash]
    assert_equal '+1234567890', session_data[:phone_number]
    assert session_data[:created_at].present?

    # Check that session string was set
    assert @user.has_session?

    # Restore session
    restored_session = @user.restore_mtproto_session

    assert_not_nil restored_session
    assert_equal 12345, restored_session['api_id']
    assert_equal 'test_hash', restored_session['api_hash']
    assert_equal '+1234567890', restored_session['phone_number']
  end

  test 'should validate MTProto session structure' do
    mock_credentials = { api_id: 12345, api_hash: 'test_hash' }
    ApplicationConfig.stubs(:telegram_api_credentials).returns(mock_credentials)
    ApplicationConfig.stubs(:telegram_api_configured?).returns(true)

    # Create valid session
    @user.create_mtproto_session

    assert @user.has_valid_mtproto_session?
    assert_not @user.session_expired?

    # Test session creation time
    created_at = @user.session_created_at
    assert_not_nil created_at
    assert_in_delta Time.current.to_i, created_at.to_i, 1
  end
end
