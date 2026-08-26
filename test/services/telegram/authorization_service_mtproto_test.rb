# frozen_string_literal: true

require 'test_helper'

class Telegram::AuthorizationServiceMtprotoTest < ActiveSupport::TestCase
  class FakeClient
    def initialize(send_result: nil, confirm_result: nil)
      @send_result = send_result
      @confirm_result = confirm_result
    end
    def send_code = @send_result
    def confirm_code(**) = @confirm_result
  end

  def setup
    @user = follower_users(:one)
    @service = Telegram::AuthorizationServiceMtproto.instance
  end

  test 'durably persists pending state and confirms after a new service process' do
    @service.client_factory = ->(_) { FakeClient.new(send_result: { success: true, phone_code_hash: 'hash', session: 'pending-session', expires_at: 10.minutes.from_now }) }
    assert_equal true, @service.start_authorization(@user)[:success]
    @user.reload
    assert_equal 'hash', @user.pending_phone_code_hash
    assert_equal 'pending-session', @user.pending_session_string

    restarted_service = Telegram::AuthorizationServiceMtproto.send(:new)
    restarted_service.client_factory = ->(_) { FakeClient.new(confirm_result: { success: true, session: 'authorized-session', user: { id: 42 } }) }
    assert_equal true, restarted_service.confirm_authorization(@user, '12345')[:success]
    @user.reload
    assert @user.authorized?
    assert_equal 'authorized-session', @user.session_string
    assert_nil @user.pending_phone_code_hash
    assert_nil @user.pending_session_string
  end

  test 'preserves pending authorization when Telegram requests 2FA' do
    @user.update!(pending_phone_code_hash: 'hash', pending_session_string: 'pending-session', authorization_expires_at: 5.minutes.from_now)
    @service.client_factory = ->(_) { FakeClient.new(confirm_result: { success: false, error_type: :needs_password, error: 'Two-factor authentication required' }) }
    result = @service.confirm_authorization(@user, '12345')
    assert_equal :needs_password, result[:error_type]
    assert_equal 'hash', @user.reload.pending_phone_code_hash
  end

  test 'does not return sensitive pending material in status' do
    @user.update!(pending_phone_code_hash: 'secret-hash', pending_session_string: 'secret-session', authorization_expires_at: 5.minutes.from_now)
    status = @service.authorization_status(@user)
    assert_equal true, status[:in_progress]
    refute_includes status.inspect, 'secret-hash'
    refute_includes status.inspect, 'secret-session'
  end
end
