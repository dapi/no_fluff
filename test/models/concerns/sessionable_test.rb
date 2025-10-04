# frozen_string_literal: true

require 'test_helper'

# Тестовая модель с Sessionable concern
class TestSessionableModel < ApplicationRecord
  include Sessionable

  # Создаем временную таблицу для тестов
  self.table_name = 'telegram_users' # Используем существующую таблицу

  # Валидации для тестов
  validates :username, presence: true, uniqueness: true
end

class SessionableTest < ActiveSupport::TestCase
  def setup
    # Ничего не делаем - транзакции автоматически откатятся в teardown
  end

  test 'should be included in model' do
    assert TestSessionableModel.included_modules.include?(Sessionable)
  end

  test 'should detect session support' do
    assert TestSessionableModel.supports_sessions?
  end

  test 'should have default empty session_data' do
    model = TestSessionableModel.create!(username: 'test_user')
    assert_equal({}, model.session_data)
    assert model.session_data.is_a?(Hash)
  end

  test 'should store and retrieve session data' do
    model = TestSessionableModel.create!(username: 'test_user')

    model.set_session('test_key', 'test_value')
    model.reload

    assert_equal 'test_value', model.get_session('test_key')
    assert_equal 'test_value', model.session_data['test_key']
  end

  test 'should handle different data types in session' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Тестируем разные типы данных
    model.set_session('string_key', 'string_value')
    model.set_session('number_key', 42)
    model.set_session('boolean_key', true)
    model.set_session('array_key', [ 1, 2, 3 ])
    model.set_session('hash_key', { nested: 'value' })

    model.reload

    assert_equal 'string_value', model.get_session('string_key')
    assert_equal 42, model.get_session('number_key')
    assert_equal true, model.get_session('boolean_key')
    assert_equal [ 1, 2, 3 ], model.get_session('array_key')
    assert_equal({ 'nested' => 'value' }, model.get_session('hash_key'))
  end

  test 'should update session data without affecting other keys' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Устанавливаем начальные данные
    model.set_session('key1', 'value1')
    model.set_session('key2', 'value2')
    model.reload

    # Обновляем один ключ
    model.set_session('key2', 'new_value2')
    model.set_session('key3', 'value3')
    model.reload

    assert_equal 'value1', model.get_session('key1')
    assert_equal 'new_value2', model.get_session('key2')
    assert_equal 'value3', model.get_session('key3')
  end

  test 'should delete session data by key' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Устанавливаем несколько ключей
    model.set_session('key1', 'value1')
    model.set_session('key2', 'value2')
    model.set_session('key3', 'value3')
    model.reload

    # Удаляем один ключ
    model.delete_session('key2')
    model.reload

    assert_equal 'value1', model.get_session('key1')
    assert_nil model.get_session('key2')
    assert_equal 'value3', model.get_session('key3')
  end

  test 'should clear all session data' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Устанавливаем данные
    model.set_session('key1', 'value1')
    model.set_session('key2', 'value2')
    model.set_session('key3', 'value3')
    model.reload

    # Очищаем сессию
    model.clear_session!
    model.reload

    assert_equal({}, model.session_data)
    assert_nil model.get_session('key1')
    assert_nil model.get_session('key2')
    assert_nil model.get_session('key3')
  end

  test 'should handle symbol and string keys consistently' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Тестируем что символы приводятся к строкам
    model.set_session(:symbol_key, 'symbol_value')
    model.set_session('string_key', 'string_value')
    model.reload

    assert_equal 'symbol_value', model.get_session(:symbol_key)
    assert_equal 'symbol_value', model.get_session('symbol_key')
    assert_equal 'string_value', model.get_session('string_key')
  end

  test 'should handle nil session values' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Устанавливаем nil значение
    model.set_session('nil_key', nil)
    model.reload

    assert_nil model.get_session('nil_key')
    assert model.session_data.key?('nil_key')
  end

  test 'should handle empty session data gracefully' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Проверяем получение данных из пустой сессии
    assert_nil model.get_session('non_existent_key')
    assert_equal({}, model.session_data)

    # Проверяем удаление из пустой сессии
    model.delete_session('non_existent_key')
    assert_equal({}, model.session_data)
  end

  test 'should check if session has key' do
    model = TestSessionableModel.create!(username: 'test_user')

    assert_not model.session_has_key?('non_existent_key')

    model.set_session('test_key', 'test_value')
    assert model.session_has_key?('test_key')
    assert model.session_has_key?(:test_key)
  end

  test 'should return session keys' do
    model = TestSessionableModel.create!(username: 'test_user')

    assert_equal [], model.session_keys

    model.set_session('key1', 'value1')
    model.set_session('key2', 'value2')

    assert_equal [ 'key1', 'key2' ], model.session_keys.sort
  end

  test 'should check if session is empty' do
    model = TestSessionableModel.create!(username: 'test_user')

    assert model.session_empty?

    model.set_session('test_key', 'test_value')
    assert_not model.session_empty?
  end

  test 'should return session size' do
    model = TestSessionableModel.create!(username: 'test_user')

    assert_equal 0, model.session_size

    model.set_session('key1', 'value1')
    assert_equal 1, model.session_size

    model.set_session('key2', 'value2')
    assert_equal 2, model.session_size
  end

  test 'should set multiple session data at once' do
    model = TestSessionableModel.create!(username: 'test_user')

    result = model.set_session_data({
      'key1' => 'value1',
      'key2' => 'value2',
      :key3 => 'value3'
    })

    assert result
    model.reload

    assert_equal 'value1', model.get_session('key1')
    assert_equal 'value2', model.get_session('key2')
    assert_equal 'value3', model.get_session('key3')
  end

  test 'should return session data copy' do
    model = TestSessionableModel.create!(username: 'test_user')
    model.set_session('test_key', 'test_value')

    copy = model.session_data_copy
    copy['new_key'] = 'new_value'

    assert_not model.session_has_key?('new_key')
    assert_equal 'test_value', model.get_session('test_key')
  end

  test 'should work with temporary session data' do
    model = TestSessionableModel.create!(username: 'test_user')
    model.set_session('original_key', 'original_value')

    result = model.with_temp_session do
      model.set_session('temp_key', 'temp_value')
      assert model.get_session('temp_key') == 'temp_value'
      'result'
    end

    assert_equal 'result', result
    assert_not model.session_has_key?('temp_key')
    assert_equal 'original_value', model.get_session('original_key')
  end

  test 'should delete multiple session keys' do
    model = TestSessionableModel.create!(username: 'test_user')

    model.set_session('key1', 'value1')
    model.set_session('key2', 'value2')
    model.set_session('key3', 'value3')
    model.set_session('key4', 'value4')

    result = model.delete_session_keys([ 'key1', 'key3', :key4 ])
    assert result

    model.reload
    assert_not model.session_has_key?('key1')
    assert_not model.session_has_key?('key3')
    assert_not model.session_has_key?('key4')
    assert model.session_has_key?('key2')
  end

  test 'should validate session data' do
    model = TestSessionableModel.create!(username: 'test_user')

    assert model.valid_session_data?

    # Создаем модель с невалидными данными через мок
    invalid_model = TestSessionableModel.create!(username: 'test_user2')

    # Переопределяем метод session_data чтобы вернуть невалидные данные
    def invalid_model.session_data
      'invalid_data'
    end

    assert_not invalid_model.valid_session_data?
  end

  test 'should return false when session not supported' do
    # Создаем класс без session_data поля
    model_class = Class.new do
      include Sessionable

      def self.column_names
        ['id', 'name'] # Нет session_data
      end

      def self.table_name
        'test_models'
      end

      def save!
        true
      end

      def self.supports_sessions?
        column_names.include?('session_data')
      end
    end

    model_without_sessions = model_class.new

    assert_not model_without_sessions.class.supports_sessions?
    assert_nil model_without_sessions.get_session('key')
    assert_not model_without_sessions.set_session('key', 'value')
    assert_not model_without_sessions.delete_session('key')
    assert_not model_without_sessions.clear_session!
  end

  test 'should handle validation errors in session operations' do
    model = TestSessionableModel.create!(username: 'test_user')

    # Эмулируем ошибку валидации
    model.define_singleton_method(:save!) do
      raise ActiveRecord::RecordInvalid, self
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      model.set_session('key', 'value')
    end
  end

  # Интеграционные тесты
  test 'should work with real model' do
    user = TelegramUser.create!(
      username: 'integration_test_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    # Проверяем что все методы работают с реальной моделью
    assert user.respond_to?(:get_session)
    assert user.respond_to?(:set_session)
    assert user.respond_to?(:delete_session)
    assert user.respond_to?(:clear_session!)

    user.set_session('integration_key', 'integration_value')
    user.reload

    assert_equal 'integration_value', user.get_session('integration_key')
  end
end
