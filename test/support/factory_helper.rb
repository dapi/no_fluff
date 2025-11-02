# frozen_string_literal: true

# FactoryHelper - фабрики для создания тестовых данных
# Предоставляет удобные методы для создания объектов с разными параметрами
module FactoryHelper
  # Создание пользователя с базовыми параметрами
  # @param overrides [Hash] параметры для переопределения
  # @return [TelegramUser] пользователь
  def create_telegram_user(overrides = {})
    defaults = {
      id: generate_unique_id,
      username: generate_unique_username,
      first_name: 'Test',
      last_name: 'User',
      language_code: 'en',
      is_premium: false,
      is_bot: false,
      is_admin: false,
      delivery_frequency: 1,
      content_format: 1,
      filter_strictness: 1,
      timezone: 'UTC'
    }

    TelegramUser.create!(defaults.merge(overrides))
  end

  # Создание premium пользователя
  # @param overrides [Hash] параметры для переопределения
  # @return [TelegramUser] premium пользователь
  def create_premium_user(overrides = {})
    create_telegram_user(
      overrides.merge(
        is_premium: true,
        username: generate_unique_username('premium')
      )
    )
  end

  # Создание admin пользователя
  # @param overrides [Hash] параметры для переопределения
  # @return [TelegramUser] admin пользователь
  def create_admin_user(overrides = {})
    create_telegram_user(
      overrides.merge(
        is_admin: true,
        username: generate_unique_username('admin')
      )
    )
  end

  # Создание пользователя с конкретными настройками доставки
  # @param frequency [Integer] частота доставки
  # @param format [Integer] формат контента
  # @param strictness [Integer] строгость фильтрации
  # @param timezone [String] часовой пояс
  # @return [TelegramUser] пользователь с настройками
  def create_user_with_settings(frequency: 1, format: 1, strictness: 1, timezone: 'UTC')
    create_telegram_user(
      delivery_frequency: frequency,
      content_format: format,
      filter_strictness: strictness,
      timezone: timezone
    )
  end

  # Создание нескольких пользователей
  # @param count [Integer] количество пользователей
  # @param type [Symbol] тип пользователей (:regular, :premium, :admin, :mixed)
  # @return [Array<TelegramUser>] массив пользователей
  def create_telegram_users(count, type = :regular)
    case type
    when :regular
      Array.new(count) { create_telegram_user }
    when :premium
      Array.new(count) { create_premium_user }
    when :admin
      Array.new(count) { create_admin_user }
    when :mixed
      users = []
      count.times do |i|
        case i % 3
        when 0 then users << create_telegram_user
        when 1 then users << create_premium_user
        when 2 then users << create_admin_user
        end
      end
      users
    else
      Array.new(count) { create_telegram_user }
    end
  end

  # Создание канала
  # @param overrides [Hash] параметры для переопределения
  # @return [Channel] канал
  def create_channel(overrides = {})
    defaults = {
      name: generate_unique_channel_name,
      username: generate_unique_channel_username,
      description: 'Test channel description',
      is_active: true,
      member_count: 1000,
      last_post_at: 1.day.ago,
      category: 'general'
    }

    Channel.create!(defaults.merge(overrides))
  end

  # Создание неактивного канала
  # @param overrides [Hash] параметры для переопределения
  # @return [Channel] неактивный канал
  def create_inactive_channel(overrides = {})
    create_channel(overrides.merge(is_active: false))
  end

  # Создание премиум канала
  # @param overrides [Hash] параметры для переопределения
  # @return [Channel] премиум канал
  def create_premium_channel(overrides = {})
    create_channel(
      overrides.merge(
        name: generate_unique_channel_name('premium'),
        is_premium: true,
        category: 'premium'
      )
    )
  end

  # Создание подписки
  # @param user [TelegramUser] пользователь
  # @param channel [Channel] канал
  # @param overrides [Hash] параметры для переопределения
  # @return [Subscription] подписка
  def create_subscription(user: nil, channel: nil, overrides: {})
    user ||= create_telegram_user
    channel ||= create_channel

    defaults = {
      user: user,
      channel: channel,
      active: true,
      subscribed_at: Time.current,
      last_delivered_at: 1.hour.ago
    }

    Subscription.create!(defaults.merge(overrides))
  end

  # Создание неактивной подписки
  # @param user [TelegramUser] пользователь
  # @param channel [Channel] канал
  # @param overrides [Hash] параметры для переопределения
  # @return [Subscription] неактивная подписка
  def create_inactive_subscription(user: nil, channel: nil, overrides: {})
    create_subscription(
      user: user,
      channel: channel,
      overrides: overrides.merge(active: false)
    )
  end

  # Создание нескольких подписок для пользователя
  # @param user [TelegramUser] пользователь
  # @param count [Integer] количество подписок
  # @param channel_type [Symbol] тип каналов (:regular, :premium, :mixed)
  # @return [Array<Subscription>] массив подписок
  def create_subscriptions_for_user(user, count, channel_type = :regular)
    channels = case channel_type
    when :regular
                 Array.new(count) { create_channel }
    when :premium
                 Array.new(count) { create_premium_channel }
    when :mixed
                 Array.new(count) do |i|
                   i.even? ? create_channel : create_premium_channel
                 end
    else
                 Array.new(count) { create_channel }
    end

    channels.map { |channel| create_subscription(user: user, channel: channel) }
  end

  # Создание поста
  # @param channel [Channel] канал
  # @param overrides [Hash] параметры для переопределения
  # @return [Post] пост
  def create_post(channel: nil, overrides: {})
    channel ||= create_channel

    defaults = {
      channel: channel,
      title: 'Test Post Title',
      content: 'Test post content with some text',
      published_at: 1.hour.ago,
      view_count: 100,
      reaction_count: 10
    }

    Post.create!(defaults.merge(overrides))
  end

  # Создание дайджеста
  # @param user [TelegramUser] пользователь
  # @param overrides [Hash] параметры для переопределения
  # @return [UserDigest] дайджест
  def create_user_digest(user: nil, overrides: {})
    user ||= create_telegram_user

    defaults = {
      user: user,
      title: 'Daily Digest',
      content: 'Digest content with posts',
      delivered_at: Time.current,
      post_count: 5
    }

    UserDigest.create!(defaults.merge(overrides))
  end

  # Создание сложного сценария: пользователь с подписками
  # @param user_type [Symbol] тип пользователя
  # @param subscription_count [Integer] количество подписок
  # @param channel_types [Array] типы каналов
  # @return [TelegramUser] пользователь с подписками
  def create_user_with_subscriptions(user_type = :regular, subscription_count = 3, channel_types = [ :regular ])
    user = case user_type
    when :regular then create_telegram_user
    when :premium then create_premium_user
    when :admin then create_admin_user
    else create_telegram_user
    end

    subscription_count.times do |i|
      channel_type = channel_types[i % channel_types.length]
      channel = case channel_type
      when :regular then create_channel
      when :premium then create_premium_channel
      when :inactive then create_inactive_channel
      else create_channel
      end

      create_subscription(user: user, channel: channel)
    end

    user
  end

  # Создание сценария с лимитом подписок
  # @param user_type [Symbol] тип пользователя
  # @param count [Integer] количество подписок
  # @return [TelegramUser] пользователь с указанным количеством подписок
  def create_user_at_limit(user_type = :regular, count = 3)
    user = case user_type
    when :regular then create_telegram_user
    when :premium then create_premium_user
    else create_telegram_user
    end

    channels = Array.new(count) { create_channel }
    channels.each { |channel| create_subscription(user: user, channel: channel) }

    user
  end

  # Создание сценария с превышением лимита
  # @param user_type [Symbol] тип пользователя
  # @param over_limit [Integer] превышение лимита
  # @return [TelegramUser] пользователь с превышением лимита подписок
  def create_user_over_limit(user_type = :regular, over_limit = 1)
    limit = user_type == :premium ? 50 : 3
    create_user_at_limit(user_type: user_type, count: limit + over_limit)
  end

  private

  # Генерация уникального ID
  # @return [Integer] уникальный ID
  def generate_unique_id
    @id_counter ||= 10000
    @id_counter += 1
  end

  # Генерация уникального имени пользователя
  # @param prefix [String] префикс
  # @return [String] уникальное имя пользователя
  def generate_unique_username(prefix = 'test')
    @username_counter ||= 1
    username = "#{prefix}_user_#{@username_counter}"
    @username_counter += 1
    username
  end

  # Генерация уникального названия канала
  # @param prefix [String] префикс
  # @return [String] уникальное название канала
  def generate_unique_channel_name(prefix = 'test')
    @channel_name_counter ||= 1
    name = "#{prefix.capitalize} Channel #{@channel_name_counter}"
    @channel_name_counter += 1
    name
  end

  # Генерация уникального имени пользователя канала
  # @return [String] уникальное имя пользователя канала
  def generate_unique_channel_username
    @channel_username_counter ||= 1
    username = "test_channel_#{@channel_username_counter}"
    @channel_username_counter += 1
    username
  end
end
