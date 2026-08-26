class AddTelegramIdToTelegramUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :telegram_users, :telegram_id, :bigint
    add_index :telegram_users, :telegram_id, unique: true
  end
end
