class CreateFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :feedbacks do |t|
      t.references :telegram_user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.integer :sentiment, default: 0, null: false
      t.text :comment
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Индексы (индексы для references создаются автоматически)
    add_index :feedbacks, [ :telegram_user_id, :post_id ], unique: true
    add_index :feedbacks, :sentiment
    add_index :feedbacks, :created_at
  end
end
