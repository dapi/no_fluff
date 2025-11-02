# frozen_string_literal: true

require 'test_helper'

class TelegramUser::SessionTest < ActiveSupport::TestCase
  # Session data integration tests (базовые проверки интеграции с Sessionable)
  test 'should include Sessionable concern' do
    user = TelegramUser.new(
      username: 'test_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    assert user.respond_to?(:get_session)
    assert user.respond_to?(:set_session)
    assert user.respond_to?(:delete_session)
    assert user.respond_to?(:clear_session!)
    assert TelegramUser.supports_sessions?
  end

  test 'should work with session through concern' do
    user = TelegramUser.create!(
      username: 'session_integration_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Проверяем базовую функциональность через concern
    assert user.set_session('test_key', 'test_value')
    user.reload
    assert_equal 'test_value', user.get_session('test_key')

    assert user.session_has_key?('test_key')
    assert_equal 1, user.session_size
    assert_not user.session_empty?

    assert user.delete_session('test_key')
    user.reload
    assert_nil user.get_session('test_key')
    assert user.session_empty?
  end

  test 'should support multiple session operations' do
    user = TelegramUser.create!(
      username: 'multi_session_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Проверяем массовые операции
    result = user.set_session_data({
      'name' => 'John',
      'age' => 30,
      'preferences' => { theme: 'dark' }
    })
    assert result

    user.reload
    assert_equal 'John', user.get_session('name')
    assert_equal 30, user.get_session('age')
    assert_equal({ 'theme' => 'dark' }, user.get_session('preferences'))

    # Проверяем работу с ключами
    keys = user.session_keys
    assert_includes keys, 'name'
    assert_includes keys, 'age'
    assert_includes keys, 'preferences'

    # Проверяем копию данных
    copy = user.session_data_copy
    copy['new_key'] = 'new_value'
    assert_not user.session_has_key?('new_key')
  end

  # Advanced session tests
  test 'should handle complex session data structures' do
    user = TelegramUser.create!(
      username: 'complex_session_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    complex_data = {
      'user_settings' => {
        'theme' => 'dark',
        'notifications' => true,
        'preferences' => {
          'language' => 'en',
          'timezone' => 'UTC'
        }
      },
      'temporary_state' => {
        'current_page' => 'dashboard',
        'filters' => [ 'active', 'recent' ],
        'metadata' => {
          'last_action' => 'view',
          'timestamp' => Time.current.to_i
        }
      }
    }

    assert user.set_session_data(complex_data)
    user.reload

    retrieved_data = user.session_data_copy
    assert_equal 'dark', retrieved_data['user_settings']['theme']
    assert_equal true, retrieved_data['user_settings']['notifications']
    assert_equal 'en', retrieved_data['user_settings']['preferences']['language']
    assert_equal [ 'active', 'recent' ], retrieved_data['temporary_state']['filters']
  end

  test 'should handle session data cleanup' do
    user = TelegramUser.create!(
      username: 'cleanup_session_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Добавляем несколько ключей
    user.set_session('temp_key1', 'value1')
    user.set_session('temp_key2', 'value2')
    user.set_session('persistent_key', 'persistent_value')

    assert_equal 3, user.session_size
    assert user.session_has_key?('temp_key1')
    assert user.session_has_key?('temp_key2')
    assert user.session_has_key?('persistent_key')

    # Удаляем временные ключи
    assert user.delete_session('temp_key1')
    assert user.delete_session('temp_key2')
    user.reload

    assert_equal 1, user.session_size
    assert_not user.session_has_key?('temp_key1')
    assert_not user.session_has_key?('temp_key2')
    assert user.session_has_key?('persistent_key')
  end

  test 'should handle session data persistence across user reloads' do
    user = TelegramUser.create!(
      username: 'persistence_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Устанавливаем данные сессии
    user.set_session('test_key', 'test_value')
    user.set_session('user_data', { name: 'Test', role: 'admin' })

    # Перезагружаем пользователя из базы
    user.reload

    # Проверяем что данные сохранились
    assert_equal 'test_value', user.get_session('test_key')
    assert_equal({ 'name' => 'Test', 'role' => 'admin' }, user.get_session('user_data'))
    assert_equal 2, user.session_size
    assert_not user.session_empty?
  end

  test 'should handle empty session operations gracefully' do
    user = TelegramUser.create!(
      username: 'empty_session_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Проверяем операции с пустой сессией
    assert_nil user.get_session('non_existent_key')
    assert_not user.session_has_key?('non_existent_key')
    assert user.session_empty?
    assert_equal 0, user.session_size
    assert_empty user.session_keys

    # Удаление несуществующего ключа должно вернуть false
    assert_not user.delete_session('non_existent_key')

    # Очистка пустой сессии должна работать
    assert user.clear_session!
    assert user.session_empty?
  end

  test 'should handle session data type consistency' do
    user = TelegramUser.create!(
      username: 'type_consistency_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Проверяем разные типы данных
    test_data = {
      'string_key' => 'string_value',
      'number_key' => 42,
      'boolean_key' => true,
      'array_key' => [ 1, 2, 3 ],
      'hash_key' => { nested: 'value' },
      'nil_key' => nil
    }

    user.set_session_data(test_data)
    user.reload

    retrieved = user.session_data_copy

    assert_equal 'string_value', retrieved['string_key']
    assert_equal 42, retrieved['number_key']
    assert_equal true, retrieved['boolean_key']
    assert_equal [ 1, 2, 3 ], retrieved['array_key']
    assert_equal({ 'nested' => 'value' }, retrieved['hash_key'])
    assert_nil retrieved['nil_key']
  end
end
