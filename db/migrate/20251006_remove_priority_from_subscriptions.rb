class RemovePriorityFromSubscriptions < ActiveRecord::Migration[8.0]
  def up
    # Проверяем наличие таблицы перед удалением колонки
    if table_exists?(:subscriptions)
      # Удаляем колонку priority
      remove_column :subscriptions, :priority if column_exists?(:subscriptions, :priority)

      # Удаляем индекс по полю priority если он существует
      remove_index :subscriptions, :priority if index_exists?(:subscriptions, :priority)
    end
  end

  def down
    # Восстанавливаем колонку priority для возможности отката миграции
    # только если таблица существует и колонки еще нет
    if table_exists?(:subscriptions) && !column_exists?(:subscriptions, :priority)
      add_column :subscriptions, :priority, :integer, default: 5, null: false
      add_index :subscriptions, :priority
    end
  end
end
