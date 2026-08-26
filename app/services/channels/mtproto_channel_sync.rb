# frozen_string_literal: true

module Channels
  class MtprotoChannelSync
    DEFAULT_LIMIT = 50

    def initialize(channel:, follower_user: nil, client: nil, limit: DEFAULT_LIMIT)
      @channel = channel
      @follower_user = follower_user
      @client = client
      @limit = [ [ Integer(limit), 1 ].max, 100 ].min
    end

    def call
      @channel.with_lock do
        assign_follower_user!
        return failure(:not_authorized) unless @follower_user.authorized? && @follower_user.session_string.present?

        join_result = joined? ? { success: true, channel: persisted_channel_data } : client.join_channel(@channel.username)
        return join_failed(join_result) unless join_result[:success]

        mark_joined!(join_result.fetch(:channel)) unless joined?
        read_result = client.read_channel_messages(channel: join_result.fetch(:channel), after_message_id: last_message_id, after_date: last_message_date, limit: @limit)
        return failure(read_result[:error_type], retry_after: read_result[:retry_after]) unless read_result[:success]

        post_ids = import_messages(read_result.fetch(:messages))
        post_ids.each { |post_id| Content::ProcessPostJob.perform_later(@channel.id, post_id) }
        { success: true, imported_post_ids: post_ids }
      end
    end

    private

    def client
      @client ||= Telegram::UserClientMtproto.new(@follower_user)
    end

    def assign_follower_user!
      @follower_user ||= @channel.follower_user || FollowerUser.next_available
      raise ActiveRecord::RecordInvalid, @channel unless @follower_user
      return if @channel.follower_user == @follower_user

      @channel.update!(follower_user: @follower_user, assignment_status: :assigned, assigned_at: Time.current, user_access_status: :joining)
      @follower_user.join_channel!
    end

    def joined?
      @channel.user_access_status == 'joined'
    end

    def persisted_channel_data
      { id: @channel.telegram_id, access_hash: nil, username: @channel.username, title: @channel.title }
    end

    def mark_joined!(data)
      @channel.update!(telegram_id: data.fetch(:id), username: data.fetch(:username), title: data[:title])
      @channel.mark_user_join_success
    end

    def import_messages(messages)
      messages.filter_map do |message|
        next if @channel.posts.exists?(telegram_message_id: message.fetch(:id))

        post = @channel.posts.create!(
          telegram_message_id: message.fetch(:id),
          text: message[:text],
          published_at: Time.iso8601(message.fetch(:date)),
          importance_score: 0,
          is_ad: false,
          is_fluff: false
        )
        @channel.update_column(:last_post_at, post.published_at) if @channel.last_post_at.nil? || post.published_at > @channel.last_post_at
        post.id
      end
    end

    def last_message_id
      @channel.posts.maximum(:telegram_message_id)
    end

    def last_message_date
      @channel.posts.maximum(:published_at)
    end

    def join_failed(result)
      @channel.mark_user_join_failed(result[:error_type].to_s)
      failure(result[:error_type], retry_after: result[:retry_after])
    end

    def failure(error_type, retry_after: nil)
      { success: false, error_type: error_type.to_sym, retry_after: }.compact
    end
  end
end
