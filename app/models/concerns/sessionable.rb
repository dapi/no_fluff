# frozen_string_literal: true

# Concern для добавления функциональности сессий в модели
# Предоставляет методы для работы с данными сессии в поле session_data
module Sessionable
  extend ActiveSupport::Concern

  included do
    # Проверяем что модель имеет поле session_data
    # Это можно вынести в валидацию при необходимости
  end

  class_methods do
    # Проверяем что модель поддерживает сессии
    def supports_sessions?
      column_names.include?('session_data')
    end
  end

  # Методы для работы с сессиями
  def session_data
    # Если поле не существует, возвращаем пустой хеш
    return {} unless self.class.supports_sessions?

    data = super
    data.is_a?(Hash) ? data : {}
  end

  def session_data=(data)
    return unless self.class.supports_sessions?

    super(data || {})
  end

  # Получить значение из сессии по ключу
  # Поддерживает как символы, так и строки в качестве ключей
  def get_session(key)
    return nil unless self.class.supports_sessions?

    session_data[key.to_s]
  end

  # Установить значение в сессию по ключу
  # Автоматически сохраняет модель в базу данных
  def set_session(key, value)
    return false unless self.class.supports_sessions?

    # Преобразуем ключ в строку для консистентности
    string_key = key.to_s

    # Обновляем сессионные данные
    current_data = session_data
    updated_data = current_data.merge(string_key => value)

    self.session_data = updated_data
    save!
  end

  # Удалить значение из сессии по ключу
  # Автоматически сохраняет модель в базу данных
  def delete_session(key)
    return false unless self.class.supports_sessions?

    string_key = key.to_s
    return false unless session_data.key?(string_key)

    # Удаляем ключ из сессионных данных
    updated_data = session_data.except(string_key)
    self.session_data = updated_data
    save!
  end

  # Очистить всю сессию
  # Удаляет все данные сессии и сохраняет модель
  def clear_session!
    return false unless self.class.supports_sessions?

    self.session_data = {}
    save!
  end

  # Проверить наличие ключа в сессии
  def session_has_key?(key)
    return false unless self.class.supports_sessions?

    session_data.key?(key.to_s)
  end

  # Получить все ключи сессии
  def session_keys
    return [] unless self.class.supports_sessions?

    session_data.keys
  end

  # Проверить пуста ли сессия
  def session_empty?
    return true unless self.class.supports_sessions?

    session_data.empty?
  end

  # Получить размер сессии (количество ключей)
  def session_size
    return 0 unless self.class.supports_sessions?

    session_data.size
  end

  # Установить несколько значений в сессии за один раз
  # Принимает хеш { key => value }
  def set_session_data(data_hash)
    return false unless self.class.supports_sessions?
    return false unless data_hash.is_a?(Hash)

    # Преобразуем все ключи в строки
    stringified_data = data_hash.transform_keys(&:to_s)

    # Объединяем с текущими данными
    updated_data = session_data.merge(stringified_data)
    self.session_data = updated_data
    save!
  end

  # Получить все данные сессии как копию
  def session_data_copy
    return {} unless self.class.supports_sessions?

    session_data.dup
  end

  # Выполнить блок с временными данными сессии
  # Изменения не сохраняются в базу данных
  def with_temp_session
    return yield unless self.class.supports_sessions?

    original_data = session_data.dup
    result = yield

    # Восстанавливаем исходные данные
    self.session_data = original_data

    result
  end

  # Массовое удаление ключей из сессии
  # Принимает массив ключей
  def delete_session_keys(keys)
    return false unless self.class.supports_sessions?
    return false unless keys.is_a?(Array)

    string_keys = keys.map(&:to_s)
    updated_data = session_data.except(*string_keys)
    self.session_data = updated_data
    save!
  end

  # Проверить валидность данных сессии
  def valid_session_data?
    return false unless self.class.supports_sessions?

    session_data.is_a?(Hash)
  end
end
