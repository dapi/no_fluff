class DeployNotification < ApplicationRecord
  validates :version, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_version, ->(version) { find_by(version: version) }

  after_commit :notify_admins, on: :create

  private

  def notify_admins
    DeployNotificationJob.perform_later(version, created_at, metadata)
  end
end
