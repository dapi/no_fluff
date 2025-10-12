require 'test_helper'

class ModelTest < ActiveSupport::TestCase
  test 'should load fixture' do
    model = models(:one)
    assert_not_nil model
  end

  test 'loaded fixture should be valid' do
    model = models(:one)
    assert model.valid?
  end

  test 'should save fixture data to database' do
    model = models(:one)
    assert_equal 'gpt-4', model.model_id
    assert_equal 'GPT-4', model.name
    assert_equal 'openai', model.provider
    assert_equal 'gpt-4', model.family
    assert_equal 8192, model.context_window
    assert_equal 4096, model.max_output_tokens
  end

  test 'should handle jsonb fields correctly' do
    model = models(:two)
    assert_equal({ 'text' => true, 'vision' => true }, model.modalities)
    assert_includes model.capabilities, 'chat'
    assert_includes model.capabilities, 'function_calling'
    assert_includes model.capabilities, 'vision'
    assert_equal 0.003, model.pricing['input']
    assert_equal 0.015, model.pricing['output']
  end
end
