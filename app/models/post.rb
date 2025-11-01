class Post < ApplicationRecord
  # Associations
  belongs_to :channel
  belongs_to :classified_by_session, class_name: 'Chat', optional: true
  has_many :user_digest_items, dependent: :destroy
  has_many :user_digests, through: :user_digest_items
  has_many :feedbacks, dependent: :destroy
  has_many :post_classifications, dependent: :destroy

  # Validations
  validates :telegram_message_id, presence: true, uniqueness: { scope: :channel_id }
  validates :published_at, presence: true
  validates :importance_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # Scopes
  scope :important, -> { where('importance_score >= ?', 60) }
  scope :not_important, -> { where('importance_score < ?', 60) }
  scope :not_ads, -> { where(is_ad: false) }
  scope :ads, -> { where(is_ad: true) }
  scope :not_fluff, -> { where(is_fluff: false) }
  scope :unique, -> { where(is_duplicate_of: nil) }
  scope :duplicates, -> { where.not(is_duplicate_of: nil) }
  scope :recent, -> { where('published_at > ?', 7.days.ago) }
  scope :by_published_at, -> { order(published_at: :desc) }
  scope :by_importance, -> { order(importance_score: :desc) }
  scope :for_channel, ->(channel) { where(channel: channel) }
  scope :by_topic, ->(topic) { where('topics @> ?', [ topic ].to_json) }
  scope :classified, -> { where.not(importance_score: 0) }
  scope :unclassified, -> { where(importance_score: 0) }

  # Methods
  def mark_as_duplicate!(duplicate_of_post)
    update(is_duplicate_of: duplicate_of_post.id)
  end

  def mark_as_important!
    update(is_important: true)
  end

  def mark_as_ad!
    update(is_ad: true)
  end

  def mark_as_fluff!
    update(is_fluff: true)
  end

  def has_media?
    media_urls.present? && media_urls.any?
  end

  def duplicate?
    is_duplicate_of.present?
  end

  def classified?
    importance_score > 0
  end
end
