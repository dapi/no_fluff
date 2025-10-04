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
      priority: 5,
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
        priority: 5,
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
end
