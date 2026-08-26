# frozen_string_literal: true

require 'test_helper'

class JobsSupervisorTest < ActiveSupport::TestCase
  test 'starts one queue worker and one bot poller and relays signals' do
    script = File.read(Rails.root.join('bin/jobs-supervisor'))
    assert_includes script, '"./bin/jobs"'
    assert_includes script, 'bundle exec rake telegram:bot:poller'
    assert_includes script, "trap 'terminate_children' TERM INT"
    assert_includes script, 'wait -n'
  end
end
