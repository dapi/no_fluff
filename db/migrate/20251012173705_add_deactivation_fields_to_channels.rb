class AddDeactivationFieldsToChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :channels, :deactivated_at, :timestamp
    add_column :channels, :deactivation_reason, :string

    # Add indexes for performance
    add_index :channels, :deactivated_at
  end
end
