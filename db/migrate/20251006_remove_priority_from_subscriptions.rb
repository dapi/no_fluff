class RemovePriorityFromSubscriptions < ActiveRecord::Migration[8.0]
  def up
    # Удаляем колонку priority
    remove_column :subscriptions, :priority

    # Удаляем индекс по полю priority если он существует
    remove_index :subscriptions, :priority
  end

  def down
    add_column :subscriptions, :priority, :integer, default: 5, null: false
    add_index :subscriptions, :priority
  end
end
