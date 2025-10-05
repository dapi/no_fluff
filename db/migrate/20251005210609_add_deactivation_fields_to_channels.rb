class AddDeactivationFieldsToChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :channels, :deactivated_at, :datetime
    add_column :channels, :deactivation_reason, :string
  end
end
