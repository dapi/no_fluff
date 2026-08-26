# frozen_string_literal: true

require 'test_helper'

class Content::PostClassifierTest < ActiveSupport::TestCase
  test 'selects the configured DeepSeek model without a remote model registry lookup' do
    response = stub(content: '{"deliverable":true,"importance_score":80,"confidence":0.9}')
    chat = mock('chat')
    chat.expects(:with_instructions).with(Content::PostClassifier::INSTRUCTIONS).returns(chat)
    chat.expects(:ask).with('Useful post').returns(response)
    RubyLLM.expects(:chat).with(model: 'deepseek-chat', provider: :deepseek, assume_model_exists: true).returns(chat)
    post = stub(text: 'Useful post')

    result = Content::PostClassifier.new.classify(post)

    assert_equal true, result[:deliverable]
    assert_equal 80, result[:importance_score]
  end
end
