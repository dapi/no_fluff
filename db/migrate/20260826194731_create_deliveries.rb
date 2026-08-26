class CreateDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :deliveries do |t|
      t.references :telegram_user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps

      t.index [ :telegram_user_id, :post_id ], unique: true
    end
  end
end
