class CreateChannelUpdateLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_update_logs do |t|
      t.string :source, null: false, index: true
      t.text :message, null: false
      t.jsonb :data, default: {}, null: false
      t.string :status, null: false, index: true
      t.references :channel, null: true, foreign_key: true, index: true
      t.string :job_id, index: true
      t.integer :execution_time_ms

      t.timestamps
    end

    add_index :channel_update_logs, [:source, :created_at]
    add_index :channel_update_logs, [:channel_id, :created_at]
  end
end
