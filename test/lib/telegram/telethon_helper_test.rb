# frozen_string_literal: true

require 'test_helper'

class Telegram::TelethonHelperTest < ActiveSupport::TestCase
  test 'uses JSON stdin and stdout' do
    status = Struct.new(:success?).new(true)
    runner = ->(_command, _input) { [ '{"success":true}', '', status ] }
    assert_equal({ success: true }, Telegram::TelethonHelper.new(command: [ 'python3', 'helper.py' ], runner:).call(operation: 'get_me'))
  end

  test 'does not include request data in subprocess errors' do
    status = Struct.new(:success?).new(false)
    helper = Telegram::TelethonHelper.new(runner: ->(_, _) { [ '', 'api-hash and session', status ] })
    error = assert_raises(Telegram::TelethonHelper::Error) { helper.call(api_hash: 'api-hash', session: 'session') }
    refute_includes error.message, 'api-hash'
    refute_includes error.message, 'session'
  end
end
