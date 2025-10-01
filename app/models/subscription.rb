class Subscription < ApplicationRecord
  belongs_to :telegram_user
  belongs_to :channel
end
