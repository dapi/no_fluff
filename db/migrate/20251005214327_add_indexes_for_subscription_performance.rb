# frozen_string_literal: true

class AddIndexesForSubscriptionPerformance < ActiveRecord::Migration[8.0]
  def up
    # Index for active subscriptions query optimization
    # This optimizes active subscriptions counting for user.channels_count
    unless index_exists?(:subscriptions, [ :telegram_user_id, :active ], name: 'index_subscriptions_on_user_and_active')
      add_index :subscriptions, [ :telegram_user_id, :active ], name: 'index_subscriptions_on_user_and_active'
    end

    # Note: Other indexes we need already exist:
    # - index_subscriptions_on_telegram_user_id (for channels_count)
    # - index_subscriptions_on_telegram_user_id_and_channel_id (for find_by)
    # - index_telegram_users_on_is_premium (for premium scope)
    # - index_telegram_users_on_is_admin (for admins scope)
  end

  def down
    # Remove only the index we created
    remove_index :subscriptions, name: 'index_subscriptions_on_user_and_active' if index_exists?(:subscriptions, [ :telegram_user_id, :active ], name: 'index_subscriptions_on_user_and_active')
  end
end
