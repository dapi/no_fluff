require 'test_helper'

class Telegram::ChannelServiceTest < ActiveSupport::TestCase
  setup do
    @bot = Telegram.bot
    @service = Telegram::ChannelService.new(@bot)
    @user = telegram_users(:one)
  end

  # Тесты парсинга username

  test 'parse_channel_username extracts username from @username format' do
    assert_equal 'testchannel', @service.parse_channel_username('@testchannel')
  end

  test 'parse_channel_username handles username without @' do
    assert_equal 'testchannel', @service.parse_channel_username('testchannel')
  end

  test 'parse_channel_username extracts username from t.me/username' do
    assert_equal 'testchannel', @service.parse_channel_username('t.me/testchannel')
  end

  test 'parse_channel_username extracts username from https://t.me/username' do
    assert_equal 'testchannel', @service.parse_channel_username('https://t.me/testchannel')
  end

  test 'parse_channel_username extracts username from http://t.me/username' do
    assert_equal 'testchannel', @service.parse_channel_username('http://t.me/testchannel')
  end

  test 'parse_channel_username handles spaces' do
    assert_equal 'testchannel', @service.parse_channel_username('  @testchannel  ')
  end

  test 'parse_channel_username returns nil for invalid format' do
    assert_nil @service.parse_channel_username('invalid format!')
    assert_nil @service.parse_channel_username('')
    assert_nil @service.parse_channel_username(nil)
  end

  test 'parse_channel_username returns nil for too short username' do
    assert_nil @service.parse_channel_username('@test')  # менее 5 символов
  end

  test 'parse_channel_username returns nil for too long username' do
    long_username = '@' + 'a' * 33  # более 32 символов
    assert_nil @service.parse_channel_username(long_username)
  end

  # Тесты valid_username?

  test 'valid_username? accepts valid usernames' do
    assert @service.valid_username?('testchannel')
    assert @service.valid_username?('test_channel')
    assert @service.valid_username?('Test123')
    assert @service.valid_username?('channel1234567890')
  end

  test 'valid_username? rejects invalid usernames' do
    assert_not @service.valid_username?('test')  # слишком короткий
    assert_not @service.valid_username?('test-channel')  # дефис не разрешен
    assert_not @service.valid_username?('test.channel')  # точка не разрешена
    assert_not @service.valid_username?('test channel')  # пробел не разрешен
    assert_not @service.valid_username?('')
    assert_not @service.valid_username?(nil)
  end

  # Тесты get_channel_info будут зависеть от моков Telegram API
  # так как мы не можем делать реальные API запросы в тестах

  test 'get_channel_info handles errors gracefully' do
    # В тестовом окружении bot stubbed, поэтому get_chat вернет ошибку
    result = @service.get_channel_info('nonexistent')
    assert_nil result
  end

  # Тесты add_channel_for_user

  test 'add_channel_for_user returns error for invalid format' do
    result = @service.add_channel_for_user(@user, 'invalid!')

    assert_not result[:success]
    assert_includes result[:message], 'Неверный формат'
  end

  test 'add_channel_for_user checks free user limit' do
    # Создаем 10 активных подписок для бесплатного пользователя
    10.times do |i|
      channel = Channel.create!(
        telegram_id: 1000 + i,
        username: "channel#{i}",
        title: "Test Channel #{i}"
      )
      @user.subscriptions.create!(channel: channel, active: true)
    end

    # Попытка добавить 11-й канал должна вернуть ошибку
    result = @service.add_channel_for_user(@user, '@newchannel')

    assert_not result[:success]
    assert_includes result[:message], 'лимит'
  end

  test 'add_channel_for_user allows premium users to exceed limit' do
    # Создаем 10 активных подписок
    10.times do |i|
      channel = Channel.create!(
        telegram_id: 1000 + i,
        username: "channel#{i}",
        title: "Test Channel #{i}"
      )
      @user.subscriptions.create!(channel: channel, active: true)
    end

    # Делаем пользователя premium
    @user.update(is_premium: true)

    # Premium пользователь не должен получить ошибку лимита
    # (хотя получит ошибку "канал не найден" из-за stubbed API)
    result = @service.add_channel_for_user(@user, '@newchannel')

    # Ошибка будет, но не из-за лимита
    assert_not_includes result[:message], 'лимит' if result[:message]
  end

  # Тесты remove_channel_for_user

  test 'remove_channel_for_user returns error for invalid format' do
    result = @service.remove_channel_for_user(@user, 'invalid!')

    assert_not result[:success]
    assert_includes result[:message], 'Неверный формат'
  end

  test 'remove_channel_for_user returns error for non-existent channel' do
    result = @service.remove_channel_for_user(@user, '@nonexistent')

    assert_not result[:success]
    assert_includes result[:message], 'не найден в твоих подписках'
  end

  test 'remove_channel_for_user returns error for non-subscribed channel' do
    # Создаем канал, но не подписываем пользователя
    channel = Channel.create!(
      telegram_id: 3001,
      username: 'testchannel_not_subscribed',
      title: 'Test Channel Not Subscribed'
    )

    result = @service.remove_channel_for_user(@user, '@testchannel_not_subscribed')

    assert_not result[:success]
    assert_includes result[:message], 'не подписан на канал'
  end

  test 'remove_channel_for_user successfully removes subscribed channel' do
    # Создаем канал и подписку
    channel = Channel.create!(
      telegram_id: 3002,
      username: 'testchannel_subscribed',
      title: 'Test Channel Subscribed'
    )

    subscription = Subscription.create!(
      telegram_user: @user,
      channel: channel,
      active: true
    )

    result = @service.remove_channel_for_user(@user, '@testchannel_subscribed')

    assert result[:success]
    assert_includes result[:message], 'Канал @testchannel_subscribed удалён'
    assert_includes result[:message], 'Всего каналов: 0'
    assert_equal channel, result[:channel]

    # Проверяем что подписка деактивирована
    subscription.reload
    assert_not subscription.active
  end

  test 'remove_channel_for_user works with different username formats' do
    # Тестируем разные форматы
    formats = [ '@testchannel_formats', 'testchannel_formats', 't.me/testchannel_formats', 'https://t.me/testchannel_formats' ]

    formats.each_with_index do |format, i|
      # Создаем уникальный канал для каждого формата
      channel = Channel.create!(
        telegram_id: 3003 + i,
        username: "testchannel_formats_#{i}",
        title: "Test Channel Formats #{i}"
      )

      # Создаем подписку
      subscription = Subscription.create!(
        telegram_user: @user,
        channel: channel,
        active: true
      )

      # Используем модифицированный формат, который парсится в тот же username
      modified_format = format.gsub('testchannel_formats', "testchannel_formats_#{i}")

      result = @service.remove_channel_for_user(@user, modified_format)

      assert result[:success], "Failed for format: #{modified_format}"
      assert_includes result[:message], "@testchannel_formats_#{i} удалён"

      # Проверяем деактивацию
      subscription.reload
      assert_not subscription.active
    end
  end

  # Тесты деактивации каналов с уведомлениями

  test 'deactivate_channel_with_notifications! successfully deactivates active channel and enqueues notifications' do
    # Создаем канал и подписчиков
    channel = Channel.create!(
      telegram_id: 4001,
      username: 'testchannel_active',
      title: 'Test Channel Active',
      active: true
    )

    # Создаем подписчиков
    users = []
    3.times do |i|
      user = TelegramUser.create!(
        telegram_id: 2000 + i,
        username: "user#{i}",
        first_name: "User #{i}",
        language_code: 'ru'
      )
      users << user
      Subscription.create!(
        telegram_user: user,
        channel: channel,
        active: true
      )
    end

    # Мокаем очередь
    ChannelDeactivationNotificationJob.expects(:perform_later)
      .with(channel, reason: 'admin_decision')
      .once

    result = @service.deactivate_channel_with_notifications!(channel, reason: 'admin_decision')

    assert result[:success]
    assert_includes result[:message], 'Канал @testchannel_active деактивирован'
    assert_includes result[:message], '3 подписчиков'

    # Проверяем что канал деактивирован
    channel.reload
    assert_not channel.active
  end

  test 'deactivate_channel_with_notifications! returns error for already inactive channel' do
    channel = Channel.create!(
      telegram_id: 4002,
      username: 'testchannel_inactive',
      title: 'Test Channel Inactive',
      active: false
    )

    result = @service.deactivate_channel_with_notifications!(channel)

    assert_not result[:success]
    assert_includes result[:message], 'уже неактивен'
  end

  test 'deactivate_channel_with_notifications! works without reason' do
    channel = Channel.create!(
      telegram_id: 4003,
      username: 'testchannel_no_reason',
      title: 'Test Channel No Reason',
      active: true
    )

    # Создаем подписчика
    user = TelegramUser.create!(
      telegram_id: 2003,
      username: 'user3',
      first_name: 'User 3',
      language_code: 'ru'
    )
    Subscription.create!(
      telegram_user: user,
      channel: channel,
      active: true
    )

    # Мокаем очередь
    ChannelDeactivationNotificationJob.expects(:perform_later)
      .with(channel, reason: nil)
      .once

    result = @service.deactivate_channel_with_notifications!(channel)

    assert result[:success]
    assert_includes result[:message], 'Канал @testchannel_no_reason деактивирован'
  end

  test 'deactivate_channel_with_notifications! counts only active subscriptions' do
    channel = Channel.create!(
      telegram_id: 4004,
      username: 'testchannel_mixed',
      title: 'Test Channel Mixed',
      active: true
    )

    # Создаем активных подписчиков
    2.times do |i|
      user = TelegramUser.create!(
        telegram_id: 2004 + i,
        username: "user_active#{i}",
        first_name: "User Active #{i}",
        language_code: 'ru'
      )
      Subscription.create!(
        telegram_user: user,
        channel: channel,
        active: true
      )
    end

    # Создаем неактивных подписчиков
    2.times do |i|
      user = TelegramUser.create!(
        telegram_id: 2006 + i,
        username: "user_inactive#{i}",
        first_name: "User Inactive #{i}",
        language_code: 'ru'
      )
      Subscription.create!(
        telegram_user: user,
        channel: channel,
        active: false
      )
    end

    # Мокаем очередь
    ChannelDeactivationNotificationJob.expects(:perform_later)
      .with(channel, reason: nil)
      .once

    result = @service.deactivate_channel_with_notifications!(channel)

    assert result[:success]
    assert_includes result[:message], '2 подписчиков'  # Только активные
  end

  test 'deactivate_channel_with_notifications! handles channel with no subscribers' do
    channel = Channel.create!(
      telegram_id: 4005,
      username: 'testchannel_empty',
      title: 'Test Channel Empty',
      active: true
    )

    # Мокаем очередь
    ChannelDeactivationNotificationJob.expects(:perform_later)
      .with(channel, reason: nil)
      .once

    result = @service.deactivate_channel_with_notifications!(channel)

    assert result[:success]
    assert_includes result[:message], '0 подписчиков'
  end

  test 'deactivate_channel_with_notifications! handles errors gracefully' do
    channel = Channel.create!(
      telegram_id: 4006,
      username: 'testchannel_error',
      title: 'Test Channel Error',
      active: true
    )

    # Мокаем канал чтобы вызвать ошибку при деактивации
    channel.stubs(:deactivate!).raises(StandardError.new('Database error'))

    result = @service.deactivate_channel_with_notifications!(channel)

    assert_not result[:success]
    assert_includes result[:message], 'Ошибка при деактивации канала'
    assert_includes result[:message], 'Database error'

    # Проверяем что уведомления не отправлялись
    ChannelDeactivationNotificationJob.expects(:perform_later).never
  end
end
