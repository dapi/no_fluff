require 'test_helper'

class PostClassificationTest < ActiveSupport::TestCase
  test 'should load fixture' do
    post_classification = post_classifications(:one)
    assert_not_nil post_classification
  end

  test 'loaded fixture should be valid' do
    post_classification = post_classifications(:one)
    assert post_classification.valid?
  end

  test 'should have post association' do
    post_classification = post_classifications(:one)
    assert_not_nil post_classification.post
    assert_instance_of Post, post_classification.post
  end

  test 'should have telegram_user association' do
    post_classification = post_classifications(:one)
    assert_not_nil post_classification.telegram_user
    assert_instance_of TelegramUser, post_classification.telegram_user
  end

  test 'should have chat association' do
    post_classification = post_classifications(:one)
    assert_not_nil post_classification.chat
    assert_instance_of Chat, post_classification.chat
  end
end
