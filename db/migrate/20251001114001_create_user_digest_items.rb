class CreateUserDigestItems < ActiveRecord::Migration[8.0]
  def change
    create_table :user_digest_items do |t|
      t.references :user_digest, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :summary
      t.text :formatted_content
      t.boolean :is_original_content, default: true

      t.timestamps
    end

    # Индексы (индексы для references создаются автоматически)
    add_index :user_digest_items, [ :user_digest_id, :position ]
    add_index :user_digest_items, [ :user_digest_id, :post_id ], unique: true
  end
end
