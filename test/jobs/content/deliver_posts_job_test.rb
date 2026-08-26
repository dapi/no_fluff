# frozen_string_literal: true

require 'test_helper'

class Content::DeliverPostsJobTest < ActiveJob::TestCase
  test 'delivers imported MTProto posts as bot messages with source links' do
    user = telegram_users(:one)
    post = posts(:one)
    bot = mock('bot')
    bot.expects(:send_message).with do |arguments|
      arguments[:chat_id] == user.telegram_id &&
        arguments[:text].include?('MyText') &&
        arguments[:text].include?('https://t.me/test_channel_one/12345')
    end.returns('ok' => true)
    Telegram.stubs(:bot).returns(bot)

    Content::DeliverPostsJob.perform_now(user.id, [ post.id ])
  end
end
