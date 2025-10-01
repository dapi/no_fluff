class CreateChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :channels do |t|
      t.bigint :telegram_id, null: false
      t.string :username, null: false
      t.string :title
      t.text :description
      t.integer :subscribers_count
      t.boolean :is_verified, default: false
      t.boolean :active, default: true
      t.datetime :last_post_at
      t.datetime :monitored_at

      t.timestamps
    end

    # Индексы
    add_index :channels, :telegram_id, unique: true
    add_index :channels, :username, unique: true
    add_index :channels, :active
    add_index :channels, :last_post_at
    add_index :channels, :monitored_at
  end
end
