require 'test_helper'

class SystemSettingTest < ActiveSupport::TestCase
  # Validation tests
  test 'should be valid with valid attributes' do
    setting = SystemSetting.new(
      key: 'test_debug_mode',
      value: false,
      description: 'Debug mode setting'
    )
    assert setting.valid?
  end

  test 'should require key' do
    setting = SystemSetting.new(
      value: false,
      description: 'Debug mode setting'
    )
    assert_not setting.valid?
    assert setting.errors[:key].present?
  end

  test 'should allow nil value' do
    setting = SystemSetting.new(
      key: 'test_debug_mode_nil',
      value: nil,
      description: 'Debug mode setting'
    )
    assert setting.valid?
  end

  test 'should require unique key' do
    existing_setting = SystemSetting.create!(
      key: 'test_unique_key',
      value: false,
      description: 'Debug mode setting'
    )

    setting = SystemSetting.new(
      key: existing_setting.key,
      value: true,
      description: 'Another debug setting'
    )
    assert_not setting.valid?
    assert setting.errors[:key].present?
  end

  test 'should allow different keys' do
    SystemSetting.create!(
      key: 'test_different_key1',
      value: false,
      description: 'Debug mode setting'
    )

    setting = SystemSetting.new(
      key: 'test_different_key2',
      value: true,
      description: 'Another setting'
    )
    assert setting.valid?
  end

  test 'should allow description to be nil' do
    setting = SystemSetting.new(
      key: 'test_description_nil',
      value: false
    )
    assert setting.valid?
  end

  # Scope tests
  test 'by_key scope should filter by key' do
    setting1 = SystemSetting.create!(key: 'test_scope_key1', value: false)
    setting2 = SystemSetting.create!(key: 'test_scope_key2', value: true)

    found_settings = SystemSetting.by_key('test_scope_key1')
    assert_includes found_settings, setting1
    assert_not_includes found_settings, setting2
  end

  test 'by_key scope should return empty when no matching key' do
    SystemSetting.create!(key: 'test_nonexistent', value: false)

    found_settings = SystemSetting.by_key('non_existent_key')
    assert_empty found_settings
  end

  # Class method tests
  test 'get should return value when setting exists' do
    setting = SystemSetting.create!(key: 'test_get_key', value: true)

    result = SystemSetting.get('test_get_key')
    assert_equal true, result
  end

  test 'get should return default when setting does not exist' do
    result = SystemSetting.get('non_existent_key', 'default_value')
    assert_equal 'default_value', result
  end

  test 'get should return nil when setting does not exist and no default provided' do
    result = SystemSetting.get('non_existent_key')
    assert_nil result
  end

  test 'set should create new setting when it does not exist' do
    setting = SystemSetting.set('test_new_setting', 'new_value', 'New setting description')

    assert setting.persisted?
    assert_equal 'test_new_setting', setting.key
    assert_equal 'new_value', setting.value
    assert_equal 'New setting description', setting.description
  end

  test 'set should update existing setting' do
    original_setting = SystemSetting.create!(
      key: 'test_update_setting',
      value: false,
      description: 'Original description'
    )

    updated_setting = SystemSetting.set('test_update_setting', true, 'Updated description')

    assert_equal original_setting.id, updated_setting.id
    assert_equal true, updated_setting.value
    assert_equal 'Updated description', updated_setting.description
  end

  test 'set should not update description when not provided' do
    original_setting = SystemSetting.create!(
      key: 'test_update_desc_setting',
      value: false,
      description: 'Original description'
    )

    updated_setting = SystemSetting.set('test_update_desc_setting', true)

    assert_equal original_setting.id, updated_setting.id
    assert_equal true, updated_setting.value
    assert_equal 'Original description', updated_setting.description
  end

  test 'set should raise error when key is nil' do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      SystemSetting.set(nil, 'new_value')
    end
    assert_not_nil error
    assert error.record.errors[:key].present?
  end

  # JSONB data type tests
  test 'should store boolean values' do
    setting = SystemSetting.create!(key: 'test_boolean', value: true)
    setting.reload

    assert_equal true, setting.value
    assert_equal true, SystemSetting.get('test_boolean')
  end

  test 'should store string values' do
    setting = SystemSetting.create!(key: 'api_key', value: 'secret_key')
    setting.reload

    assert_equal 'secret_key', setting.value
    assert_equal 'secret_key', SystemSetting.get('api_key')
  end

  test 'should store hash values' do
    hash_value = { nested: { value: 42 }, array: [1, 2, 3] }
    setting = SystemSetting.create!(key: 'config', value: hash_value)
    setting.reload

    # JSONB converts symbol keys to strings
    expected_value = { 'nested' => { 'value' => 42 }, 'array' => [1, 2, 3] }
    assert_equal expected_value, setting.value
    assert_equal expected_value, SystemSetting.get('config')
  end

  test 'should store array values' do
    array_value = ['item1', 'item2', { nested: 'value' }]
    setting = SystemSetting.create!(key: 'list', value: array_value)
    setting.reload

    # JSONB converts symbol keys to strings in nested objects
    expected_value = ['item1', 'item2', { 'nested' => 'value' }]
    assert_equal expected_value, setting.value
    assert_equal expected_value, SystemSetting.get('list')
  end

  test 'should store numeric values' do
    setting = SystemSetting.create!(key: 'timeout', value: 30)
    setting.reload

    assert_equal 30, setting.value
    assert_equal 30, SystemSetting.get('timeout')
  end

  # Edge case tests
  test 'should handle empty hash values' do
    setting = SystemSetting.create!(key: 'empty_config', value: {})
    setting.reload

    assert_equal({}, setting.value)
    assert_equal({}, SystemSetting.get('empty_config'))
  end

  test 'should handle empty array values' do
    setting = SystemSetting.create!(key: 'empty_list', value: [])
    setting.reload

    assert_equal([], setting.value)
    assert_equal([], SystemSetting.get('empty_list'))
  end

  test 'should handle nil values in setting' do
    setting = SystemSetting.create!(key: 'nullable_field', value: nil)
    setting.reload

    assert_nil setting.value
    assert_nil SystemSetting.get('nullable_field')
  end

  # Integration tests
  test 'should work with debug mode setting specifically' do
    # Initially disabled
    assert_equal false, SystemSetting.get('test_debug_specific', false)

    # Enable debug mode
    SystemSetting.set('test_debug_specific', true, 'Enable debug notifications')
    assert_equal true, SystemSetting.get('test_debug_specific')

    # Disable debug mode
    SystemSetting.set('test_debug_specific', false)
    assert_equal false, SystemSetting.get('test_debug_specific')
  end

  test 'should handle multiple different settings' do
    SystemSetting.set('test_multi_1', true)
    SystemSetting.set('test_multi_2', 100)
    SystemSetting.set('test_multi_3', { new_ui: true, beta_features: false })

    assert_equal true, SystemSetting.get('test_multi_1')
    assert_equal 100, SystemSetting.get('test_multi_2')
    # JSONB converts symbol keys to strings
    assert_equal({ 'new_ui' => true, 'beta_features' => false }, SystemSetting.get('test_multi_3'))

    # Ensure settings don't interfere with each other
    multi_settings = SystemSetting.by_key('test_multi_1')
    assert_equal 1, multi_settings.count

    # Count should be 3 + 2 from fixtures = 5
    all_settings = SystemSetting.all
    assert_equal 5, all_settings.count
  end
end
