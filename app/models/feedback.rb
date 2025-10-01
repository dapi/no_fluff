class Feedback < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :post
end
