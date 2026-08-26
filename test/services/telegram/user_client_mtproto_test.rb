# frozen_string_literal: true

require 'test_helper'

class Telegram::UserClientMtprotoTest < ActiveSupport::TestCase
  class FakeHelper
    attr_reader :requests
    def initialize(*responses) = (@responses = responses; @requests = [])
    def call(request) = (@requests << request; @responses.shift)
  end

  def setup
    @user = follower_users(:one)
    @user.update!(api_credentials: { api_id: 123_456, api_hash: 'api-hash-that-must-not-leak' })
  end

  test 'sends a code through the helper with a parsed SOCKS5 proxy' do
    helper = FakeHelper.new(success: true, phone_code_hash: 'pending-hash', session: 'pending-session')
    client = Telegram::UserClientMtproto.new(@user, helper:, proxy_url: 'socks5://proxy.example:1080')
    result = client.send_code
    assert_equal true, result[:success]
    assert_equal 'pending-hash', result[:phone_code_hash]
    assert_equal 'pending-session', result[:session]
    assert_equal({ operation: 'send_code', phone: @user.phone_number, api_id: 123_456,
                   api_hash: 'api-hash-that-must-not-leak', session: nil,
                   proxy: { scheme: 'socks5', host: 'proxy.example', port: 1080 } }, helper.requests.first)
  end

  test 'resends a code using the persisted pending session and hash' do
    helper = FakeHelper.new(success: true, phone_code_hash: 'next-hash', session: 'next-session', delivery_type: 'SentCodeTypeSms')
    client = Telegram::UserClientMtproto.new(@user, helper:)
    result = client.resend_code(phone_code_hash: 'persisted-hash', session: 'persisted-session')

    assert_equal true, result[:success]
    assert_equal 'next-hash', result[:phone_code_hash]
    assert_equal 'next-session', result[:session]
    assert_equal 'SentCodeTypeSms', result[:delivery_type]
    assert_equal 'resend_code', helper.requests.first[:operation]
    assert_equal 'persisted-hash', helper.requests.first[:phone_code_hash]
    assert_equal 'persisted-session', helper.requests.first[:session]
  end

  test 'confirms code using the persisted pending session and hash' do
    helper = FakeHelper.new(success: true, session: 'authorized-session', user: { id: 42, username: 'follower' })
    client = Telegram::UserClientMtproto.new(@user, helper:)
    result = client.confirm_code(code: '12345', phone_code_hash: 'persisted-hash', session: 'persisted-session')
    assert_equal true, result[:success]
    assert_equal 'authorized-session', result[:session]
    assert_equal '12345', helper.requests.first[:code]
    assert_equal 'persisted-hash', helper.requests.first[:phone_code_hash]
    assert_equal 'persisted-session', helper.requests.first[:session]
  end

  test 'returns a typed needs_password result without exposing the code' do
    helper = FakeHelper.new(success: false, error_type: 'needs_password')
    result = Telegram::UserClientMtproto.new(@user, helper:).confirm_code(code: 'secret-code', phone_code_hash: 'hash', session: 'session')
    assert_equal({ success: false, error: 'Two-factor authentication required', error_type: :needs_password }, result)
  end

  test 'restores an authorized session and gets the current user' do
    helper = FakeHelper.new(success: true, user: { id: 42, username: 'follower' })
    result = Telegram::UserClientMtproto.new(@user, helper:).get_me('authorized-session')
    assert_equal true, result[:success]
    assert_equal 'authorized-session', helper.requests.first[:session]
    assert_equal 'get_me', helper.requests.first[:operation]
  end

  test 'rejects invalid proxy URLs' do
    assert_raises(ArgumentError) { Telegram::UserClientMtproto.new(@user, helper: FakeHelper.new, proxy_url: 'http://proxy.example:1080') }
  end

  test 'sanitizes helper failures' do
    helper = FakeHelper.new(success: false, error_type: 'network_error', error: 'pending-hash api-hash-that-must-not-leak')
    result = Telegram::UserClientMtproto.new(@user, helper:).send_code
    assert_equal false, result[:success]
    assert_equal 'Telegram authorization request failed', result[:error]
    assert_equal :network_error, result[:error_type]
  end

  test 'resolves, joins, and reads through a freshly restored encrypted session' do
    @user.update!(session_string: 'encrypted-session')
    helper = FakeHelper.new(
      { success: true, channel: { id: 99, access_hash: 'access-hash', username: 'public_news', title: 'Public news' } },
      { success: true, channel: { id: 99, access_hash: 'access-hash', username: 'public_news', title: 'Public news' } },
      { success: true, messages: [ { id: 17, date: '2026-08-26T10:00:00Z', text: 'hello', views: 12, forwards: 2 } ] }
    )
    client = Telegram::UserClientMtproto.new(@user, helper:, proxy_url: 'socks5://proxy.example:1080')

    assert_equal 99, client.resolve_channel('@public_news').dig(:channel, :id)
    assert_equal 'public_news', client.join_channel('public_news').dig(:channel, :username)
    assert_equal 17, client.read_channel_messages(channel: { id: 99, access_hash: 'access-hash', username: 'public_news' }, after_message_id: 16, after_date: Time.utc(2026, 8, 25), limit: 25).dig(:messages, 0, :id)

    assert_equal %w[resolve_channel join_channel read_channel_messages], helper.requests.map { |request| request[:operation] }
    helper.requests.each { |request| assert_equal 'encrypted-session', request[:session] }
    assert_equal({ scheme: 'socks5', host: 'proxy.example', port: 1080 }, helper.requests.first[:proxy])
    assert_equal '@public_news', helper.requests.first[:username]
    assert_equal 16, helper.requests.last[:after_message_id]
    assert_equal '2026-08-25T00:00:00Z', helper.requests.last[:after_date]
    assert_equal 25, helper.requests.last[:limit]
  end

  test 'returns sanitized flood wait metadata without helper error text' do
    helper = FakeHelper.new(success: false, error_type: 'flood_wait', retry_after: 120, error: 'session-string')
    result = Telegram::UserClientMtproto.new(@user, helper:).join_channel('public_news')

    assert_equal false, result[:success]
    assert_equal :flood_wait, result[:error_type]
    assert_equal 120, result[:retry_after]
    assert_equal 'Telegram channel request failed', result[:error]
    refute_includes result.to_s, 'session-string'
  end
end
