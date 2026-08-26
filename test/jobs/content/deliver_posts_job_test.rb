# frozen_string_literal: true

require 'test_helper'

class Content::DeliverPostsJobTest < ActiveJob::TestCase
  test 'delivers imported MTProto posts as bot messages with source links' do
    user = telegram_users(:one)
    user.update!(telegram_id: 42)
    post = posts(:one)
    bot = mock('bot')
    bot.expects(:send_message).with do |arguments|
      arguments[:chat_id] == 42 &&
        arguments[:text].include?('MyText') &&
        arguments[:text].include?('https://t.me/test_channel_one/12345')
    end.returns('ok' => true)
    Telegram.stubs(:bot).returns(bot)

    Content::DeliverPostsJob.perform_now(user.id, [ post.id ])
  end

  test 'records successful delivery and skips a duplicate job without another Bot API call' do
    user = telegram_users(:one)
    user.update!(telegram_id: 42)
    post = posts(:one)
    bot = mock('bot')
    bot.expects(:send_message).once.returns('ok' => true)
    Telegram.stubs(:bot).returns(bot)

    Content::DeliverPostsJob.perform_now(user.id, [ post.id ])
    Content::DeliverPostsJob.perform_now(user.id, [ post.id ])

    assert Delivery.exists?(telegram_user: user, post: post)
  end

  test 'does not record failed Bot API sends so the post can retry' do
    user = telegram_users(:one)
    user.update!(telegram_id: 42)
    post = posts(:one)
    bot = mock('bot')
    bot.expects(:send_message).returns('ok' => false, 'description' => 'temporary failure')
    Telegram.stubs(:bot).returns(bot)

    Content::DeliverPostsJob.perform_now(user.id, [ post.id ])

    assert_not Delivery.exists?(telegram_user: user, post: post)
  end
end
