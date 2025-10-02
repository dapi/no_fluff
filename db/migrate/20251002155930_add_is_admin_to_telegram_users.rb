class AddIsAdminToTelegramUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :telegram_users, :is_admin, :boolean, default: false, null: false
    add_index :telegram_users, :is_admin
  end
end
