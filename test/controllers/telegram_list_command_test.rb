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

  test 'user does /list and sees 2 subscribed channels with only delete buttons' do
    # Создаем 2 канала и подписываем пользователя
    channel1 = Channel.create!(telegram_id: 1001, username: 'channel1', title: 'First Channel')
    channel2 = Channel.create!(telegram_id: 1002, username: 'channel2', title: 'Second Channel')

    Subscription.create!(telegram_user: @user, channel: channel1, priority: 10, active: true)
    Subscription.create!(telegram_user: @user, channel: channel2, priority: 5, active: true)

    # Отправляем команду /list
    update = create_user_update(command: '/list')
    send_webhook_update(update)

    assert_response :success

    # Проверяем ответ
    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content

    # Проверяем что оба канала есть в списке
    assert_includes message_content[:text], 'First Channel'
    assert_includes message_content[:text], 'Second Channel'
    assert_includes message_content[:text], 'Всего каналов: 2'

    # Проверяем что есть клавиатура с кнопками
    assert_not_nil message_content[:reply_markup]
    keyboard = message_content[:reply_markup][:inline_keyboard]
    assert_equal 2, keyboard.length

    # Проверяем что у каждого канала только одна кнопка удаления
    keyboard.each do |row|
      assert_equal 1, row.length, 'Each channel should have exactly one button'
      button = row.first
      assert_equal '🗑️', button[:text], 'Button should be delete button'
      assert_includes button[:callback_data], 'remove_channel:', 'Button should trigger remove callback'
    end
  end
end