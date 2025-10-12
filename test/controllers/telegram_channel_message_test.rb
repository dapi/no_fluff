require 'test_helper'

class TelegramChannelMessageTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset if @bot
  end

  def create_channel_message_update(message_id: 123, channel_id: -1001234567890, text: 'Test channel message')
    {
      'update_id' => 1,
      'message' => {
        'message_id' => message_id,
        'chat' => {
          'id' => channel_id,
          'username' => 'testchannel',
          'title' => 'Test Channel',
          'type' => 'channel'
        },
        'date' => 1640995200,
        'text' => text,
        'from' => {
          'id' => 987654321,
          'first_name' => 'Test',
          'username' => 'testuser'
        }
      }
    }
  end

  def create_direct_message_update(message_id: 123, user_id: 123456, text: 'Hello bot')
    {
      'update_id' => 2,
      'message' => {
        'message_id' => message_id,
        'from' => {
          'id' => user_id,
          'username' => 'testuser',
          'first_name' => 'Test',
          'last_name' => 'User',
          'language_code' => 'ru',
          'is_premium' => false
        },
        'chat' => { 'id' => user_id, 'type' => 'private' },
        'text' => text
      }
    }
  end

  def send_webhook_update(update)
    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }
  end

  test 'channel text message is saved without response' do
    initial_count = ChannelMessage.count

    update = create_channel_message_update(text: 'Hello from channel')
    send_webhook_update(update)

    assert_response :success

    # Проверяем что сообщение сохранено
    assert_equal initial_count + 1, ChannelMessage.count

    saved_message = ChannelMessage.last
    assert_equal 123, saved_message.message_id
    assert_equal -1001234567890, saved_message.channel_id
    assert_equal 'testchannel', saved_message.channel_username
    assert_equal 'Test Channel', saved_message.channel_title
    assert_equal 'Hello from channel', saved_message.content
    assert_equal 'text', saved_message.message_type
    assert_equal 987654321, saved_message.sender_id
    assert_equal 'testuser', saved_message.sender_username
    assert_equal 'Test', saved_message.sender_first_name

    # Проверяем что бот НЕ отправил ответ
    assert_empty @bot.requests, 'Bot should not respond to channel messages'
  end

  test 'channel photo message is saved correctly' do
    update = create_channel_message_update
    update['message'].delete('text')
    update['message']['photo'] = [
      {
        'file_id' => 'Abc123',
        'file_size' => 1234,
        'width' => 800,
        'height' => 600
      }
    ]
    update['message']['caption'] = 'Beautiful photo'

    initial_count = ChannelMessage.count
    send_webhook_update(update)

    assert_response :success
    assert_equal initial_count + 1, ChannelMessage.count

    saved_message = ChannelMessage.last
    assert_equal 'Beautiful photo', saved_message.content
    assert_equal 'photo', saved_message.message_type
    assert_empty @bot.requests
  end

  test 'channel sticker message is saved correctly' do
    update = create_channel_message_update
    update['message'].delete('text')
    update['message']['sticker'] = {
      'file_id' => 'Sticker123',
      'width' => 512,
      'height' => 512,
      'emoji' => '😀',
      'set_name' => 'TestSet'
    }

    initial_count = ChannelMessage.count
    send_webhook_update(update)

    assert_response :success
    assert_equal initial_count + 1, ChannelMessage.count

    saved_message = ChannelMessage.last
    assert_equal '😀', saved_message.content
    assert_equal 'sticker', saved_message.message_type
    assert_empty @bot.requests
  end

  test 'channel document message is saved correctly' do
    update = create_channel_message_update
    update['message'].delete('text')
    update['message']['document'] = {
      'file_id' => 'Doc123',
      'file_name' => 'test_document.pdf',
      'mime_type' => 'application/pdf',
      'file_size' => 1024
    }

    initial_count = ChannelMessage.count
    send_webhook_update(update)

    assert_response :success
    assert_equal initial_count + 1, ChannelMessage.count

    saved_message = ChannelMessage.last
    assert_equal 'test_document.pdf', saved_message.content
    assert_equal 'document', saved_message.message_type
    assert_empty @bot.requests
  end

  test 'direct message is processed normally' do
    update = create_direct_message_update(text: 'Hello bot')

    send_webhook_update(update)

    assert_response :success

    # Проверяем что бот отправил ответ
    assert_not_empty @bot.requests

    # Проверяем что сообщение НЕ было сохранено в ChannelMessage
    assert_equal 0, ChannelMessage.count

    # Проверяем ответное сообщение
    send_message_request = @bot.requests.find { |method, _| method == :sendMessage }
    assert_not_nil send_message_request

    message_params = send_message_request[1].first
    assert_includes message_params[:text], 'Вы написали: Hello bot'
  end

  test 'direct message with channel link is processed as channel addition' do
    update = create_direct_message_update(text: '@testchannel')

    send_webhook_update(update)

    assert_response :success

    # Проверяем что бот отправил ответ (попытка добавить канал)
    assert_not_empty @bot.requests

    # Проверяем что сообщение НЕ было сохранено в ChannelMessage
    assert_equal 0, ChannelMessage.count
  end

  test 'multiple channel messages are saved separately' do
    updates = [
      create_channel_message_update(message_id: 100, text: 'First message'),
      create_channel_message_update(message_id: 101, text: 'Second message'),
      create_channel_message_update(message_id: 102, text: 'Third message')
    ]

    initial_count = ChannelMessage.count

    updates.each do |update|
      @bot.reset
      send_webhook_update(update)
      assert_response :success
      assert_empty @bot.requests
    end

    assert_equal initial_count + 3, ChannelMessage.count

    saved_messages = ChannelMessage.last(3)
    assert_equal [ 'First message', 'Second message', 'Third message' ],
                 saved_messages.map(&:content)
  end

  test 'channel message without sender is handled gracefully' do
    update = create_channel_message_update
    update['message'].delete('from')

    initial_count = ChannelMessage.count
    send_webhook_update(update)

    assert_response :success
    assert_equal initial_count + 1, ChannelMessage.count

    saved_message = ChannelMessage.last
    assert_nil saved_message.sender_id
    assert_nil saved_message.sender_username
    assert_empty @bot.requests
  end

  test 'channel message with all content types handled correctly' do
    # Тестируем только video тип
    @bot.reset

    update = create_channel_message_update
    update['message'].delete('text')
    update['message']['video'] = { 'file_id' => 'video123' }
    update['message']['caption'] = 'Video caption'

    initial_count = ChannelMessage.count
    send_webhook_update(update)

    assert_response :success
    assert_equal initial_count + 1, ChannelMessage.count

    saved_message = ChannelMessage.last
    assert_equal 'Video caption', saved_message.content
    assert_equal 'video', saved_message.message_type
    assert_empty @bot.requests
  end

  test 'channel message raw_data is preserved' do
    update = create_channel_message_update(text: 'Test raw data')

    send_webhook_update(update)

    assert_response :success

    saved_message = ChannelMessage.last
    assert_not_nil saved_message.raw_data
    assert_equal 'Test raw data', saved_message.raw_data['text']
    assert_equal -1001234567890, saved_message.raw_data['chat']['id']
    assert_equal 'channel', saved_message.raw_data['chat']['type']
    assert_empty @bot.requests
  end

  test 'channel messages from different channels are saved separately' do
    channel1_update = create_channel_message_update(
      channel_id: -1001111111111,
      text: 'Channel 1 message'
    )

    channel2_update = create_channel_message_update(
      channel_id: -1002222222222,
      text: 'Channel 2 message'
    )

    initial_count = ChannelMessage.count

    # Сообщение из первого канала
    send_webhook_update(channel1_update)
    assert_response :success
    assert_equal initial_count + 1, ChannelMessage.count
    assert_empty @bot.requests

    # Сообщение из второго канала
    @bot.reset
    send_webhook_update(channel2_update)
    assert_response :success
    assert_equal initial_count + 2, ChannelMessage.count
    assert_empty @bot.requests

    # Проверяем что сообщения сохранены правильно
    messages = ChannelMessage.last(2)
    channel1_message = messages.find { |m| m.channel_id == -1001111111111 }
    channel2_message = messages.find { |m| m.channel_id == -1002222222222 }

    assert_not_nil channel1_message
    assert_not_nil channel2_message
    assert_equal 'Channel 1 message', channel1_message.content
    assert_equal 'Channel 2 message', channel2_message.content
  end

  test 'same message_id from different channels is allowed' do
    channel1_update = create_channel_message_update(
      message_id: 999,
      channel_id: -1001111111111,
      text: 'Same ID different channel 1'
    )

    channel2_update = create_channel_message_update(
      message_id: 999,
      channel_id: -1002222222222,
      text: 'Same ID different channel 2'
    )

    initial_count = ChannelMessage.count

    # Первое сообщение
    send_webhook_update(channel1_update)
    assert_response :success
    assert_equal initial_count + 1, ChannelMessage.count
    assert_empty @bot.requests

    # Второе сообщение с тем же ID но из другого канала
    @bot.reset
    send_webhook_update(channel2_update)
    assert_response :success
    assert_equal initial_count + 2, ChannelMessage.count
    assert_empty @bot.requests

    # Проверяем что оба сообщения сохранены
    messages = ChannelMessage.last(2)
    assert_equal 2, messages.count
    assert_includes messages.map(&:content), 'Same ID different channel 1'
    assert_includes messages.map(&:content), 'Same ID different channel 2'
  end
end
