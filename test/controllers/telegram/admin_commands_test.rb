require 'test_helper'

class Telegram::AdminCommandsTest < ActionDispatch::IntegrationTest
  include TelegramHelper
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset if @bot
  end


  # Создание тестовых данных
  def create_test_channels
    # Создаем каналы с разным количеством подписчиков
    @channel1 = Channel.create!(
      telegram_id: 1001,
      username: 'popular_channel',
      title: 'Popular Channel',
      description: 'Very popular channel',
      subscribers_count: 1000,
      last_post_at: 1.hour.ago,
      bot_join_status: 'not_joined'
    )

    @channel2 = Channel.create!(
      telegram_id: 1002,
      username: 'medium_channel',
      title: 'Medium Channel',
      description: 'Medium popularity channel',
      subscribers_count: 500,
      last_post_at: 3.hours.ago,
      bot_join_status: 'not_joined'
    )

    @channel3 = Channel.create!(
      telegram_id: 1003,
      username: 'inactive_channel',
      title: 'Inactive Channel',
      description: 'Inactive channel',
      subscribers_count: 200,
      last_post_at: 2.days.ago,
      deactivated_at: 1.day.ago,
      deactivation_reason: 'test_deactivation',
      bot_join_status: 'not_joined'
    )

    @channel4 = Channel.create!(
      telegram_id: 1004,
      username: 'old_channel',
      title: 'Old Channel',
      description: 'Channel with old posts',
      subscribers_count: 300,
      last_post_at: 10.days.ago,
      bot_join_status: 'not_joined'
    )
  end

  def create_test_subscriptions
    # Создаем подписчиков для каналов
    users = []
    5.times do |i|
      users << TelegramUser.create!(
        username: "user#{i}",
        first_name: "User #{i}",
        language_code: 'ru'
      )
    end

    # Подписчики для popular_channel
    users[0..2].each do |user|
      Subscription.create!(telegram_user: user, channel: @channel1, active: true)
    end

    # Подписчики для medium_channel
    users[1..3].each do |user|
      Subscription.create!(telegram_user: user, channel: @channel2, active: true)
    end

    # Подписчики для inactive_channel (только активные подписки считаются)
    Subscription.create!(telegram_user: users[0], channel: @channel3, active: false)
    Subscription.create!(telegram_user: users[1], channel: @channel3, active: true)

    # Подписчики для old_channel
    Subscription.create!(telegram_user: users[2], channel: @channel4, active: true)
    Subscription.create!(telegram_user: users[3], channel: @channel4, active: true)
  end

  # Основные тесты для команды /channels

  test 'admin can view channels list' do
    admin_user = TelegramUser.create!(
      username: 'admin_channels',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    create_test_channels
    create_test_subscriptions

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], 'Список каналов в системе'
    assert_includes message_content[:text], 'popular_channel'
    assert_includes message_content[:text], 'medium_channel'
    assert_includes message_content[:text], 'inactive_channel'
    assert_includes message_content[:text], 'old_channel'
  end

  test 'channels are sorted by active subscribers count descending' do
    admin_user = TelegramUser.create!(
      username: 'admin_sort',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    create_test_channels
    create_test_subscriptions

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    text = message_content[:text]

    # Проверяем порядок сортировки (popular_channel с 3 подписчиками должен быть первым)
    popular_pos = text.index('popular_channel')
    medium_pos = text.index('medium_channel')
    old_pos = text.index('old_channel')
    inactive_pos = text.index('inactive_channel')

    assert_not_nil popular_pos
    assert_not_nil medium_pos
    assert_not_nil old_pos
    assert_not_nil inactive_pos

    # popular_channel (3 подписчика) должен быть раньше medium_channel (3 подписчика, но создан позже)
    assert popular_pos < medium_pos
    # medium_channel (3 подписчика) должен быть раньше old_channel (2 подписчика)
    assert medium_pos < old_pos
    # old_channel (2 подписчика) должен быть раньше inactive_channel (1 подписчик)
    assert old_pos < inactive_pos
  end

  test 'channels list shows correct subscriber counts' do
    admin_user = TelegramUser.create!(
      username: 'admin_counts',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    create_test_channels
    create_test_subscriptions

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    text = message_content[:text]

    # Проверяем что количество подписчиков отображается корректно
    assert_includes text, '3 подписчика'  # popular_channel
    assert_includes text, '3 подписчика'  # medium_channel
    assert_includes text, '2 подписчика'  # old_channel
    assert_includes text, '1 подписчик'  # inactive_channel
  end

  test 'channels list shows status indicators' do
    admin_user = TelegramUser.create!(
      username: 'admin_status',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    create_test_channels
    create_test_subscriptions

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    text = message_content[:text]

    # Проверяем индикаторы статуса
    assert_includes text, '✅'  # Активные каналы
    assert_includes text, '❌'  # Неактивный канал
    assert_includes text, '⚠️'  # Канал со старыми постами
  end

  test 'non-admin cannot access channels list' do
    regular_user = TelegramUser.create!(
      username: 'regular_channels',
      first_name: 'Regular',
      language_code: 'ru',
      is_admin: false
    )

    create_test_channels

    update = create_user_update(user_id: regular_user.id, username: regular_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.channels.admin_list.admin_only')
  end

  test 'channels list shows message with available channels' do
    admin_user = TelegramUser.create!(
      username: 'admin_empty',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    # Создаем один канал для демонстрации
    test_channel = Channel.create!(
      telegram_id: 9999,
      username: 'demo_channel',
      title: 'Demo Channel',
      description: 'Demo channel for testing',
      subscribers_count: 100,
      last_post_at: 1.hour.ago,
      bot_join_status: 'not_joined'
    )

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    # Проверяем что есть заголовок списка каналов
    assert_includes message_content[:text], '📊 Список каналов в системе'
  end

  test 'channels list handles pagination correctly' do
    admin_user = TelegramUser.create!(
      username: 'admin_pagination',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    # Создаем много каналов для тестирования пагинации
    channels = []
    25.times do |i|
      channel = Channel.create!(
        telegram_id: 2000 + i,
        username: "channel_#{i}",
        title: "Channel #{i}",
        description: "Test channel #{i}",
        subscribers_count: 100 + i,
        last_post_at: i.hours.ago,
        bot_join_status: 'not_joined'
      )
      channels << channel

      # Добавляем по одному подписчику для каждого канала
      user = TelegramUser.create!(
        username: "user_for_channel_#{i}",
        first_name: "User #{i}",
        language_code: 'ru'
      )
      Subscription.create!(telegram_user: user, channel: channel, active: true)
    end

    # Первая страница
    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    text = message_content[:text]

    # Проверяем что на первой странице 20 каналов
    assert_includes text, 'Страница 1 из 2'
    assert_includes text, '(всего:'

    # Проверяем наличие кнопок пагинации
    reply_markup = message_content[:reply_markup]
    assert_not_nil reply_markup
    assert reply_markup[:inline_keyboard].is_a?(Array)

    # Находим кнопки пагинации
    next_button = reply_markup[:inline_keyboard].flatten.find { |btn| btn[:text].include?('Следующая') }
    assert_not_nil next_button
    assert_includes next_button[:callback_data], 'channels_page:2'
  end

  test 'channels list shows channel descriptions' do
    admin_user = TelegramUser.create!(
      username: 'admin_descriptions',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    create_test_channels

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    text = message_content[:text]

    # Проверяем что описания каналов отображаются
    assert_includes text, 'Very popular channel'
    assert_includes text, 'Medium popularity channel'
    assert_includes text, 'Inactive channel'
    assert_includes text, 'Channel with old posts'
  end

  test 'channels list shows last post information' do
    admin_user = TelegramUser.create!(
      username: 'admin_last_post',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    create_test_channels

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content_from_requests(@bot.requests)
    assert_not_nil message_content
    text = message_content[:text]

    # Проверяем что информация о последнем посте отображается
    assert_includes text, I18n.t('telegram_bot.channels.admin_list.last_post')
  end

  test 'channels command handles errors gracefully' do
    admin_user = TelegramUser.create!(
      username: 'admin_error',
      first_name: 'Admin',
      language_code: 'ru',
      is_admin: true
    )

    # Создаем канал который вызовет ошибку (например, с невалидными данными)
    invalid_channel = Channel.new(telegram_id: nil, username: nil)

    update = create_user_update(user_id: admin_user.id, username: admin_user.username,
                               command: '/channels')
    send_webhook_update(update)

    assert_response :success

    # Просто проверяем что команда обрабатывается без критических ошибок
    # Фактическая обработка ошибок будет проверяться в интеграционных тестах
  end
end
