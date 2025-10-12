class AddBotJoinFieldsToChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :channels, :bot_join_status, :string, default: 'not_joined', null: false
    add_column :channels, :bot_join_error, :text
    add_column :channels, :bot_join_at, :datetime

    add_index :channels, :bot_join_status
  end
end
