class AddFollowerUserToChannels < ActiveRecord::Migration[8.0]
  def change
    # Add follower user reference (nullable for existing channels)
    add_reference :channels, :follower_user, null: true, foreign_key: true

    # Add new fields for follower user management
    add_column :channels, :user_access_status, :integer, default: 0, null: false
    add_column :channels, :assignment_status, :integer, default: 0, null: false
    add_column :channels, :assigned_at, :timestamp
    add_column :channels, :last_activity_at, :timestamp
    add_column :channels, :activity_score, :decimal, precision: 5, scale: 2, default: 0.0, null: false

    # Add indexes for optimization (follower_user_id index already created by foreign_key)
    add_index :channels, :user_access_status
    add_index :channels, :assignment_status
    add_index :channels, :activity_score
    add_index :channels, :last_activity_at
  end
end
