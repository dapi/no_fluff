class AddLastSuccessfulUpdateAtToChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :channels, :last_successful_update_at, :timestamp, null: true
    add_index :channels, :last_successful_update_at
  end
end
