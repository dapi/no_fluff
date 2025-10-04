require 'test_helper'

class FeedbackTest < ActiveSupport::TestCase
  test 'should load fixture' do
    feedback = feedbacks(:one)
    assert_not_nil feedback
  end

  test 'loaded fixture should be valid' do
    feedback = feedbacks(:one)
    assert feedback.valid?
  end

  test 'should have telegram_user association' do
    feedback = feedbacks(:one)
    assert_not_nil feedback.telegram_user
    assert_instance_of TelegramUser, feedback.telegram_user
  end

  test 'should have post association' do
    feedback = feedbacks(:one)
    assert_not_nil feedback.post
    assert_instance_of Post, feedback.post
  end
end
