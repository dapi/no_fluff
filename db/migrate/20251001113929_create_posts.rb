class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.references :channel, null: false, foreign_key: true
      t.bigint :telegram_message_id, null: false
      t.text :text
      t.jsonb :media_urls, default: []
      t.datetime :published_at, null: false
      t.boolean :is_important, default: false
      t.float :importance_score, default: 0.0
      t.boolean :is_ad, default: false
      t.boolean :is_fluff, default: false
      t.bigint :is_duplicate_of
      t.jsonb :topics, default: []
      t.text :classification_reasoning
      t.float :confidence, default: 0.0
      t.jsonb :classification_data, default: {}
      t.bigint :classified_by_session_id

      t.timestamps
    end

    # Индексы
    add_index :posts, [ :channel_id, :published_at ]
    add_index :posts, :telegram_message_id
    add_index :posts, :is_important
    add_index :posts, :is_ad
    add_index :posts, :is_fluff
    add_index :posts, :is_duplicate_of
    add_index :posts, :importance_score
    add_index :posts, :published_at
    add_index :posts, :topics, using: :gin
    add_index :posts, [ :channel_id, :telegram_message_id ], unique: true
  end
end
