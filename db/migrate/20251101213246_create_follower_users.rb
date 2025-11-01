class CreateFollowerUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :follower_users do |t|
      t.string :phone_number, null: false
      t.string :username
      t.string :first_name
      t.string :last_name
      t.integer :auth_status, default: 0, null: false
      t.text :session_string_encrypted
      t.text :api_credentials_encrypted
      t.jsonb :device_info, default: {}
      t.integer :daily_joins_limit, default: 50, null: false
      t.integer :daily_joins_count, default: 0, null: false
      t.date :last_reset_date
      t.integer :max_channels, default: 400, null: false
      t.integer :channels_count, default: 0, null: false
      t.decimal :workload_score, precision: 5, scale: 2, default: 0.0, null: false
      t.decimal :health_score, precision: 5, scale: 2, default: 100.0, null: false
      t.integer :consecutive_errors, default: 0, null: false
      t.integer :priority, default: 0, null: false
      t.string :specialization
      t.timestamp :last_authorized_at
      t.timestamp :last_successful_join
      t.timestamp :last_activity_at

      t.timestamps
    end

    # Indexes
    add_index :follower_users, :phone_number, unique: true
    add_index :follower_users, :username, unique: true
    add_index :follower_users, :auth_status
    add_index :follower_users, :priority
    add_index :follower_users, :last_activity_at
    add_index :follower_users, :health_score
    add_index :follower_users, :daily_joins_count
    add_index :follower_users, :channels_count
    add_index :follower_users, :specialization
  end
end
