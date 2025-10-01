class AddFieldsToChats < ActiveRecord::Migration[8.0]
  def change
    add_reference :chats, :telegram_user, null: false, foreign_key: true, index: true
    add_column :chats, :session_type, :integer, default: 0, null: false
    add_column :chats, :status, :integer, default: 0, null: false
    add_column :chats, :context, :jsonb, default: {}
    add_column :chats, :last_activity_at, :datetime
    add_column :chats, :messages_count, :integer, default: 0

    # Индексы
    add_index :chats, [ :telegram_user_id, :session_type ]
    add_index :chats, :status
    add_index :chats, :last_activity_at
    add_index :chats, :context, using: :gin
  end
end
