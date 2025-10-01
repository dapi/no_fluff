class UserDigestItem < ApplicationRecord
  belongs_to :user_digest
  belongs_to :post
end
