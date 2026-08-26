# frozen_string_literal: true

require 'test_helper'
require 'yaml'

class RecurringTasksTest < ActiveSupport::TestCase
  test 'all configured recurring job classes exist' do
    recurring = YAML.safe_load_file(Rails.root.join('config/recurring.yml'), aliases: true)
    class_names = recurring.values.compact.flat_map(&:values).filter_map { |task| task['class'] }

    missing = class_names.reject { |class_name| class_name.safe_constantize }

    assert_empty missing, "Missing recurring job classes: #{missing.uniq.join(', ')}"
  end

  test 'production recurring sync uses the channels queue' do
    recurring = YAML.safe_load_file(Rails.root.join('config/recurring.yml'), aliases: true)
    task = recurring.fetch('production').fetch('recurring_mtproto_channel_sync')

    assert_equal 'Channels::RecurringMtprotoChannelSyncJob', task.fetch('class')
    assert_equal 'channels', task.fetch('queue')
  end
end
