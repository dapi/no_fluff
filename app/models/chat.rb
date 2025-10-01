class Chat < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :model, optional: true

  acts_as_chat
end
