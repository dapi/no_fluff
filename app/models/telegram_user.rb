class TelegramUser < ApplicationRecord
  # Associations
  has_many :subscriptions, dependent: :destroy
  has_many :channels, through: :subscriptions
  has_many :user_digests, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_one :user_preference, dependent: :destroy

  # Enums
  enum :delivery_frequency, {
    real_time: 0,
    three_times_daily: 1,
    twice_daily: 2,
    once_daily: 3,
    every_few_days: 4,
    weekly: 5,
    on_demand: 6
  }, prefix: true

  enum :content_format, {
    original: 0,
    summaries: 1,
    unified_digest: 2,
    combo: 3,
    headlines: 4
  }, prefix: true

  enum :filter_strictness, {
    ultra: 0,
    high: 1,
    medium: 2,
    low: 3,
    smart: 4
  }, prefix: true

  # Validations
  validates :username, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :language_code, presence: true

  # Scopes
  scope :active_telegram_users, -> { where.not(subscriptions: { id: nil }).distinct }
  scope :by_delivery_time, ->(time) { where(delivery_frequency: time) }
  scope :premium, -> { where(is_premium: true) }
  scope :non_bots, -> { where(is_bot: false) }

  # Используем ID записи как telegram_id для Telegram API
  alias_attribute :telegram_id, :id
end
