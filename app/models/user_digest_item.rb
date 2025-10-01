class UserDigestItem < ApplicationRecord
  # Associations
  belongs_to :user_digest
  belongs_to :post

  # Validations
  validates :user_digest, presence: true
  validates :post, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :post_id, uniqueness: { scope: :user_digest_id }

  # Scopes
  scope :ordered, -> { order(position: :asc) }
  scope :for_digest, ->(digest) { where(user_digest: digest) }
  scope :original_content, -> { where(is_original_content: true) }
  scope :summarized, -> { where(is_original_content: false) }
end
