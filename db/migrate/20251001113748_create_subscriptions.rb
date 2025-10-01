class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :telegram_user, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.integer :priority, default: 5, null: false
      t.boolean :active, default: true, null: false
      t.datetime :last_digest_sent_at
      t.jsonb :settings, default: {}

      t.timestamps
    end

    # Индексы
    add_index :subscriptions, [ :telegram_user_id, :channel_id ], unique: true
    add_index :subscriptions, :active
    add_index :subscriptions, :priority
    add_index :subscriptions, :last_digest_sent_at
  end
end
