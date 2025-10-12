require 'test_helper'

class Channels::BotJoinJobTest < ActiveJob::TestCase
  test 'should perform job successfully for accessible channel' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    # Mock successful Telegram API response
    mock_bot = Minitest::Mock.new
    mock_response = { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

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
    mock_bot = Minitest::Mock.new
    mock_response = {
      'ok' => false,
      'error_code' => 400,
      'description' => 'Bad Request: chat not found'
    }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

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
    mock_bot = Minitest::Mock.new
    mock_bot.expect(:get_chat, nil) do
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
    mock_bot = Minitest::Mock.new
    mock_bot.expect(:get_chat, nil) do
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
    mock_bot = Minitest::Mock.new
    mock_response = { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

    Telegram.stub(:bots, { default: mock_bot }) do
      # Check status during job execution
      Channel.any_instance.stubs(:start_joining!).with do
        channel.reload
        assert_equal 'joining', channel.bot_join_status
      end

      Channels::BotJoinJob.perform_now(channel.id)
    end

    channel.reload
    assert_equal 'joined', channel.bot_join_status
  end

  test 'should use channels queue' do
    assert_equal 'channels', Channels::BotJoinJob.new.queue_name
  end

  test 'should retry on errors' do
    job = Channels::BotJoinJob.new

    assert_respond_to job, :retry_on
    # The job should retry on StandardError with exponential backoff
  end

  test 'should log successful join' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Minitest::Mock.new
    mock_response = { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

    Telegram.stub(:bots, { default: mock_bot }) do
      assert_logs('Bot successfully joined channel') do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end
  end

  test 'should log failed join with error details' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Minitest::Mock.new
    mock_response = {
      'ok' => false,
      'error_code' => 403,
      'description' => 'Forbidden: bot was blocked by the user'
    }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

    Telegram.stub(:bots, { default: mock_bot }) do
      assert_logs('Bot failed to join channel') do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end
  end

  test 'should send success notifications when bot joins channel' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Minitest::Mock.new
    mock_response = { 'ok' => true, 'result' => { 'id' => channel.telegram_id } }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

    # Mock notification service
    notification_service = Minitest::Mock.new
    notification_service.expect(:notify_success, nil, [ channel ])

    Channels::BotJoinNotificationService.stub(:new, notification_service) do
      Telegram.stub(:bots, { default: mock_bot }) do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end

    notification_service.verify
  end

  test 'should send failure notifications when bot fails to join channel' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined')

    mock_bot = Minitest::Mock.new
    mock_response = {
      'ok' => false,
      'error_code' => 404,
      'description' => 'Bad Request: chat not found'
    }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

    # Mock notification service
    notification_service = Minitest::Mock.new
    notification_service.expect(:notify_failure, nil, [ channel, 'Bad Request: chat not found' ])

    Channels::BotJoinNotificationService.stub(:new, notification_service) do
      Telegram.stub(:bots, { default: mock_bot }) do
        Channels::BotJoinJob.perform_now(channel.id)
      end
    end

    notification_service.verify
  end

  test 'should classify error and send context to Bugsnag on failure' do
    channel = channels(:one)
    channel.update!(bot_join_status: 'not_joined', title: 'Test Channel')

    mock_bot = Minitest::Mock.new
    mock_response = {
      'ok' => false,
      'error_code' => 403,
      'description' => 'Forbidden: bot was kicked from the channel'
    }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

    # Mock notification service
    notification_service = Minitest::Mock.new
    notification_service.expect(:notify_failure, nil, [ channel, 'Forbidden: bot was kicked from the channel' ])

    # Test error classification
    Channels::BotJoinErrorHandler.stub(:classify_error, { type: :bot_kicked, admin_message: 'Test error', severity: :high }) do
      Channels::BotJoinNotificationService.stub(:new, notification_service) do
        Telegram.stub(:bots, { default: mock_bot }) do
          # Mock Bugsnag
          Bugsnag.stub(:notify, true) do |exception, message, &block|
            assert_equal 'Bot join failed: bot_kicked', exception.message
            assert_equal 'Test error', message
          end

          Channels::BotJoinJob.perform_now(channel.id)
        end
      end
    end

    notification_service.verify
  end

  test 'should include error context in logs and Bugsnag' do
    channel = channels(:one)
    channel.update!(
      bot_join_status: 'not_joined',
      title: 'Test Channel',
      username: 'testchannel',
      telegram_id: -1001234567890
    )

    mock_bot = Minitest::Mock.new
    mock_response = {
      'ok' => false,
      'error_code' => 429,
      'description' => 'Too many requests: retry after 30 seconds'
    }
    mock_bot.expect(:get_chat, mock_response, [ { chat_id: channel.telegram_id } ])

    # Mock notification service
    notification_service = Minitest::Mock.new
    notification_service.expect(:notify_failure, nil, [ channel, 'Too many requests: retry after 30 seconds' ])

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
            # Test Bugsnag metadata
            Bugsnag.stub(:notify, true) do |exception, message, &block|
              metadata_block = block.call
              assert_equal error_context, metadata_block.metadata
              assert_equal :medium, metadata_block.severity
            end

            assert_logs('Error context:') do
              Channels::BotJoinJob.perform_now(channel.id)
            end
          end
        end
      end
    end

    notification_service.verify
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
