# frozen_string_literal: true

# AssertionHelper - дополнительные assertions для тестов
# Предоставляет удобные методы для проверки различных условий
# Расширен для поддержки комплексных проверок и уменьшения дублирования
module AssertionHelper
  # Проверка, что пользователь может добавлять каналы
  # @param user [TelegramUser] пользователь
  # @param message [String] сообщение об ошибке
  def assert_user_can_add_channels(user, message = nil)
    assert user.can_add_channel?, message || "User #{user.username} should be able to add channels"
  end

  # Проверка, что пользователь не может добавлять каналы
  # @param user [TelegramUser] пользователь
  # @param message [String] сообщение об ошибке
  def assert_user_cannot_add_channels(user, message = nil)
    assert_not user.can_add_channel?, message || "User #{user.username} should not be able to add channels"
  end

  # Проверка, что пользователь достиг лимита каналов
  # @param user [TelegramUser] пользователь
  # @param message [String] сообщение об ошибке
  def assert_user_at_channel_limit(user, message = nil)
    assert user.channels_limit_reached?, message || "User #{user.username} should be at channel limit"
  end

  # Проверка, что пользователь не достиг лимита каналов
  # @param user [TelegramUser] пользователь
  # @param message [String] сообщение об ошибке
  def assert_user_not_at_channel_limit(user, message = nil)
    assert_not user.channels_limit_reached?, message || "User #{user.username} should not be at channel limit"
  end

  # Проверка количества подписок пользователя
  # @param user [TelegramUser] пользователь
  # @param expected_count [Integer] ожидаемое количество
  # @param message [String] сообщение об ошибке
  def assert_user_subscription_count(user, expected_count, message = nil)
    actual_count = user.subscriptions.count
    assert_equal expected_count, actual_count, message || "User #{user.username} should have #{expected_count} subscriptions, but has #{actual_count}"
  end

  # Проверка количества активных подписок пользователя
  # @param user [TelegramUser] пользователь
  # @param expected_count [Integer] ожидаемое количество
  # @param message [String] сообщение об ошибке
  def assert_user_active_subscription_count(user, expected_count, message = nil)
    actual_count = user.subscriptions.active.count
    assert_equal expected_count, actual_count, message || "User #{user.username} should have #{expected_count} active subscriptions, but has #{actual_count}"
  end

  # Проверка типа пользователя
  # @param user [TelegramUser] пользователь
  # @param type [Symbol] тип (:regular, :premium, :admin, :bot)
  # @param message [String] сообщение об ошибке
  def assert_user_type(user, type, message = nil)
    case type
    when :regular
      assert_not user.is_premium?, message || "User #{user.username} should not be premium"
      assert_not user.is_admin?, message || "User #{user.username} should not be admin"
      assert_not user.is_bot?, message || "User #{user.username} should not be bot"
    when :premium
      assert user.is_premium?, message || "User #{user.username} should be premium"
      assert_not user.is_admin?, message || "User #{user.username} should not be admin"
      assert_not user.is_bot?, message || "User #{user.username} should not be bot"
    when :admin
      assert user.is_admin?, message || "User #{user.username} should be admin"
    when :bot
      assert user.is_bot?, message || "User #{user.username} should be bot"
    else
      raise ArgumentError, "Unknown user type: #{type}"
    end
  end

  # Проверка статуса канала
  # @param channel [Channel] канал
  # @param status [Symbol] статус (:active, :inactive)
  # @param message [String] сообщение об ошибке
  def assert_channel_status(channel, status, message = nil)
    case status
    when :active
      assert channel.is_active?, message || "Channel #{channel.username} should be active"
    when :inactive
      assert_not channel.is_active?, message || "Channel #{channel.username} should be inactive"
    else
      raise ArgumentError, "Unknown channel status: #{status}"
    end
  end

  # Проверка статуса подписки
  # @param subscription [Subscription] подписка
  # @param status [Symbol] статус (:active, :inactive)
  # @param message [String] сообщение об ошибке
  def assert_subscription_status(subscription, status, message = nil)
    case status
    when :active
      assert subscription.active?, message || 'Subscription should be active'
    when :inactive
      assert_not subscription.active?, message || 'Subscription should be inactive'
    else
      raise ArgumentError, "Unknown subscription status: #{status}"
    end
  end

  # Проверка наличия сессии у пользователя
  # @param user [TelegramUser] пользователь
  # @param key [String] ключ сессии
  # @param expected_value [Object] ожидаемое значение
  # @param message [String] сообщение об ошибке
  def assert_session_value(user, key, expected_value, message = nil)
    actual_value = user.session[key]
    assert_equal expected_value, actual_value, message || "Session key '#{key}' should be '#{expected_value}', but is '#{actual_value}'"
  end

  # Проверка наличия ключа в сессии
  # @param user [TelegramUser] пользователь
  # @param key [String] ключ сессии
  # @param message [String] сообщение об ошибке
  def assert_session_has_key(user, key, message = nil)
    assert user.session.key?(key), message || "Session should have key '#{key}'"
  end

  # Проверка отсутствия ключа в сессии
  # @param user [TelegramUser] пользователь
  # @param key [String] ключ сессии
  # @param message [String] сообщение об ошибке
  def assert_session_missing_key(user, key, message = nil)
    assert_not user.session.key?(key), message || "Session should not have key '#{key}'"
  end

  # Проверка настроек доставки пользователя
  # @param user [TelegramUser] пользователь
  # @param frequency [Integer] частота доставки
  # @param format [Integer] формат контента
  # @param strictness [Integer] строгость фильтрации
  # @param message [String] сообщение об ошибке
  def assert_user_delivery_settings(user, frequency: nil, format: nil, strictness: nil, message: nil)
    if frequency
      assert_equal frequency, user.delivery_frequency, message || "Delivery frequency should be #{frequency}"
    end

    if format
      assert_equal format, user.content_format, message || "Content format should be #{format}"
    end

    if strictness
      assert_equal strictness, user.filter_strictness, message || "Filter strictness should be #{strictness}"
    end
  end

  # Проверка временной зоны пользователя
  # @param user [TelegramUser] пользователь
  # @param timezone [String] временная зона
  # @param message [String] сообщение об ошибке
  def assert_user_timezone(user, timezone, message = nil)
    assert_equal timezone, user.timezone, message || "User timezone should be '#{timezone}'"
  end

  # Проверка языкового кода пользователя
  # @param user [TelegramUser] пользователь
  # @param language_code [String] языковой код
  # @param message [String] сообщение об ошибке
  def assert_user_language_code(user, language_code, message = nil)
    assert_equal language_code, user.language_code, message || "User language code should be '#{language_code}'"
  end

  # Проверка, что канал является премиум
  # @param channel [Channel] канал
  # @param message [String] сообщение об ошибке
  def assert_channel_is_premium(channel, message = nil)
    assert channel.is_premium?, message || "Channel #{channel.username} should be premium"
  end

  # Проверка, что канал не является премиум
  # @param channel [Channel] канал
  # @param message [String] сообщение об ошибке
  def assert_channel_not_premium(channel, message = nil)
    assert_not channel.is_premium?, message || "Channel #{channel.username} should not be premium"
  end

  # Проверка количества постов в дайджесте
  # @param digest [UserDigest] дайджест
  # @param expected_count [Integer] ожидаемое количество
  # @param message [String] сообщение об ошибке
  def assert_digest_post_count(digest, expected_count, message = nil)
    actual_count = digest.post_count
    assert_equal expected_count, actual_count, message || "Digest should have #{expected_count} posts, but has #{actual_count}"
  end

  # Проверка наличия текста в дайджесте
  # @param digest [UserDigest] дайджест
  # @param expected_text [String] ожидаемый текст
  # @param message [String] сообщение об ошибке
  def assert_digest_contains_text(digest, expected_text, message = nil)
    assert digest.content.include?(expected_text), message || "Digest should contain text: '#{expected_text}'"
  end

  # Проверка, что время в допустимом диапазоне
  # @param actual_time [Time] фактическое время
  # @param expected_time [Time] ожидаемое время
  # @param delta [Integer] допустимое отклонение в секундах
  # @param message [String] сообщение об ошибке
  def assert_time_within_delta(actual_time, expected_time, delta = 5, message = nil)
    difference = (actual_time - expected_time).abs
    assert difference <= delta, message || "Time difference #{difference}s should be within #{delta}s"
  end

  # Проверка, что массив содержит ожидаемые элементы
  # @param actual_array [Array] фактический массив
  # @param expected_elements [Array] ожидаемые элементы
  # @param message [String] сообщение об ошибке
  def assert_array_contains_all(actual_array, expected_elements, message = nil)
    missing_elements = expected_elements - actual_array
    assert missing_elements.empty?, message || "Array should contain elements: #{missing_elements.join(', ')}"
  end

  # Проверка, что массив не содержит нежелательные элементы
  # @param actual_array [Array] фактический массив
  # @param forbidden_elements [Array] запрещенные элементы
  # @param message [String] сообщение об ошибке
  def assert_array_contains_none(actual_array, forbidden_elements, message = nil)
    present_elements = forbidden_elements & actual_array
    assert present_elements.empty?, message || "Array should not contain elements: #{present_elements.join(', ')}"
  end

  # Проверка валидации формата данных
  # @param data [String] данные для проверки
  # @param format [Symbol] формат (:email, :url, :username)
  # @param message [String] сообщение об ошибке
  def assert_format_valid(data, format, message = nil)
    case format
    when :email
      assert_match(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i, data, message || 'Email format should be valid')
    when :url
      assert_match(/\Ahttps?:\/\/.+\z/, data, message || 'URL format should be valid')
    when :username
      assert_match(/\A[a-zA-Z0-9_]+\z/, data, message || 'Username format should be valid')
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  end

  # Проверка, что количество записей в базе соответствует ожидаемому
  # @param model_class [Class] класс модели
  # @param expected_count [Integer] ожидаемое количество
  # @param conditions [Hash] условия для запроса
  # @param message [String] сообщение об ошибке
  def assert_record_count(model_class, expected_count, conditions = {}, message = nil)
    actual_count = model_class.where(conditions).count
    assert_equal expected_count, actual_count, message || "#{model_class.name} should have #{expected_count} records"
  end

  # Проверка наличия ошибок валидации у модели
  # @param record [ActiveRecord::Base] запись модели
  # @param expected_errors [Array] ожидаемые ошибки
  # @param message [String] сообщение об ошибке
  def assert_validation_errors(record, expected_errors, message = nil)
    record.valid?
    actual_errors = record.errors.full_messages

    expected_errors.each do |expected_error|
      assert_includes actual_errors, expected_error, message || "Validation should include error: #{expected_error}"
    end

    assert_equal expected_errors.length, actual_errors.length, message || "Should have exactly #{expected_errors.length} validation errors"
  end

  # ===== Новые комплексные assertions для рефакторинга =====

  # Комплексная проверка ассоциаций одной записью
  # @param record [ActiveRecord::Base] запись модели
  # @param association_config [Hash] конфигурация ассоциаций
  # @param message [String] сообщение об ошибке
  def assert_associations(record, association_config, message = nil)
    base_message = message || "#{record.class.name} associations"

    association_config.each do |assoc_type, assoc_names|
      Array(assoc_names).each do |assoc_name|
        assert_respond_to record, assoc_name, "#{base_message}: should respond to #{assoc_name}"

        # Для belongs_to проверяем наличие связанной записи
        if [ :belongs_to, :has_one ].include?(assoc_type) && record.send(assoc_name).nil?
          flunk "#{base_message}: #{assoc_name} should not be nil"
        end
      end
    end
  end

  # ===== ЗАПРЕЩЕНО: Не тестировать валидации моделей =====
  # Валидации - ответственность Rails framework, не требуют дублирования в тестах
  # Вместо этого тестируйте бизнес-логику, ассоциации, scope и кастомные методы

  # Проверка работы scope через конфигурацию
  # @param model_class [Class] класс модели
  # @param scope_name [Symbol] имя scope
  # @param test_data [Hash] тестовые данные
  # @param expectations [Array] ожидания
  def assert_scope_behavior(model_class, scope_name, test_data, expectations)
    # Настраиваем тестовые данные
    setup_test_data(test_data)

    # Выполняем scope
    results = model_class.send(scope_name)

    # Проверяем ожидания
    expectations.each do |expectation|
      case expectation[:type]
      when :includes
        record = expectation[:record]
        assert_includes results, record,
          "#{scope_name} scope should include #{record.class.name} with id #{record.id}"
      when :excludes
        record = expectation[:record]
        assert_not_includes results, record,
          "#{scope_name} scope should exclude #{record.class.name} with id #{record.id}"
      when :count
        assert_equal expectation[:count], results.count,
          "#{scope_name} scope should return #{expectation[:count]} records"
      when :ordered
        actual_ids = results.map(&:id)
        expected_ids = expectation[:order].map(&:id)
        assert_equal expected_ids, actual_ids,
          "#{scope_name} scope should return records in correct order"
      end
    end
  end

  # Проверка enum функциональности
  # @param record [ActiveRecord::Base] запись модели
  # @param enum_definitions [Hash] определения enum
  def assert_enum_functionality(record, enum_definitions)
    enum_definitions.each do |enum_name, enum_values|
      # Проверяем наличие enum
      assert_respond_to record, enum_name, "Should have #{enum_name} enum"

      # Проверяем query методы
      enum_values.each do |enum_value|
        query_method = "#{enum_name}_#{enum_value}?"
        assert_respond_to record, query_method, "Should have #{query_method} method"
      end

      # Проверяем работу с значениями
      test_values = [ enum_values.first, enum_values.last ].uniq
      test_values.each do |enum_value|
        # Устанавливаем значение
        record.send("#{enum_name}=", enum_value.to_sym)

        # Проверяем query метод
        query_method = "#{enum_name}_#{enum_value}?"
        assert record.send(query_method), "Query method #{query_method} should return true for #{enum_value}"

        # Проверяем сохраненное значение
        assert_equal enum_value, record.send(enum_name), "Enum should store #{enum_value}"
      end
    end
  end

  # Проверка destroy зависимостей
  # @param record [ActiveRecord::Base] запись для удаления
  # @param dependencies [Hash] конфигурация зависимостей
  def assert_destroy_dependencies(record, dependencies)
    dependencies.each do |dependency_name, config|
      dependency_model = config[:model]
      expected_change = config[:expected_change] || -1

      # Получаем начальное количество
      initial_count = dependency_model.where(config[:conditions] || {}).count

      # Удаляем запись
      record.destroy

      # Проверяем изменение количества
      final_count = dependency_model.where(config[:conditions] || {}).count
      actual_change = final_count - initial_count

      assert_equal expected_change, actual_change,
        "Destroying #{record.class.name} should change #{dependency_model.name} count by #{expected_change}, but changed by #{actual_change}"
    end
  end

  # Проверка состояния state machine
  # @param record [ActiveRecord::Base] запись с state machine
  # @param state_field [Symbol] поле состояния
  # @param transitions [Array] массив переходов
  def assert_state_transitions(record, state_field, transitions)
    transitions.each do |transition|
      from_state = transition[:from]
      to_state = transition[:to]
      method = transition[:method]

      # Устанавливаем начальное состояние
      record.send("#{state_field}=", from_state)

      # Выполняем переход
      if method
        record.send(method)
      else
        record.send("#{state_field}=", to_state)
      end

      # Проверяем результат
      assert_equal to_state, record.send(state_field),
        "State should transition from #{from_state} to #{to_state}"
    end
  end

  private

  # Настройка тестовых данных
  def setup_test_data(test_data)
    test_data.each do |model_name, records_config|
      model_class = model_name.to_s.camelize.constantize

      records_config.each do |record_config|
        attributes = record_config[:attributes]

        if record_config[:find_or_create]
          record = model_class.find_by(attributes)
          record ||= model_class.create!(attributes)
        else
          record = model_class.create!(attributes)
        end

        if record_config[:updates]
          record.update!(record_config[:updates])
        end
      end
    end
  end
end
