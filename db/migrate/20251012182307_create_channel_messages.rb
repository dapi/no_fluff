class CreateChannelMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_messages do |t|
      t.bigint "message_id", null: false
      t.bigint "channel_id", null: false
      t.string "channel_username"
      t.string "channel_title"
      t.bigint "sender_id"
      t.string "sender_username"
      t.string "sender_first_name"
      t.string "sender_last_name"
      t.text "content"
      t.string "message_type"
      t.jsonb "raw_data"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false

      t.index [ "channel_id" ], name: "index_channel_messages_on_channel_id"
      t.index [ "message_id", "channel_id" ], name: "index_channel_messages_on_unique", unique: true
    end
  end
end
