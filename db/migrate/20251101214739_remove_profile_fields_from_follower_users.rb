class RemoveProfileFieldsFromFollowerUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :follower_users, :first_name, :string
    remove_column :follower_users, :last_name, :string
    remove_column :follower_users, :username, :string
  end
end
