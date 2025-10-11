# frozen_string_literal: true

module ChannelUpdatable
  extend ActiveSupport::Concern

  # Обновление времени успешного обновления
  def mark_as_successfully_updated
    update!(last_successful_update_at: Time.current)
  end

  # Проверка на актуальность канала
  def stale?(threshold = 24.hours)
    last_successful_update_at.blank? ||
    last_successful_update_at < threshold.ago
  end

  # Форматированное время обновления
  def last_update_formatted
    return I18n.t('channels.never_updated') if last_successful_update_at.blank?

    last_successful_update_at.strftime('%d %b %H:%M')
  end

  # Статус актуальности
  def freshness_status
    return 'never_updated' if last_successful_update_at.blank?
    return 'stale' if stale?
    'fresh'
  end
end
