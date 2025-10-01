class CreateUserDigests < ActiveRecord::Migration[8.0]
  def change
    create_table :user_digests do |t|
      t.references :telegram_user, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :scheduled_for
      t.datetime :sent_at
      t.integer :posts_analyzed_count, default: 0
      t.integer :posts_included_count, default: 0
      t.text :content
      t.jsonb :format_settings, default: {}
      t.string :telegram_message_id
      t.text :error_message

      t.timestamps
    end

    # Индексы
    add_index :user_digests, :status
    add_index :user_digests, :scheduled_for
    add_index :user_digests, :sent_at
    add_index :user_digests, [ :telegram_user_id, :status ]
    add_index :user_digests, [ :telegram_user_id, :scheduled_for ]
  end
end
