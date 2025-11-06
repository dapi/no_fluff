class AddUsernameToFollowerUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :follower_users, :username, :string
  end
end
