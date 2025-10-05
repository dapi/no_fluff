class NotifyChannelSubscribersJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(channel)
    # Находим всех подписчиков канала с активными подписками
    subscribers = channel.telegram_users.joins(:subscriptions).where(subscriptions: { active: true })

    subscribers.each do |user|
      SendChannelDeactivationNotificationJob.perform_later(channel, user)
    end
  end
end