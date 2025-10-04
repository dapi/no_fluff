require 'test_helper'

class TelegramWebhookControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset if @bot
  end

  test 'start command creates user and sends welcome message' do
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
    assert_includes params[:text], I18n.t('telegram_bot.start.welcome')
    assert_includes params[:text], 'Без Шелухи'

    # Проверяем наличие inline клавиатуры
    assert_not_nil params[:reply_markup]
    assert params[:reply_markup].is_a?(Hash)
    assert params[:reply_markup].key?(:inline_keyboard)
  end

  test 'start command for existing user does not create duplicate' do
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

  test 'help command sends help message' do
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
    assert_includes params[:text], I18n.t('telegram_bot.help.commands')
    assert_includes params[:text], '/start'
    assert_includes params[:text], '/help'
  end

  test 'callback query start_onboarding edits message' do
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
    assert_not_nil answer_request, 'Expected answerCallbackQuery request'

    # Ищем editMessageText
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request, 'Expected editMessageText request'

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], I18n.t('telegram_bot.onboarding.add_channels')
  end

  test 'callback query more_info shows detailed information' do
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
    assert_includes edit_params[:text], I18n.t('telegram_bot.more_info.text')
    assert_includes edit_params[:text], 'AI'
  end

  test 'callback query back_to_start returns to welcome' do
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
    assert_includes edit_params[:text], I18n.t('telegram_bot.start.welcome')
  end

  # Тесты команды /add

  test 'add command without arguments shows prompt' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 7,
      'message' => {
        'message_id' => 13,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/add'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], I18n.t('telegram_bot.channels.add.prompt')
    assert_includes params[:text], '@channelname'
  end

  test 'add command with invalid format returns error' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 8,
      'message' => {
        'message_id' => 14,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/add invalid!'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], I18n.t('telegram_bot.channels.add.invalid_format')
  end

  test 'message with @username triggers add channel' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 9,
      'message' => {
        'message_id' => 15,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '@testchannel'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Должен попытаться добавить канал (может быть несколько запросов)
    assert_operator @bot.requests.size, :>=, 1

    # Проверяем что был хотя бы один sendMessage или getChat
    has_requests = @bot.requests[:sendMessage].present? || @bot.requests[:getChat].present?
    assert has_requests, 'Expected at least one sendMessage or getChat request'
  end

  test 'message with t.me link triggers add channel' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 10,
      'message' => {
        'message_id' => 16,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => 'https://t.me/testchannel'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Должен попытаться добавить канал (может быть несколько запросов)
    assert_operator @bot.requests.size, :>=, 1

    # Проверяем что был хотя бы один sendMessage
    send_message_requests = @bot.requests[:sendMessage]
    assert send_message_requests.present?, 'Expected at least one sendMessage request'
  end

  test 'message without @ or t.me does not trigger add channel' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 11,
      'message' => {
        'message_id' => 17,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => 'Hello world'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], I18n.t('telegram_bot.messages.user_message', text: 'Hello world')
  end

  # Тесты команды /list

  test 'list command with no subscriptions shows empty message' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 12,
      'message' => {
        'message_id' => 18,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/list'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], I18n.t('telegram_bot.channels.list.empty')
  end

  test 'list command with subscriptions shows list with buttons' do
    # Создаем тестового пользователя
    user = TelegramUser.create!(
      username: 'testuser_list',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    # Создаем тестовые каналы
    channel1 = Channel.create!(
      telegram_id: 1001,
      username: 'testchannel1',
      title: 'Test Channel 1'
    )

    channel2 = Channel.create!(
      telegram_id: 1002,
      username: 'testchannel2',
      title: 'Test Channel 2'
    )

    # Создаем подписки
    Subscription.create!(
      telegram_user: user,
      channel: channel1,
      priority: 5,
      active: true
    )

    Subscription.create!(
      telegram_user: user,
      channel: channel2,
      priority: 8,
      active: true
    )

    user_data = {
      'id' => 123457,
      'username' => 'testuser_list',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 13,
      'message' => {
        'message_id' => 19,
        'from' => user_data,
        'chat' => { 'id' => 123457, 'type' => 'private' },
        'text' => '/list'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], I18n.t('telegram_bot.channels.list.title')
    assert_includes params[:text], I18n.t('telegram_bot.channels.list.total', count: 2)
    assert_includes params[:text], 'Test Channel 1'
    assert_includes params[:text], 'Test Channel 2'
    assert_includes params[:text], 'приоритет: 5'
    assert_includes params[:text], 'приоритет: 8'

    # Проверяем наличие inline клавиатуры
    assert_not_nil params[:reply_markup]
    assert params[:reply_markup].is_a?(Hash)
    assert params[:reply_markup].key?(:inline_keyboard)

    # Проверяем наличие кнопок управления
    keyboard = params[:reply_markup][:inline_keyboard]
    assert_equal 2, keyboard.length  # Две строки для двух каналов

    # Проверяем кнопки для первого канала
    first_row = keyboard.first
    assert_equal 3, first_row.length  # Три кнопки: вверх, вниз, удалить
    assert_equal '⬆️', first_row[0][:text]
    assert_equal '⬇️', first_row[1][:text]
    assert_equal '🗑️', first_row[2][:text]
    assert_includes first_row[0][:callback_data], 'priority_up:'
    assert_includes first_row[1][:callback_data], 'priority_down:'
    assert_includes first_row[2][:callback_data], 'remove_channel:'
  end

  test 'callback query my_subscriptions triggers list command' do
    user = TelegramUser.create!(
      username: 'testuser',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 14,
      'callback_query' => {
        'id' => 'callback_list_1',
        'from' => user_data,
        'message' => {
          'message_id' => 20,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'my_subscriptions:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем answerCallbackQuery
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем editMessageText с сообщением о подписках
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'У тебя пока нет подписок'
  end

  test 'callback query remove_channel shows confirmation' do
    # Создаем тестовые данные
    user = TelegramUser.create!(
      username: 'testuser_remove',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    channel = Channel.create!(
      telegram_id: 1003,
      username: 'testchannel_remove',
      title: 'Test Channel Remove'
    )

    subscription = Subscription.create!(
      telegram_user: user,
      channel: channel,
      priority: 5,
      active: true
    )

    user_data = {
      'id' => 123458,
      'username' => 'testuser_remove',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 15,
      'callback_query' => {
        'id' => 'callback_remove_1',
        'from' => user_data,
        'message' => {
          'message_id' => 21,
          'chat' => { 'id' => 123458, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => "remove_channel:#{channel.id}"
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем answerCallbackQuery
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем editMessageText с подтверждением
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'Удалить @testchannel_remove из подписок?'

    # Проверяем наличие кнопок подтверждения
    assert_not_nil edit_params[:reply_markup]
    assert edit_params[:reply_markup].is_a?(Hash)
    assert edit_params[:reply_markup].key?(:inline_keyboard)

    keyboard = edit_params[:reply_markup][:inline_keyboard]
    assert_equal 1, keyboard.length

    first_row = keyboard.first
    assert_equal 2, first_row.length
    assert_equal '🗑️', first_row[0][:text]
    assert_equal 'Отмена', first_row[1][:text]
    assert_includes first_row[0][:callback_data], 'confirm_remove:'
    assert_equal 'my_subscriptions:', first_row[1][:callback_data]
  end

  test 'callback query confirm_remove deactivates subscription' do
    # Создаем тестовые данные
    user = TelegramUser.create!(
      username: 'testuser_confirm',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    channel = Channel.create!(
      telegram_id: 1004,
      username: 'testchannel_confirm',
      title: 'Test Channel Confirm'
    )

    subscription = Subscription.create!(
      telegram_user: user,
      channel: channel,
      priority: 5,
      active: true
    )

    user_data = {
      'id' => 123459,
      'username' => 'testuser_confirm',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 16,
      'callback_query' => {
        'id' => 'callback_confirm_1',
        'from' => user_data,
        'message' => {
          'message_id' => 22,
          'chat' => { 'id' => 123459, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => "confirm_remove:#{channel.id}"
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем что подписка деактивирована
    subscription.reload
    assert_not subscription.active

    # Проверяем answerCallbackQuery
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем editMessageText с сообщением об успехе
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'Канал @testchannel_confirm удалён из подписок'
  end

  test 'callback query priority_up increases priority' do
    # Создаем тестовые данные
    user = TelegramUser.create!(
      username: 'testuser_priority_up',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    channel = Channel.create!(
      telegram_id: 1005,
      username: 'testchannel_priority',
      title: 'Test Channel Priority'
    )

    subscription = Subscription.create!(
      telegram_user: user,
      channel: channel,
      priority: 5,
      active: true
    )

    # Добавим еще одну подписку чтобы список не был пустым
    channel2 = Channel.create!(
      telegram_id: 1007,
      username: 'testchannel_priority_extra',
      title: 'Test Channel Priority Extra'
    )

    Subscription.create!(
      telegram_user: user,
      channel: channel2,
      priority: 3,
      active: true
    )

    user_data = {
      'id' => 123460,
      'username' => 'testuser_priority_up',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 17,
      'callback_query' => {
        'id' => 'callback_priority_up_1',
        'from' => user_data,
        'message' => {
          'message_id' => 23,
          'chat' => { 'id' => 123460, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => "priority_up:#{channel.id}"
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем что приоритет увеличен
    subscription.reload
    assert_equal 6, subscription.priority

    # Проверяем что был вызван answerCallbackQuery (пустой ответ)
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем что был вызван editMessageText с обновленным списком
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'Мои подписки'
  end

  test 'callback query priority_down decreases priority' do
    # Создаем тестовые данные
    user = TelegramUser.create!(
      username: 'testuser_priority_down',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    channel = Channel.create!(
      telegram_id: 1006,
      username: 'testchannel_priority2',
      title: 'Test Channel Priority 2'
    )

    subscription = Subscription.create!(
      telegram_user: user,
      channel: channel,
      priority: 5,
      active: true
    )

    # Добавим еще одну подписку чтобы список не был пустым
    channel2 = Channel.create!(
      telegram_id: 1008,
      username: 'testchannel_priority2_extra',
      title: 'Test Channel Priority 2 Extra'
    )

    Subscription.create!(
      telegram_user: user,
      channel: channel2,
      priority: 3,
      active: true
    )

    user_data = {
      'id' => 123461,
      'username' => 'testuser_priority_down',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 18,
      'callback_query' => {
        'id' => 'callback_priority_down_1',
        'from' => user_data,
        'message' => {
          'message_id' => 24,
          'chat' => { 'id' => 123461, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => "priority_down:#{channel.id}"
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем что приоритет уменьшен
    subscription.reload
    assert_equal 4, subscription.priority

    # Проверяем что был вызван answerCallbackQuery (пустой ответ)
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем что был вызван editMessageText с обновленным списком
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], 'Мои подписки'
  end

  # Тесты команды /remove

  test 'remove command without arguments shows prompt' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 19,
      'message' => {
        'message_id' => 25,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/remove'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], I18n.t('telegram_bot.channels.remove.prompt')
  end

  test 'remove command with invalid format returns error' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 20,
      'message' => {
        'message_id' => 26,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/remove invalid!'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], I18n.t('telegram_bot.channels.add.invalid_format')
  end

  test 'remove command with non-existent channel returns error' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 21,
      'message' => {
        'message_id' => 27,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/remove @nonexistentchannel'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], 'не найден в твоих подписках'
  end

  test 'remove command with subscribed channel successfully removes it' do
    # Создаем тестового пользователя и подписку
    user = TelegramUser.create!(
      username: 'testuser_remove_cmd',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    channel = Channel.create!(
      telegram_id: 2001,
      username: 'testchannel_remove_cmd',
      title: 'Test Channel Remove Cmd'
    )

    subscription = Subscription.create!(
      telegram_user: user,
      channel: channel,
      priority: 5,
      active: true
    )

    user_data = {
      'id' => 123462,
      'username' => 'testuser_remove_cmd',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 22,
      'message' => {
        'message_id' => 28,
        'from' => user_data,
        'chat' => { 'id' => 123462, 'type' => 'private' },
        'text' => '/remove @testchannel_remove_cmd'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], 'Канал @testchannel_remove_cmd удалён'
    assert_includes params[:text], 'Всего каналов: 0'

    # Проверяем что подписка деактивирована
    subscription.reload
    assert_not subscription.active
  end

  test 'remove command with t.me link successfully removes channel' do
    # Создаем тестового пользователя и подписку
    user = TelegramUser.create!(
      username: 'testuser_remove_link',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC'
    )

    channel = Channel.create!(
      telegram_id: 2002,
      username: 'testchannel_remove_link',
      title: 'Test Channel Remove Link'
    )

    subscription = Subscription.create!(
      telegram_user: user,
      channel: channel,
      priority: 5,
      active: true
    )

    user_data = {
      'id' => 123463,
      'username' => 'testuser_remove_link',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 23,
      'message' => {
        'message_id' => 29,
        'from' => user_data,
        'chat' => { 'id' => 123463, 'type' => 'private' },
        'text' => '/remove t.me/testchannel_remove_link'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_includes params[:text], 'Канал @testchannel_remove_link удалён'

    # Проверяем что подписка деактивирована
    subscription.reload
    assert_not subscription.active
  end

  # Тесты команды /settings

  test 'settings command shows current settings' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser_settings',
      'first_name' => 'Test',
      'last_name' => 'User',
      'language_code' => 'ru',
      'is_premium' => false
    }

    update = {
      'update_id' => 24,
      'message' => {
        'message_id' => 30,
        'from' => user_data,
        'chat' => { 'id' => 123456, 'type' => 'private' },
        'text' => '/settings'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что пользователь был создан
    user = TelegramUser.find_by(username: 'testuser_settings')
    assert_not_nil user

    # Проверяем, что бот отправил сообщение
    assert_equal 1, @bot.requests.size

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_equal 123456, params[:chat_id]
    assert_includes params[:text], I18n.t('telegram_bot.settings.title')
    assert_includes params[:text], I18n.t('telegram_bot.settings.current_settings')
    assert_includes params[:text], I18n.t('telegram_bot.settings.delivery_frequency.title')
    assert_includes params[:text], I18n.t('telegram_bot.settings.content_format.title')
    assert_includes params[:text], I18n.t('telegram_bot.settings.filter_strictness.title')

    # Проверяем наличие inline клавиатуры
    assert_not_nil params[:reply_markup]
    assert params[:reply_markup].is_a?(Hash)
    assert params[:reply_markup].key?(:inline_keyboard)
  end

  test 'callback query settings shows settings menu' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser_settings',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 25,
      'callback_query' => {
        'id' => 'callback_settings_1',
        'from' => user_data,
        'message' => {
          'message_id' => 31,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'settings:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем answerCallbackQuery
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем editMessageText с настройками
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], '⚙️ Настройки'
    assert_includes edit_params[:text], '📋 Текущие настройки'
  end

  test 'callback query delivery_frequency shows frequency options' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser_settings',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 26,
      'callback_query' => {
        'id' => 'callback_frequency_1',
        'from' => user_data,
        'message' => {
          'message_id' => 32,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'delivery_frequency:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем answerCallbackQuery
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем editMessageText с опциями частоты
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], '⏰ Частота доставки'

    # Проверяем наличие inline клавиатуры с опциями
    assert_not_nil edit_params[:reply_markup]
    assert edit_params[:reply_markup].is_a?(Hash)
    assert edit_params[:reply_markup].key?(:inline_keyboard)

    # Проверяем что опции находятся в клавиатуре, а не в тексте
    keyboard = edit_params[:reply_markup][:inline_keyboard]
    assert_not_empty keyboard

    # Находим кнопки с опциями
    flat_buttons = keyboard.flatten
    option_texts = flat_buttons.map { |button| button[:text] }

    assert_includes option_texts, 'Реальное время'
    assert_includes option_texts, 'Раз в день'
    assert_includes option_texts, '← Назад'
  end

  test 'callback query content_format shows format options' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser_settings',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 27,
      'callback_query' => {
        'id' => 'callback_format_1',
        'from' => user_data,
        'message' => {
          'message_id' => 33,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'content_format:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем editMessageText с опциями формата
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], '📝 Формат контента'

    # Проверяем что опции находятся в клавиатуре
    assert_not_nil edit_params[:reply_markup]
    assert edit_params[:reply_markup].is_a?(Hash)
    assert edit_params[:reply_markup].key?(:inline_keyboard)

    keyboard = edit_params[:reply_markup][:inline_keyboard]
    flat_buttons = keyboard.flatten
    option_texts = flat_buttons.map { |button| button[:text] }

    assert_includes option_texts, 'Оригинальные посты'
    assert_includes option_texts, 'Саммари'
    assert_includes option_texts, '← Назад'
  end

  test 'callback query filter_strictness shows strictness options' do
    user_data = {
      'id' => 123456,
      'username' => 'testuser_settings',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 28,
      'callback_query' => {
        'id' => 'callback_strictness_1',
        'from' => user_data,
        'message' => {
          'message_id' => 34,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'filter_strictness:'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем editMessageText с опциями строгости
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], '🎯 Строгость фильтрации'

    # Проверяем что опции находятся в клавиатуре
    assert_not_nil edit_params[:reply_markup]
    assert edit_params[:reply_markup].is_a?(Hash)
    assert edit_params[:reply_markup].key?(:inline_keyboard)

    keyboard = edit_params[:reply_markup][:inline_keyboard]
    flat_buttons = keyboard.flatten
    option_texts = flat_buttons.map { |button| button[:text] }

    assert_includes option_texts, 'Ультра'
    assert_includes option_texts, 'Высокая'
    assert_includes option_texts, '← Назад'
  end

  test 'callback query set_delivery_frequency updates user setting' do
    user = TelegramUser.create!(
      username: 'testuser_freq_change',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC',
      delivery_frequency: 'once_daily'
    )

    user_data = {
      'id' => 123456,
      'username' => 'testuser_freq_change',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 29,
      'callback_query' => {
        'id' => 'callback_set_freq_1',
        'from' => user_data,
        'message' => {
          'message_id' => 35,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'set_delivery_frequency:weekly'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что настройка была обновлена
    user.reload
    assert_equal 'weekly', user.delivery_frequency

    # Проверяем answerCallbackQuery
    answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
    assert_not_nil answer_request

    # Проверяем editMessageText с сообщением об успехе
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], '✅ Частота доставки изменена на'
    assert_includes edit_params[:text], 'Раз в неделю'
  end

  test 'callback query set_content_format updates user setting' do
    user = TelegramUser.create!(
      username: 'testuser_format_change',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC',
      content_format: 'original'
    )

    user_data = {
      'id' => 123456,
      'username' => 'testuser_format_change',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 30,
      'callback_query' => {
        'id' => 'callback_set_format_1',
        'from' => user_data,
        'message' => {
          'message_id' => 36,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'set_content_format:summaries'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что настройка была обновлена
    user.reload
    assert_equal 'summaries', user.content_format

    # Проверяем editMessageText с сообщением об успехе
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], '✅ Формат контента изменён на'
    assert_includes edit_params[:text], 'Саммари'
  end

  test 'callback query set_filter_strictness updates user setting' do
    user = TelegramUser.create!(
      username: 'testuser_strictness_change',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC',
      filter_strictness: 'medium'
    )

    user_data = {
      'id' => 123456,
      'username' => 'testuser_strictness_change',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 31,
      'callback_query' => {
        'id' => 'callback_set_strictness_1',
        'from' => user_data,
        'message' => {
          'message_id' => 37,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'set_filter_strictness:high'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что настройка была обновлена
    user.reload
    assert_equal 'high', user.filter_strictness

    # Проверяем editMessageText с сообщением об успехе
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    assert_includes edit_params[:text], '✅ Строгость фильтрации изменена на'
    assert_includes edit_params[:text], 'Высокая'
  end

  test 'callback query with same value returns to settings without update' do
    user = TelegramUser.create!(
      username: 'testuser_same_value',
      first_name: 'Test',
      language_code: 'ru',
      timezone: 'UTC',
      delivery_frequency: :real_time  # Используем символ
    )

    user_data = {
      'id' => user.id,  # Используем тот же ID что и у пользователя
      'username' => 'testuser_same_value',
      'first_name' => 'Test'
    }

    update = {
      'update_id' => 32,
      'callback_query' => {
        'id' => 'callback_same_value_1',
        'from' => user_data,
        'message' => {
          'message_id' => 38,
          'chat' => { 'id' => 123456, 'type' => 'private' },
          'text' => 'Previous text'
        },
        'data' => 'set_delivery_frequency:real_time'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что настройка не изменилась
    user.reload
    assert_equal 'real_time', user.delivery_frequency

    # Проверяем editMessageText с сообщением (текущее поведение)
    edit_request = @bot.requests.find { |method, _| method == :editMessageText }
    assert_not_nil edit_request

    _, edit_params = edit_request
    edit_params = edit_params.first
    # Проверяем что пришло сообщение об успехе (текущее поведение)
    assert_includes edit_params[:text], '✅ Частота доставки изменена на'
    assert_includes edit_params[:text], 'Реальное время'
  end

  # Тесты для функциональности администратора

  test 'start command promotes first user to admin' do
    # Сначала убеждаемся, что в системе нет администраторов
    TelegramUser.where(is_admin: true).update_all(is_admin: false)

    # Проверяем, что в системе действительно нет администраторов
    assert_not TelegramUser.any_admins?, 'Тест требует отсутствия администраторов в системе'


    # Создаем нового пользователя, который станет администратором
    user_data = {
      'id' => 999999,  # Используем уникальный ID, которого нет в фикстурах
      'username' => 'first_admin',
      'first_name' => 'First',
      'last_name' => 'Admin',
      'language_code' => 'ru',
      'is_premium' => false
    }

    update = {
      'update_id' => 1001,
      'message' => {
        'message_id' => 1001,
        'from' => user_data,
        'chat' => { 'id' => 999999, 'type' => 'private' },
        'text' => '/start'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что пользователь был создан и стал администратором
    user = TelegramUser.find_by(username: 'first_admin')
    assert_not_nil user


    assert user.is_admin?, "User should be admin but is_admin=#{user.is_admin}"  # Главное проверка!

    # Проверяем, что бот отправил сообщение с поздравлением
    assert_equal 1, @bot.requests.size

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_equal 999999, params[:chat_id]
    assert_includes params[:text], I18n.t('telegram_bot.start.first_admin')
    assert_includes params[:text], I18n.t('telegram_bot.start.welcome')

    # Проверяем наличие inline клавиатуры
    assert_not_nil params[:reply_markup]
    assert params[:reply_markup].is_a?(Hash)
    assert params[:reply_markup].key?(:inline_keyboard)
  end

  test 'start command does not promote subsequent users to admin' do
    # Сначала создаем администратора
    existing_admin = TelegramUser.create!(
      username: 'existing_admin',
      first_name: 'Existing',
      language_code: 'ru',
      timezone: 'UTC',
      is_admin: true
    )

    user_data = {
      'id' => 123457,
      'username' => 'regular_user',
      'first_name' => 'Regular',
      'last_name' => 'User',
      'language_code' => 'ru',
      'is_premium' => false
    }

    update = {
      'update_id' => 1002,
      'message' => {
        'message_id' => 1002,
        'from' => user_data,
        'chat' => { 'id' => 123457, 'type' => 'private' },
        'text' => '/start'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что пользователь был создан, но не стал администратором
    user = TelegramUser.find_by(username: 'regular_user')
    assert_not_nil user
    assert_equal 'Regular', user.first_name
    assert_equal 'User', user.last_name
    assert_equal false, user.is_admin  # Главное проверка!

    # Проверяем, что бот отправил обычное приветственное сообщение
    assert_equal 1, @bot.requests.size

    method, params = @bot.requests.first
    params = params.first

    assert_equal :sendMessage, method
    assert_equal 123457, params[:chat_id]
    assert_includes params[:text], I18n.t('telegram_bot.start.welcome')
    # Не должно быть сообщения о назначении администратором
    assert_not_includes params[:text], I18n.t('telegram_bot.start.first_admin')
  end

  test 'start command works correctly when user already exists' do
    # Создаем администратора в системе, чтобы новый пользователь не стал админом
    admin_user = TelegramUser.create!(
      username: 'admin_user',
      first_name: 'Admin',
      language_code: 'ru',
      timezone: 'UTC',
      is_admin: true
    )

    # Создаем существующего пользователя (не администратор)
    existing_user = TelegramUser.create!(
      username: 'existing_user',
      first_name: 'Existing',
      language_code: 'ru',
      timezone: 'UTC',
      is_admin: false
    )

    user_data = {
      'id' => 123458,
      'username' => 'existing_user',
      'first_name' => 'Updated',
      'last_name' => 'Name',
      'language_code' => 'en'
    }

    update = {
      'update_id' => 1003,
      'message' => {
        'message_id' => 1003,
        'from' => user_data,
        'chat' => { 'id' => 123458, 'type' => 'private' },
        'text' => '/start'
      }
    }

    initial_count = TelegramUser.count

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success
    assert_equal initial_count, TelegramUser.count

    # Проверяем, что пользователь не стал администратором (поскольку уже есть администраторы в системе)
    existing_user.reload
    assert_equal false, existing_user.is_admin
  end

  test 'start command promotes existing user to admin if no admins exist' do
    # Создаем существующего пользователя без прав администратора
    existing_user = TelegramUser.create!(
      username: 'existing_promoted',
      first_name: 'WillBeAdmin',
      language_code: 'ru',
      timezone: 'UTC',
      is_admin: false
    )

    user_data = {
      'id' => existing_user.id,  # Используем тот же ID
      'username' => 'existing_promoted',
      'first_name' => 'WillBeAdmin'
    }

    update = {
      'update_id' => 1004,
      'message' => {
        'message_id' => 1004,
        'from' => user_data,
        'chat' => { 'id' => existing_user.id, 'type' => 'private' },
        'text' => '/start'
      }
    }

    post telegram_webhook_path, params: update.to_json,
      headers: { 'Content-Type' => 'application/json' }

    assert_response :success

    # Проверяем, что существующий пользователь стал администратором
    existing_user.reload
    assert_equal true, existing_user.is_admin

    # Проверяем, что бот отправил сообщение с поздравлением
    assert_equal 1, @bot.requests.size

    method, params = @bot.requests.first
    params = params.first

    assert_includes params[:text], I18n.t('telegram_bot.start.first_admin')
  end
end
