class CreateTelegramUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_users do |t|
      t.string :username
      t.string :first_name
      t.string :last_name
      t.string :language_code, default: 'ru'
      t.boolean :is_premium, default: false
      t.boolean :is_bot, default: false

      # Настройки
      t.integer :delivery_frequency, default: 3, null: false # daily
      t.integer :content_format, default: 3, null: false # combo
      t.integer :filter_strictness, default: 1, null: false # high
      t.string :timezone, default: 'UTC'

      t.timestamps
    end

    # Индексы для оптимизации запросов
    add_index :telegram_users, :username
    add_index :telegram_users, :is_premium
    add_index :telegram_users, :delivery_frequency
    add_index :telegram_users, :content_format
  end
end