class CreatePostClassifications < ActiveRecord::Migration[8.0]
  def change
    create_table :post_classifications do |t|
      t.references :post, null: false, foreign_key: true
      t.references :telegram_user, null: false, foreign_key: true
      t.references :chat, foreign_key: true
      t.float :importance_score, default: 0.0
      t.boolean :is_relevant, default: false
      t.text :reasoning
      t.float :confidence, default: 0.0
      t.jsonb :classification_data, default: {}

      t.timestamps
    end

    # Индексы (индексы для references создаются автоматически)
    add_index :post_classifications, [ :telegram_user_id, :post_id ], unique: true
    add_index :post_classifications, :is_relevant
    add_index :post_classifications, :importance_score
  end
end
