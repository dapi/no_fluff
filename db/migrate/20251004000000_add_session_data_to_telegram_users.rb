# frozen_string_literal: true

class AddSessionDataToTelegramUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :telegram_users, :session_data, :jsonb, default: {}

    # Добавляем индекс для быстрых запросов к данным сессии
    add_index :telegram_users, :session_data, using: :gin
  end
end