require 'test_helper'

class DeployNotificationTest < ActiveSupport::TestCase
  test 'should create deploy notification' do
    notification = DeployNotification.create!(
      version: '1.0.0',
      metadata: { deployed_at: Time.current.iso8601 }
    )
    assert notification.valid?
    assert_equal '1.0.0', notification.version
  end

  test 'should enforce version uniqueness' do
    DeployNotification.create!(version: '1.0.0', metadata: {})

    duplicate = DeployNotification.new(version: '1.0.0', metadata: {})
    assert_not duplicate.valid?
  end

  test 'should use find_or_create_by correctly' do
    notification1 = DeployNotification.find_or_create_by(version: '1.0.0') { |r| r.metadata = {} }
    notification2 = DeployNotification.find_or_create_by(version: '1.0.0') { |r| r.metadata = {} }

    assert_equal notification1.id, notification2.id
  end
end
