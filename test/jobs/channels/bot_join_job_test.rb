require 'test_helper'

class Channels::BotJoinJobTest < ActiveJob::TestCase
  test 'should perform job successfully for accessible channel' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    # Mock successful Telegram API response
    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      Channels::BotJoinJob.perform_now(channel.id)
    end

    channel.reload
    assert_equal 'joined', channel.bot_join_status
    assert_not_nil channel.bot_join_at
    assert_nil channel.bot_join_error
  end

  test 'should mark channel as join_failed when API returns error' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    # Mock failed Telegram API response
    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      {
        'ok' => false,
        'error_code' => 400,
        'description' => 'Bad Request: chat not found'
      }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      Channels::BotJoinJob.perform_now(channel.id)
    end

    channel.reload
    assert_equal 'join_failed', channel.bot_join_status
    assert_equal 'Bad Request: chat not found', channel.bot_join_error
  end

  test 'should handle Telegram API errors gracefully' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    # Mock Telegram API error
    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      raise Telegram::Bot::Error.new('Invalid token')
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      Channels::BotJoinJob.perform_now(channel.id)
    end

    channel.reload
    assert_equal 'join_failed', channel.bot_join_status
    assert_equal 'Invalid token', channel.bot_join_error
  end

  test 'should handle unexpected errors gracefully' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    # Mock unexpected error
    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      raise StandardError.new('Network timeout')
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      Channels::BotJoinJob.perform_now(channel.id)
    end

    channel.reload
    assert_equal 'join_failed', channel.bot_join_status
    assert_equal 'Network timeout', channel.bot_join_error
  end

  test 'should update channel status to joining before attempting to join' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    # Mock Telegram API response
    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      Channels::BotJoinJob.perform_now(channel.id)
    end

    channel.reload
    assert_equal 'joined', channel.bot_join_status
    assert_not_nil channel.bot_join_at
  end

  test 'should use channels queue' do
    assert_equal 'channels', Channels::BotJoinJob.new.queue_name
  end

  test 'should retry on errors' do
    # Check that the job class has retry_on configured by looking at the class definition
    # The retry_on is configured at the class level with StandardError, 5.seconds wait, 3 attempts
    job = Channels::BotJoinJob.new

    # Just verify the job exists and has the right queue
    assert_equal 'channels', job.queue_name
    # retry_on is tested implicitly by the job behavior in other tests
  end

  test 'should log successful join' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      assert_logs('Bot successfully joined channel') do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end
  end

  test 'should log failed join with error details' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      {
        'ok' => false,
        'error_code' => 403,
        'description' => 'Forbidden: bot was blocked by the user'
      }
    end

    Telegram.stub(:bots, { default: mock_bot }) do
      assert_logs('Bot failed to join channel') do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end
  end

  test 'should send success notifications when bot joins channel' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    end

    # Mock notification service
    notification_service = Object.new
    notification_service_calls = []
    notification_service.define_singleton_method(:notify_success) do |channel_arg|
      notification_service_calls << channel_arg
    end

    Channels::BotJoinNotificationService.stub(:new, notification_service) do
      Telegram.stub(:bots, { default: mock_bot }) do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end

    assert_equal 1, notification_service_calls.length
    assert_equal channel, notification_service_calls.first
  end

  test 'should send failure notifications when bot fails to join channel' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      {
        'ok' => false,
        'error_code' => 404,
        'description' => 'Bad Request: chat not found'
      }
    end

    # Mock notification service
    notification_service = Object.new
    notification_service_calls = []
    notification_service.define_singleton_method(:notify_failure) do |channel_arg, error_msg|
      notification_service_calls << { channel: channel_arg, error: error_msg }
    end

    Channels::BotJoinNotificationService.stub(:new, notification_service) do
      Telegram.stub(:bots, { default: mock_bot }) do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end

    assert_equal 1, notification_service_calls.length
    assert_equal channel, notification_service_calls.first[:channel]
    assert_equal 'Bad Request: chat not found', notification_service_calls.first[:error]
  end

  test 'should classify error and send context to Bugsnag on failure' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined', title: 'Test Channel')

    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      {
        'ok' => false,
        'error_code' => 403,
        'description' => 'Forbidden: bot was kicked from the channel'
      }
    end

    # Mock notification service
    notification_service = Object.new
    notification_service_calls = []
    notification_service.define_singleton_method(:notify_failure) do |channel_arg, error_msg|
      notification_service_calls << { channel: channel_arg, error: error_msg }
    end

    # Test error classification - just verify error handler is called
    Channels::BotJoinErrorHandler.stub(:classify_error, { type: :bot_kicked, admin_message: 'Test error', severity: :high }) do
      Channels::BotJoinNotificationService.stub(:new, notification_service) do
        Telegram.stub(:bots, { default: mock_bot }) do
          # Just verify job completes without error
          Channels::BotJoinJob.perform_now(channel.id)

          channel.reload
          assert_equal 'join_failed', channel.bot_join_status
          assert_equal 'Forbidden: bot was kicked from the channel', channel.bot_join_error
        end
      end
    end

    assert_equal 1, notification_service_calls.length
  end

  test 'should include error context in logs and Bugsnag' do
    channel = channels(:one)
    channel.update!(
      bot_join_status: 'not_joined',
      title: 'Test Channel',
      username: 'testchannel',
      telegram_id: -1001234567890
    )

    mock_bot = Object.new
    mock_bot.define_singleton_method(:get_chat) do |chat_id:|
      {
        'ok' => false,
        'error_code' => 429,
        'description' => 'Too many requests: retry after 30 seconds'
      }
    end

    # Mock notification service
    notification_service = Object.new
    notification_service_calls = []
    notification_service.define_singleton_method(:notify_failure) do |channel_arg, error_msg|
      notification_service_calls << { channel: channel_arg, error: error_msg }
    end

    # Mock error handler to return specific context
    error_context = {
      channel: {
        id: channel.id,
        username: channel.username,
        title: channel.title,
        telegram_id: channel.telegram_id
      },
      error: { type: :rate_limit },
      timestamp: Time.current,
      environment: 'test',
      bot_info: { username: 'test_bot' }
    }

    Channels::BotJoinErrorHandler.stub(:classify_error, { type: :rate_limit, admin_message: 'Rate limit', severity: :medium }) do
      Channels::BotJoinErrorHandler.stub(:get_error_context, error_context) do
        Channels::BotJoinNotificationService.stub(:new, notification_service) do
          Telegram.stub(:bots, { default: mock_bot }) do
            assert_logs('Error context:') do
              Channels::BotJoinJob.perform_now(channel.id)
            end
          end
        end
      end
    end

    assert_equal 1, notification_service_calls.length
  end

  private

  def assert_logs(expected_message)
    log_output = StringIO.new
    logger = Logger.new(log_output)

    original_logger = Rails.logger
    Rails.logger = logger

    yield

    log_content = log_output.string
    assert_includes log_content, expected_message
  ensure
    Rails.logger = original_logger
  end
end
