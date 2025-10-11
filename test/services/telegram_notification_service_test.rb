require 'test_helper'

class TelegramNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @bot = Telegram.bot
    @service = TelegramNotificationService.new(@bot)
    @user = telegram_users(:one)
    @channel = Channel.create!(
      telegram_id: 5001,
      username: 'testchannel',
      title: 'Test Channel',
      active: false
    )
  end

  test 'send_channel_deactivation_notification returns error when user has no chat_id' do
    @user.update!(chat_id: nil)

    result = @service.send_channel_deactivation_notification(@user, @channel, 'admin_decision')

    assert_not result[:success]
    assert_equal 'User has no chat_id', result[:error]
  end

  test 'send_channel_deactivation_notification sends message with known reason' do
    @user.update!(chat_id: 12345)

    # Мокаем успешную отправку сообщения
    @bot.expects(:send_message).with(
      chat_id: 12345,
      text: anything,
      parse_mode: 'Markdown',
      reply_markup: anything
    ).returns({ 'ok' => true })

    result = @service.send_channel_deactivation_notification(@user, @channel, 'admin_decision')

    assert result[:success]
  end

  test 'send_channel_deactivation_notification sends message with custom reason' do
    @user.update!(chat_id: 12345)

    @bot.expects(:send_message).with(
      chat_id: 12345,
      text: anything,
      parse_mode: 'Markdown',
      reply_markup: anything
    ).returns({ 'ok' => true })

    result = @service.send_channel_deactivation_notification(@user, @channel, 'Custom reason text')

    assert result[:success]
  end

  test 'send_channel_deactivation_notification sends message without reason' do
    @user.update!(chat_id: 12345)

    @bot.expects(:send_message).with(
      chat_id: 12345,
      text: anything,
      parse_mode: 'Markdown',
      reply_markup: anything
    ).returns({ 'ok' => true })

    result = @service.send_channel_deactivation_notification(@user, @channel)

    assert result[:success]
  end

  test 'send_channel_deactivation_notification handles Telegram API error' do
    @user.update!(chat_id: 12345)

    @bot.expects(:send_message).returns({
      'ok' => false,
      'description' => 'Bad Request: chat not found'
    })

    result = @service.send_channel_deactivation_notification(@user, @channel)

    assert_not result[:success]
    assert_equal 'Bad Request: chat not found', result[:error]
  end

  test 'send_channel_deactivation_notification handles network errors' do
    @user.update!(chat_id: 12345)

    @bot.expects(:send_message).raises(StandardError.new('Network error'))

    result = @service.send_channel_deactivation_notification(@user, @channel)

    assert_not result[:success]
    assert_equal 'Network error', result[:error]
  end

  test 'send_channel_deactivation_notification logs errors to Bugsnag' do
    @user.update!(chat_id: 12345)

    @bot.expects(:send_message).raises(StandardError.new('Test error'))
    Bugsnag.expects(:notify).with do |error, &block|
      error.message == 'Test error' && block_given?
    end

    result = @service.send_channel_deactivation_notification(@user, @channel)

    assert_not result[:success]
  end

  test 'send_admin_deactivation_notification sends admin message' do
    admin_chat_id = 54321
    stats = { sent: 10, errors: 2, total: 12 }

    @bot.expects(:send_message).with(
      chat_id: admin_chat_id,
      text: anything,
      parse_mode: 'Markdown',
      reply_markup: nil
    ).returns({ 'ok' => true })

    result = @service.send_admin_deactivation_notification(admin_chat_id, @channel, stats)

    assert result[:success]
  end

  test 'send_admin_deactivation_notification handles Telegram API error' do
    admin_chat_id = 54321
    stats = { sent: 5, errors: 1, total: 6 }

    @bot.expects(:send_message).returns({
      'ok' => false,
      'description' => 'Forbidden: bot was blocked by the user'
    })

    result = @service.send_admin_deactivation_notification(admin_chat_id, @channel, stats)

    assert_not result[:success]
    assert_equal 'Forbidden: bot was blocked by the user', result[:error]
  end

  test 'send_admin_deactivation_notification logs errors to Bugsnag' do
    admin_chat_id = 54321
    stats = { sent: 3, errors: 0, total: 3 }

    @bot.expects(:send_message).raises(StandardError.new('Admin notification error'))
    Bugsnag.expects(:notify).with do |error, &block|
      error.message == 'Admin notification error' && block_given?
    end

    result = @service.send_admin_deactivation_notification(admin_chat_id, @channel, stats)

    assert_not result[:success]
  end

  test 'build_deactivation_message includes known reason text' do
    # Проверяем через публичный интерфейс
    @user.update!(chat_id: 12345)
    @bot.expects(:send_message).with do |options|
      # Проверяем что сообщение содержит текст причины
      options[:text].include?('Решение администратора')
    end.returns({ 'ok' => true })

    @service.send_channel_deactivation_notification(@user, @channel, 'admin_decision')
  end

  test 'build_deactivation_message includes custom reason text' do
    @user.update!(chat_id: 12345)
    @bot.expects(:send_message).with do |options|
      options[:text].include?('Custom violation reason')
    end.returns({ 'ok' => true })

    @service.send_channel_deactivation_notification(@user, @channel, 'Custom violation reason')
  end

  test 'build_notification_keyboard includes correct buttons' do
    @user.update!(chat_id: 12345)
    @bot.expects(:send_message).with do |options|
      keyboard = options[:reply_markup][:inline_keyboard]
      button_texts = keyboard.flatten.map { |btn| btn[:text] }

      button_texts.include?('🔍 Посмотреть каталог каналов') &&
      button_texts.include?('⚙️ Настройки уведомлений')
    end.returns({ 'ok' => true })

    @service.send_channel_deactivation_notification(@user, @channel)
  end

  test 'deactivation reasons mapping includes all expected reasons' do
    expected_reasons = %w[admin_decision inactive violation technical]
    actual_reasons = TelegramNotificationService::DEACTIVATION_REASONS.keys

    assert_equal expected_reasons.sort, actual_reasons.sort
  end
end