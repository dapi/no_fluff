class CreateTelegramUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_users do |t|
      t.string :username
      t.string :first_name
      t.string :last_name
      t.string :language_code, default: 'ru'
      t.boolean :is_premium, default: false
      t.boolean :is_bot, default: false
      t.integer :delivery_frequency, default: 3
      t.integer :content_format, default: 3
      t.integer :filter_strictness, default: 1
      t.string :timezone, default: 'UTC'

      t.timestamps
    end

    # Индексы
    add_index :telegram_users, :username, unique: true
    add_index :telegram_users, :is_premium
    add_index :telegram_users, :delivery_frequency
    add_index :telegram_users, :content_format
  end
end
