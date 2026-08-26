class AddPendingAuthorizationToFollowerUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :follower_users, :pending_session_encrypted, :text
    add_column :follower_users, :pending_phone_code_hash_encrypted, :text
    add_column :follower_users, :authorization_expires_at, :datetime
  end
end
