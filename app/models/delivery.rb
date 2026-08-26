class Delivery < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :post

  validates :post_id, uniqueness: { scope: :telegram_user_id }
end
