class RemoveActiveFromChannels < ActiveRecord::Migration[8.0]
  def change
    remove_column :channels, :active
  end
end
