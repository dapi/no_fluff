require 'test_helper'

class BotChannelJoinIntegrationTest < ActionDispatch::IntegrationTest
  test 'complete workflow: add channel -> bot joins -> process posts' do
    # Создаем пользователя
    user = telegram_users(:one)

    # Создаем мок для успешного ответа Telegram API
    mock_bot = Minitest::Mock.new
    mock_channel_info = {
      'ok' => true,
      'result' => {
        'id' => -1001234567890,
        'title' => 'Test Channel',
        'username' => 'test_channel',
        'description' => 'Test description',
        'member_count' => 1000
      }
    }
    mock_bot.expect(:get_chat, mock_channel_info, [ { chat_id: -1001234567890 } ])

    Telegram.stub(:bots, { default: mock_bot }) do
      # 1. Пользователь добавляет канал через ChannelService
      service = Telegram::ChannelService.new(mock_bot)
      result = service.add_channel_for_user(user, 'test_channel')

      assert result[:success], 'Channel should be added successfully'
      channel = result[:channel]
      assert_equal 'not_joined', channel.bot_join_status

      # 2. BotJoinJob выполняется и успешно вступает в канал
      Channels::BotJoinJob.perform_now(channel.id)
      channel.reload
      assert_equal 'joined', channel.bot_join_status
      assert_not_nil channel.bot_join_at
      assert_nil channel.bot_join_error

      # 3. Пост из канала обрабатывается успешно
      post_data = {
        telegram_message_id: 123,
        text: 'Test post',
        media_urls: [],
        published_at: Time.current
      }

      Content::ProcessPostJob.perform_now(channel.id, post_data)

      # Проверяем, что пост был создан
      post = Post.find_by(telegram_message_id: 123)
      assert_not_nil post
      assert_equal channel.id, post.channel_id
      assert_equal 'Test post', post.text
    end
  end

  test 'workflow with failed bot join' do
    # Создаем пользователя
    user = telegram_users(:one)

    # Создаем мок для неуспешного ответа Telegram API
    mock_bot = Minitest::Mock.new
    mock_channel_info = {
      'ok' => true,
      'result' => {
        'id' => -1001234567890,
        'title' => 'Private Channel',
        'username' => 'private_channel',
        'description' => 'Private channel',
        'member_count' => 100
      }
    }
    mock_bot.expect(:get_chat, mock_channel_info, [ { chat_id: -1001234567890 } ])

    # Для BotJoinJob возвращаем ошибку доступа
    mock_bot_for_join = Minitest::Mock.new
    mock_error_response = {
      'ok' => false,
      'error_code' => 403,
      'description' => 'Forbidden: bot was kicked from the channel'
    }
    mock_bot_for_join.expect(:get_chat, mock_error_response, [ { chat_id: -1001234567890 } ])

    # Сначала добавляем канал успешно
    Telegram.stub(:bots, { default: mock_bot }) do
      service = Telegram::ChannelService.new(mock_bot)
      result = service.add_channel_for_user(user, 'private_channel')

      assert result[:success], 'Channel should be added successfully'
      channel = result[:channel]
      assert_equal 'not_joined', channel.bot_join_status
    end

    # Затем BotJoinJob не может вступить
    Telegram.stub(:bots, { default: mock_bot_for_join }) do
      Channels::BotJoinJob.perform_now(channel.id)
      channel.reload
      assert_equal 'join_failed', channel.bot_join_status
      assert_equal 'Forbidden: bot was kicked from the channel', channel.bot_join_error
    end

    # Пост из такого канала должен игнорироваться
    post_data = {
      telegram_message_id: 456,
      text: 'Test post from failed channel',
      media_urls: [],
      published_at: Time.current
    }

    Content::ProcessPostJob.perform_now(channel.id, post_data)

    # Проверяем, что пост НЕ был создан
    post = Post.find_by(telegram_message_id: 456)
    assert_nil post
  end

  test 'posts from inactive channels are ignored' do
    # Создаем канал с неактивным статусом
    channel = channels(:one)
    channel.update!(
      bot_join_status: 'joined',
      deactivated_at: 1.day.ago
    )

    post_data = {
      telegram_message_id: 789,
      text: 'Test post from inactive channel',
      media_urls: [],
      published_at: Time.current
    }

    Content::ProcessPostJob.perform_now(channel.id, post_data)

    # Проверяем, что пост НЕ был создан
    post = Post.find_by(telegram_message_id: 789)
    assert_nil post
  end

  test 'posts from not_joined channels are ignored' do
    # Создаем канал со статусом not_joined
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    post_data = {
      telegram_message_id: 101112,
      text: 'Test post from not_joined channel',
      media_urls: [],
      published_at: Time.current
    }

    Content::ProcessPostJob.perform_now(channel.id, post_data)

    # Проверяем, что пост НЕ был создан
    post = Post.find_by(telegram_message_id: 101112)
    assert_nil post
  end

  test 'posts from join_failed channels are ignored' do
    # Создаем канал со статусом join_failed
    channel = channels(:one)
    channel.update!(
      bot_join_status: 'join_failed',
      bot_join_error: 'Channel is private'
    )

    post_data = {
      telegram_message_id: 131415,
      text: 'Test post from join_failed channel',
      media_urls: [],
      published_at: Time.current
    }

    Content::ProcessPostJob.perform_now(channel.id, post_data)

    # Проверяем, что пост НЕ был создан
    post = Post.find_by(telegram_message_id: 131415)
    assert_nil post
  end

  test 'ChannelService triggers BotJoinJob for existing channels' do
    # Создаем канал со статусом not_joined
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    # Создаем мок для успешного ответа Telegram API
    mock_bot = Minitest::Mock.new
    mock_channel_info = {
      'ok' => true,
      'result' => {
        'id' => channel.telegram_id,
        'title' => 'Updated Channel',
        'username' => channel.username,
        'description' => 'Updated description',
        'member_count' => 2000
      }
    }
    mock_bot.expect(:get_chat, mock_channel_info, [ { chat_id: channel.telegram_id } ])

    Telegram.stub(:bots, { default: mock_bot }) do
      service = Telegram::ChannelService.new(mock_bot)
      result = service.add_channel_to_database(channel.username)

      assert result[:success], 'Channel should be updated successfully'

      # BotJoinJob должен быть запланирован
      assert_enqueued_with(channel.id) do
        # Проверяем, что job был запланирован
      end
    end
  end
end
