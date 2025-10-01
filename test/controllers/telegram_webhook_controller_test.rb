require "test_helper"

class TelegramWebhookControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset
  end

  test "start command creates user and sends welcome message" do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test',
      'last_name' => 'User',
      'language_code' => 'ru',
      'is_premium' => false
    }

    # Создаём update для команды /start
    update = {
      'update_id' => 1,
      'message' => {
        'message_id' => 1,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/start'
      }
    }

    # Отправляем update в контроллер
    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что пользователь был создан
    user = TelegramUser.find_by(username: 'testuser')
    assert_not_nil user
    assert_equal 'Test', user.first_name
    assert_equal 'User', user.last_name
    assert_equal 'ru', user.language_code
    assert_equal false, user.is_premium

    # Проверяем, что бот отправил сообщение
    assert_equal 1, @bot.requests.size

    # Request имеет структуру [:method, [params]]
    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_equal 123456, params[:chat_id]
    assert_includes params[:text], 'Привет!'
    assert_includes params[:text], 'No Fluff Bot'

    # Проверяем наличие inline клавиатуры
    assert_not_nil params[:reply_markup]
    assert params[:reply_markup].is_a?(Telegram::Bot::Types::InlineKeyboardMarkup)
  end

  test "start command for existing user does not create duplicate" do
    # Создаём существующего пользователя
    existing_user = telegram_users(:one)

    user_data = {
      'id' => 123456,
      'username' => existing_user.username,
      'first_name' => 'Updated',
      'last_name' => 'Name',
      'language_code' => 'en'
    }

    update = {
      'update_id' => 2,
      'message' => {
        'message_id' => 2,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/start'
      }
    }

    initial_count = TelegramUser.count

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success
    assert_equal initial_count, TelegramUser.count
  end

  test "help command sends help message" do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test',
      'chat' => { 'id' => 123456, 'type' => 'private' }
    }

    update = {
      'update_id' => 3,
      'message' => {
        'message_id' => 3,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/help'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что бот отправил сообщение с командами
    assert_equal 1, @bot.requests.size

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], 'Доступные команды'
    assert_includes params[:text], '/start'
    assert_includes params[:text], '/help'
  end

  test "callback query start_onboarding edits message" do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 4,
      'callback_query' => {
        'id' => 'callback_1',
        'from' => user_data,
        'message' => {
          'message_id' => 10,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'start_onboarding:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что бот ответил на callback query
    assert_operator @bot.requests.size, :>=, 1

    # Ищем answerCallbackQuery
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request, "Expected answerCallbackQuery request"

    # Ищем editMessageText
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request, "Expected editMessageText request"

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'Пришли мне ссылки'
  end

  test "callback query more_info shows detailed information" do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 5,
      'callback_query' => {
        'id' => 'callback_2',
        'from' => user_data,
        'message' => {
          'message_id' => 11,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'more_info:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Ищем editMessageText
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'Как это работает?'
    assert_includes edit_params[:text], 'AI'
  end

  test "callback query back_to_start returns to welcome" do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 6,
      'callback_query' => {
        'id' => 'callback_3',
        'from' => user_data,
        'message' => {
          'message_id' => 12,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'back_to_start:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Ищем editMessageText
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'No Fluff Bot'
    assert_includes edit_params[:text], 'Начнём?'
  end
end
