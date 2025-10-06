module Telegram
  class ChannelsListService
    include ActionView::Helpers::DateHelper

    attr_reader :bot, :current_user

    def initialize(bot, current_user)
      @bot = bot
      @current_user = current_user
    end

    def execute
      return access_denied_response unless admin_access_allowed?

      channels = fetch_channels_with_stats

      if channels.any?
        success_response(channels)
      else
        empty_response
      end
    end

    private

    def admin_access_allowed?
      current_user&.is_admin? || false
    end

    def fetch_channels_with_stats
      Channel.left_joins(:subscriptions)
            .select('channels.*, COUNT(subscriptions.id) as subscribers_count')
            .group('channels.id')
            .order('COUNT(subscriptions.id) DESC, channels.username ASC')
    end

    def success_response(channels)
      message = build_channels_list(channels)

      {
        status: :success,
        message: message
      }
    end

    def access_denied_response
      {
        status: :access_denied,
        message: I18n.t('telegram_bot.channels.list.access_denied')
      }
    end

    def empty_response
      {
        status: :empty,
        message: I18n.t('telegram_bot.channels.list.no_channels')
      }
    end

    def build_channels_list(channels)
      total_count = channels.size
      active_count = channels.count { |ch| ch.active? }

      message = I18n.t('telegram_bot.channels.list.title') + "\n\n"
      message += I18n.t('telegram_bot.channels.list.total_channels', count: total_count) + "\n"
      message += I18n.t('telegram_bot.channels.list.active_channels', count: active_count) + "\n\n"

      channels.each do |channel|
        message += format_channel_line(channel) + "\n\n"
      end

      message
    end

    def format_channel_line(channel)
      verification_icon = channel.is_verified ? '✅' : '⭕'
      status_icon = channel.active? ? '🟢' : '🔴'

      # Формируем информацию о подписчиках
      subscribers_text = I18n.t('telegram_bot.channels.list.subscribers_count',
                               count: channel.subscribers_count)

      # Формируем информацию о последнем посте
      if channel.last_post_at
        last_post_text = I18n.t('telegram_bot.channels.list.last_post.recently',
                               time: time_ago_in_words(channel.last_post_at))
      else
        last_post_text = I18n.t('telegram_bot.channels.list.last_post.never')
      end

      # Формируем статус
      status_text = channel.active? ? I18n.t('telegram_bot.channels.list.status.active')
                                   : I18n.t('telegram_bot.channels.list.status.inactive')

      # Собираем все вместе
      channel_line = "#{verification_icon} @#{channel.username} — #{subscribers_text}"
      channel_line += "\n#{status_icon} #{status_text} • #{last_post_text}"

      channel_line
    end
  end
end