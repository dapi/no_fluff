require 'test_helper'

class DeliveryTest < ActiveSupport::TestCase
  test 'database unique index allows only one delivery per Telegram user and post' do
    user = telegram_users(:one)
    post = posts(:one)

    Delivery.insert_all!([ { telegram_user_id: user.id, post_id: post.id, metadata: { telegram_message_id: 123 }, created_at: Time.current, updated_at: Time.current } ])

    assert_raises(ActiveRecord::RecordNotUnique) do
      Delivery.transaction(requires_new: true) do
        Delivery.insert_all!([ { telegram_user_id: user.id, post_id: post.id, metadata: {}, created_at: Time.current, updated_at: Time.current } ])
      end
    end
  end
end
