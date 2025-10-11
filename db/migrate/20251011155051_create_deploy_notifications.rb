class CreateDeployNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_notifications do |t|
      t.string :version, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    add_index :deploy_notifications, :version, unique: true
    add_index :deploy_notifications, :created_at
  end
end
