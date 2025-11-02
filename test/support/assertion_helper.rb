# frozen_string_literal: true

# AssertionHelper - дополнительные assertions для тестов
# Предоставляет удобные методы для проверки различных условий
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
end
