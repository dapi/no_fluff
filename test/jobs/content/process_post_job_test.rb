# frozen_string_literal: true

require 'test_helper'

class Content::ProcessPostJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test 'enqueues delivery only after the classifier marks a joined-user post deliverable' do
    channel = channels(:one)
    follower = follower_users(:one)
    follower.update!(auth_status: :authorized, session_string: 'session', health_score: 90)
    channel.update!(follower_user: follower, user_access_status: :joined)
    post = channel.posts.create!(telegram_message_id: 90_001, text: 'useful', published_at: Time.current, importance_score: 0, is_ad: false, is_fluff: false)

    classifier = Object.new
    classifier.define_singleton_method(:classify) { |_| { deliverable: true, importance_score: 80, confidence: 0.9 } }
    Content::PostClassifier.stub(:new, classifier) do
      assert_enqueued_jobs channel.telegram_users.joins(:subscriptions).where(subscriptions: { active: true }).count, only: Content::DeliverPostsJob do
        Content::ProcessPostJob.perform_now(channel.id, post.id)
      end
    end
    assert_equal true, post.reload.is_important
    assert_equal 80, post.importance_score
  end

  test 'does not enqueue delivery when classification rejects the post' do
    channel = channels(:one)
    follower = follower_users(:one)
    follower.update!(auth_status: :authorized, session_string: 'session', health_score: 90)
    channel.update!(follower_user: follower, user_access_status: :joined)
    post = channel.posts.create!(telegram_message_id: 90_002, text: 'fluff', published_at: Time.current, importance_score: 0, is_ad: false, is_fluff: false)
    classifier = Object.new
    classifier.define_singleton_method(:classify) { |_| { deliverable: false, importance_score: 1, confidence: 0.9 } }

    Content::PostClassifier.stub(:new, classifier) do
      assert_no_enqueued_jobs only: Content::DeliverPostsJob do
        Content::ProcessPostJob.perform_now(channel.id, post.id)
      end
    end
  end
end
