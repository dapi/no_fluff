require 'test_helper'

class TelegramListCommandTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset

    @user = TelegramUser.create!(
      username: 'list_test_user',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )
  end

  teardown do
    @bot.reset if @bot
  end

  def create_user_update(user_id: @user.id, username: @user.username, command: '/list')
    {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
        'from' => {
          'id' => user_id,
          'username' => username,
          'first_name' => 'Test',
          'language_code' => 'ru'
        },
        'chat' => { 'id' => user_id, 'type' => 'private' },
        'text' => command
      }
    }
  end

  def create_callback_update(user_id: @user.id, username: @user.username, data: 'test:')
    {
      'update_id' => 1,
      'callback_query' => {
        'id' => 'callback_1',
        'from' => {
          'id' => user_id,
          'username' => username,
          'first_name' => 'Test'
        },
        'message' => {
          'message_id' => 10,
          'chat' => { 'id' => user_id, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => data
      }
    }
  end

  def send_webhook_update(update)
    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }
  end

  def extract_message_content(requests)
    message_requests = requests.select { |method, _| method == :sendMessage }
    return nil if message_requests.empty?

    method, params = message_requests.first
    params.first
  end

  def extract_edited_message_content(requests)
    edit_requests = requests.select { |method, _| method == :editMessageText }
    return nil if edit_requests.empty?

    method, params = edit_requests.first
    params.first
  end

  # Тесты для команды /list

  test 'list command with no subscriptions shows empty message' do
    update = create_user_update(command: '/list')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.channels.list.empty')
    assert_nil message_content[:reply_markup]  # Не должно быть клавиатуры
  end

  test 'list command with subscriptions shows simplified keyboard without priority buttons' do
    # Создаем тестовые каналы и подписки
    channel1 = Channel.create!(telegram_id: 1001, username: 'channel1', title: 'Test Channel 1')
    channel2 = Channel.create!(telegram_id: 1002, username: 'channel2', title: 'Test Channel 2')
    channel3 = Channel.create!(telegram_id: 1003, username: 'channel3', title: 'Test Channel 3')

    Subscription.create!(telegram_user: @user, channel: channel1, priority: 10, active: true)
    Subscription.create!(telegram_user: @user, channel: channel2, priority: 5, active: true)
    Subscription.create!(telegram_user: @user, channel: channel3, priority: 1, active: true)

    update = create_user_update(command: '/list')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content

    # Проверяем текст сообщения
    assert_includes message_content[:text], I18n.t('telegram_bot.channels.list.title')
    assert_includes message_content[:text], 'Всего каналов: 3'
    assert_includes message_content[:text], 'Test Channel 1'
    assert_includes message_content[:text], 'Test Channel 2'
    assert_includes message_content[:text], 'Test Channel 3'

    # Проверяем что клавиатура есть
    assert_not_nil message_content[:reply_markup]
    keyboard = message_content[:reply_markup][:inline_keyboard]

    # Проверяем что есть только 3 строки (по одной на канал)
    assert_equal 3, keyboard.length

    # Проверяем что в каждой строке только одна кнопка (кнопка удаления)
    keyboard.each do |row|
      assert_equal 1, row.length, 'Each row should have exactly one button'
      button = row.first
      assert_equal '🗑️', button[:text], 'Button should be delete button'
      assert_includes button[:callback_data], 'remove_channel:', 'Button should trigger remove callback'
    end

    # Проверяем что порядок каналов соответствует приоритету (от высокого к низкому)
    assert message_content[:text].include?('Test Channel 1 (приоритет: 10)')
    assert message_content[:text].include?('Test Channel 2 (приоритет: 5)')
    assert message_content[:text].include?('Test Channel 3 (приоритет: 1)')

    # Проверяем что кнопки соответствуют порядку каналов
    assert_includes keyboard[0][0][:callback_data], "remove_channel:#{channel1.id}"
    assert_includes keyboard[1][0][:callback_data], "remove_channel:#{channel2.id}"
    assert_includes keyboard[2][0][:callback_data], "remove_channel:#{channel3.id}"
  end

  test 'list command callback my_subscriptions works the same as direct command' do
    # Создаем подписки
    channel = Channel.create!(telegram_id: 2001, username: 'my_channel', title: 'My Test Channel')
    Subscription.create!(telegram_user: @user, channel: channel, priority: 5, active: true)

    # Тестируем callback
    update = create_callback_update(data: 'my_subscriptions:')
    send_webhook_update(update)

    assert_response :success

    # Проверяем что callback query был обработан
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем что сообщение было отредактировано
    edit_content = extract_edited_message_content(@bot.requests)
    assert_not_nil edit_content
    assert_includes edit_content[:text], 'My Test Channel'
    assert_not_nil edit_content[:reply_markup]

    # Проверяем что клавиатура такая же простая (только кнопки удаления)
    keyboard = edit_content[:reply_markup][:inline_keyboard]
    assert_equal 1, keyboard.length
    assert_equal 1, keyboard[0].length
    assert_equal '🗑️', keyboard[0][0][:text]
    assert_includes keyboard[0][0][:callback_data], "remove_channel:#{channel.id}"
  end

  test 'remove_channel callback shows confirmation dialog' do
    # Создаем подписку
    channel = Channel.create!(telegram_id: 3001, username: 'remove_me', title: 'Remove Me Channel')
    Subscription.create!(telegram_user: @user, channel: channel, priority: 5, active: true)

    # Сначала показываем список
    update1 = create_user_update(command: '/list')
    send_webhook_update(update1)
    @bot.reset

    # Нажимаем кнопку удаления
    update2 = create_callback_update(data: "remove_channel:#{channel.id}")
    send_webhook_update(update2)

    assert_response :success

    # Проверяем что callback query был обработан
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем что появилось диалог подтверждения
    edit_content = extract_edited_message_content(@bot.requests)
    assert_not_nil edit_content
    assert_includes edit_content[:text], I18n.t('telegram_bot.channels.list.confirm_remove', channel: '@remove_me')

    # Проверяем что есть клавиатура с кнопками подтверждения
    assert_not_nil edit_content[:reply_markup]
    keyboard = edit_content[:reply_markup][:inline_keyboard]
    assert_equal 1, keyboard.length
    assert_equal 2, keyboard[0].length  # Кнопка удаления и отмена

    # Проверяем что кнопка подтверждения содержит правильный channel_id
    remove_button = keyboard[0].find { |btn| btn[:text] == '🗑️' }
    assert_not_nil remove_button
    assert_includes remove_button[:callback_data], "confirm_remove:#{channel.id}"
  end

  test 'confirm_remove callback removes subscription and updates list' do
    # Создаем 2 канала
    channel1 = Channel.create!(telegram_id: 4001, username: 'keep_me', title: 'Keep Me Channel')
    channel2 = Channel.create!(telegram_id: 4002, username: 'remove_me', title: 'Remove Me Channel')

    subscription1 = Subscription.create!(telegram_user: @user, channel: channel1, priority: 10, active: true)
    subscription2 = Subscription.create!(telegram_user: @user, channel: channel2, priority: 5, active: true)

    # Удаляем второй канал
    update = create_callback_update(data: "confirm_remove:#{channel2.id}")
    send_webhook_update(update)

    assert_response :success

    # Проверяем что подписка деактивирована
    subscription2.reload
    assert_not subscription2.active

    # Проверяем что сообщение обновлено с новым списком
    edit_content = extract_edited_message_content(@bot.requests)
    assert_not_nil edit_content

    # Сначала проверяем сообщение об удалении
    assert_includes edit_content[:text], I18n.t('telegram_bot.channels.list.remove_success', channel: '@remove_me')

    # Затем проверяем что оставшийся канал есть в списке
    assert_includes edit_content[:text], 'Keep Me Channel'
    assert_not_includes edit_content[:text], 'Remove Me Channel'

    # Проверяем что в клавиатуре только одна кнопка для оставшегося канала
    keyboard = edit_content[:reply_markup][:inline_keyboard]
    assert_equal 1, keyboard.length
    assert_equal 1, keyboard[0].length
    assert_includes keyboard[0][0][:callback_data], "remove_channel:#{channel1.id}"
  end

  test 'priority_up and priority_down callbacks are not handled anymore' do
    # Создаем подписку
    channel = Channel.create!(telegram_id: 5001, username: 'test_priority', title: 'Priority Test Channel')
    subscription = Subscription.create!(telegram_user: @user, channel: channel, priority: 5, active: true)

    # Пытаемся вызвать старые callback'и для изменения приоритета
    ["priority_up:#{channel.id}", "priority_down:#{channel.id}"].each do |callback_data|
      @bot.reset

      update = create_callback_update(data: callback_data)
      send_webhook_update(update)

      assert_response :success

      # Проверяем что callback query НЕ был обработан (нет обработчика)
      answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
      assert_nil answer_request, "Callback query should not be answered for priority callbacks: #{callback_data}"

      # Проверяем что сообщение НЕ было изменено (нет обработчика)
      edit_content = extract_edited_message_content(@bot.requests)
      assert_nil edit_content, "Message should not be edited for priority callbacks: #{callback_data}"

      # Проверяем что приоритет не изменился
      subscription.reload
      assert_equal 5, subscription.priority
    end
  end

  test 'list command maintains correct order by priority' do
    # Создаем каналы в разном порядке
    channel3 = Channel.create!(telegram_id: 6003, username: 'channel3', title: 'Channel Priority 3')
    channel1 = Channel.create!(telegram_id: 6001, username: 'channel1', title: 'Channel Priority 1')
    channel2 = Channel.create!(telegram_id: 6002, username: 'channel2', title: 'Channel Priority 2')

    # Создаем подписки в разном порядке
    Subscription.create!(telegram_user: @user, channel: channel3, priority: 3, active: true)
    Subscription.create!(telegram_user: @user, channel: channel1, priority: 1, active: true)
    Subscription.create!(telegram_user: @user, channel: channel2, priority: 2, active: true)

    update = create_user_update(command: '/list')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content

    # Проверяем что порядок в тексте соответствует приоритету (1, 2, 3)
    text_lines = message_content[:text].split("\n")

    # Находим строки с каналами
    channel_lines = text_lines.select { |line| line.include?('Channel Priority') }

    # Проверяем порядок (от высокого приоритета к низкому)
    # Приоритеты: 3 > 2 > 1, поэтому порядок будет 3, 2, 1
    assert channel_lines[0].include?('Channel Priority 3 (приоритет: 3)')
    assert channel_lines[1].include?('Channel Priority 2 (приоритет: 2)')
    assert channel_lines[2].include?('Channel Priority 1 (приоритет: 1)')

    # Проверяем что порядок кнопок соответствует порядку каналов
    keyboard = message_content[:reply_markup][:inline_keyboard]
    assert_equal 3, keyboard.length

    # Находим каналы по приоритету в списке (от высокого к низкому)
    # channel3 (priority: 3) > channel2 (priority: 2) > channel1 (priority: 1)
    assert_includes keyboard[0][0][:callback_data], "remove_channel:#{channel3.id}"  # Priority 3
    assert_includes keyboard[1][0][:callback_data], "remove_channel:#{channel2.id}"  # Priority 2
    assert_includes keyboard[2][0][:callback_data], "remove_channel:#{channel1.id}"  # Priority 1
  end

  test 'list command ignores inactive subscriptions' do
    # Создаем активную и неактивную подписки
    active_channel = Channel.create!(telegram_id: 7001, username: 'active_channel', title: 'Active Channel')
    inactive_channel = Channel.create!(telegram_id: 7002, username: 'inactive_channel', title: 'Inactive Channel')

    Subscription.create!(telegram_user: @user, channel: active_channel, priority: 10, active: true)
    Subscription.create!(telegram_user: @user, channel: inactive_channel, priority: 5, active: false)

    update = create_user_update(command: '/list')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content

    # Проверяем что только активный канал в списке
    assert_includes message_content[:text], 'Active Channel'
    assert_not_includes message_content[:text], 'Inactive Channel'
    assert_includes message_content[:text], 'Всего каналов: 1'

    # Проверяем что только одна кнопка
    keyboard = message_content[:reply_markup][:inline_keyboard]
    assert_equal 1, keyboard.length
    assert_includes keyboard[0][0][:callback_data], "remove_channel:#{active_channel.id}"
  end

  test 'list command handles edge case with mixed active/inactive subscriptions' do
    # Создаем несколько подписок, некоторые неактивные
    channel1 = Channel.create!(telegram_id: 8001, username: 'active1', title: 'Active Channel 1')
    channel2 = Channel.create!(telegram_id: 8002, username: 'inactive1', title: 'Inactive Channel 1')
    channel3 = Channel.create!(telegram_id: 8003, username: 'active2', title: 'Active Channel 2')
    channel4 = Channel.create!(telegram_id: 8004, username: 'inactive2', title: 'Inactive Channel 2')

    Subscription.create!(telegram_user: @user, channel: channel1, priority: 10, active: true)
    Subscription.create!(telegram_user: @user, channel: channel2, priority: 8, active: false)
    Subscription.create!(telegram_user: @user, channel: channel3, priority: 6, active: true)
    Subscription.create!(telegram_user: @user, channel: channel4, priority: 4, active: false)

    update = create_user_update(command: '/list')
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content

    # Проверяем что только активные каналы в списке
    assert_includes message_content[:text], 'Active Channel 1'
    assert_includes message_content[:text], 'Active Channel 2'
    assert_not_includes message_content[:text], 'Inactive Channel 1'
    assert_not_includes message_content[:text], 'Inactive Channel 2'
    assert_includes message_content[:text], 'Всего каналов: 2'

    # Проверяем что только две кнопки для активных каналов
    keyboard = message_content[:reply_markup][:inline_keyboard]
    assert_equal 2, keyboard.length

    # Проверяем что порядок соответствует приоритету активных каналов
    assert_includes keyboard[0][0][:callback_data], "remove_channel:#{channel1.id}"  # Priority 10
    assert_includes keyboard[1][0][:callback_data], "remove_channel:#{channel3.id}"  # Priority 6
  end
end