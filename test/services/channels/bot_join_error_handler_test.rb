require 'test_helper'

class Channels::BotJoinErrorHandlerTest < ActiveSupport::TestCase
  test 'should classify bot kicked error correctly' do
    error_message = 'Forbidden: bot was kicked from the channel'
    result = Channels::BotJoinErrorHandler.classify_error(error_message)

    assert_equal :bot_kicked, result[:type]
    assert_equal 'Бот был удален из канала', result[:user_message]
    assert_equal 'Бота исключили из канала', result[:admin_message]
    assert_equal :high, result[:severity]
    assert_equal false, result[:retry_possible]
  end

  test 'should classify rate limit error correctly' do
    error_message = 'Too many requests: retry after 30 seconds'
    result = Channels::BotJoinErrorHandler.classify_error(error_message)

    assert_equal :rate_limit, result[:type]
    assert_equal 'Слишком много запросов. Попробуйте позже.', result[:user_message]
    assert_equal 'Превышен лимит запросов к Telegram API', result[:admin_message]
    assert_equal :medium, result[:severity]
    assert_equal true, result[:retry_possible]
  end

  test 'should classify channel not found error correctly' do
    error_message = 'Bad Request: chat not found'
    result = Channels::BotJoinErrorHandler.classify_error(error_message)

    assert_equal :channel_not_found, result[:type]
    assert_equal 'Канал не найден или был удален', result[:user_message]
    assert_equal 'Канал не существует в Telegram', result[:admin_message]
    assert_equal :high, result[:severity]
    assert_equal false, result[:retry_possible]
  end

  test 'should classify timeout error correctly' do
    error_message = 'timeout'
    result = Channels::BotJoinErrorHandler.classify_error(error_message)

    assert_equal :timeout, result[:type]
    assert_equal 'Время ожидания истекло', result[:user_message]
    assert_equal 'Тайм-аут при подключении к Telegram API', result[:admin_message]
    assert_equal :medium, result[:severity]
    assert_equal true, result[:retry_possible]
  end

  test 'should classify unknown error as default' do
    error_message = 'Unknown error occurred'
    result = Channels::BotJoinErrorHandler.classify_error(error_message)

    assert_equal :unknown, result[:type]
    assert_equal 'Неизвестная ошибка', result[:user_message]
    assert_equal error_message, result[:admin_message]
    assert_equal :medium, result[:severity]
    assert_equal false, result[:retry_possible]
  end

  test 'should get error context with all required fields' do
    error_info = {
      type: :bot_kicked,
      user_message: 'Test error',
      admin_message: 'Test admin error',
      severity: :high,
      retry_possible: false
    }

    channel = channels(:one)

    # Mock bot username for test environment
    ApplicationConfig.stub(:bot_username, 'test_bot') do
      context = Channels::BotJoinErrorHandler.get_error_context(error_info, channel)

      assert_equal channel.id, context[:channel][:id]
      assert_equal channel.username, context[:channel][:username]
      assert_equal channel.title, context[:channel][:title]
      assert_equal channel.telegram_id, context[:channel][:telegram_id]

      assert_equal error_info, context[:error]
      assert_not_nil context[:timestamp]
      assert_equal Rails.env, context[:environment]
      assert_equal 'test_bot', context[:bot_info][:username]
    end
  end

  test 'should determine retry possibility correctly' do
    retryable_error = {
      type: :rate_limit,
      retry_possible: true
    }

    non_retryable_error = {
      type: :bot_kicked,
      retry_possible: false
    }

    assert Channels::BotJoinErrorHandler.should_retry?(retryable_error)
    assert_not Channels::BotJoinErrorHandler.should_retry?(non_retryable_error)
  end

  test 'should get severity level correctly' do
    critical_error = { severity: :critical }
    high_error = { severity: :high }
    medium_error = { severity: :medium }

    assert_equal :critical, Channels::BotJoinErrorHandler.get_severity_level(critical_error)
    assert_equal :high, Channels::BotJoinErrorHandler.get_severity_level(high_error)
    assert_equal :medium, Channels::BotJoinErrorHandler.get_severity_level(medium_error)
  end

  test 'should handle error messages case insensitively' do
    error_message = 'FORBIDDEN: BOT WAS KICKED FROM THE CHANNEL'
    result = Channels::BotJoinErrorHandler.classify_error(error_message)

    assert_equal :bot_kicked, result[:type]
  end

  test 'should handle empty error message' do
    result = Channels::BotJoinErrorHandler.classify_error('')

    assert_equal :unknown, result[:type]
    assert_equal 'Неизвестная ошибка', result[:user_message]
  end
end
