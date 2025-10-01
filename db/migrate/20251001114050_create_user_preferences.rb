class CreateUserPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :user_preferences do |t|
      t.references :telegram_user, null: false, foreign_key: true
      t.jsonb :topic_weights, default: {}
      t.jsonb :channel_weights, default: {}
      t.float :adjusted_importance_threshold, default: 50.0
      t.jsonb :personalization_data, default: {}
      t.datetime :last_updated_at

      t.timestamps
    end

    # Индексы (telegram_user_id индекс уже создается автоматически для references)
    add_index :user_preferences, :last_updated_at
    add_index :user_preferences, :topic_weights, using: :gin
    add_index :user_preferences, :channel_weights, using: :gin
  end
end
