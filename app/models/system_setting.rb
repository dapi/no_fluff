class SystemSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  # validates :value, presence: true - removed to allow nil values

  scope :by_key, ->(key) { where(key: key) }

  def self.get(key, default = nil)
    setting = find_by(key: key)
    setting ? setting.value : default
  end

  def self.set(key, value, description = nil)
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.description = description if description.present?
    setting.save!
    setting
  rescue ActiveRecord::RecordInvalid => e
    # Re-raise with more descriptive message
    raise ActiveRecord::RecordInvalid, e.record
  end
end
