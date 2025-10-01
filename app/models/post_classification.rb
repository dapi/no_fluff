class PostClassification < ApplicationRecord
  belongs_to :post
  belongs_to :telegram_user
  belongs_to :chat
end
