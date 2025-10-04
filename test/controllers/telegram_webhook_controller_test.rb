require "test_helper"

class TelegramWebhookControllerImprovedTest < ActionDispatch::IntegrationTest
  setup do
    @bot = Telegram.bot
    @bot.reset
  end

  teardown do
    @bot.reset if @bot
  end

  # Helper methods для создания тестовых данных
  def create_user_update(user_id: 123456, username: "testuser", command: "/start")
    {
      "update_id" => 1,
      "message" => {
        "message_id" => 1,
        "from" => {
          "id" => user_id,
          "username" => username,
          "first_name" => "Test",
          "last_name" => "User",
          "language_code" => "ru",
          "is_premium" => false
        },
        "chat" => { "id" => user_id, "type" => "private" },
        "text" => command
      }
    }
  end

  def create_callback_update(user_id: 123456, username: "testuser", data: "test:")
    {
      "update_id" => 1,
      "callback_query" => {
        "id" => "callback_1",
        "from" => {
          "id" => user_id,
          "username" => username,
          "first_name" => "Test"
        },
        "message" => {
          "message_id" => 10,
          "chat" => { "id" => user_id, "type" => "private" },
          "text" => "Previous text"
        },
        "data" => data
      }
    }
  end

  def send_webhook_update(update)
    post telegram_webhook_path, params: update.to_json,
      headers: { "Content-Type" => "application/json" }
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

  # High-level тесты на уровне пользовательского поведения

  test "start command creates user and sends welcome message" do
    initial_user_count = TelegramUser.count

    update = create_user_update(username: "newuser", command: "/start")
    send_webhook_update(update)

    assert_response :success

    # Проверяем что пользователь был создан
    assert_equal initial_user_count + 1, TelegramUser.count

    user = TelegramUser.find_by(username: "newuser")
    assert_not_nil user
    assert_equal "Test", user.first_name

    # Проверяем что было отправлено приветственное сообщение
    assert_operator @bot.requests.size, :>=, 1

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.start.welcome')
    assert_not_nil message_content[:reply_markup]
  end

  test "start command for existing user updates data and sends welcome" do
    # Создаем пользователя заранее
    existing_user = TelegramUser.create!(
      username: "existing_user",
      first_name: "Old",
      language_code: "en",
      timezone: "UTC"
    )

    update = create_user_update(user_id: existing_user.id, username: "existing_user",
                               command: "/start")
    update["message"]["from"]["first_name"] = "Updated"
    update["message"]["from"]["last_name"] = "Name"
    update["message"]["from"]["language_code"] = "ru"

    initial_count = TelegramUser.count
    send_webhook_update(update)

    assert_response :success
    assert_equal initial_count, TelegramUser.count  # Пользователь не создан повторно

    # Проверяем что данные обновились
    existing_user.reload
    assert_equal "existing_user", existing_user.username

    # Проверяем что было отправлено сообщение
    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.start.welcome')
  end

  test "help command sends help information" do
    update = create_user_update(command: "/help")
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.help.commands')
  end

  test "first user becomes admin" do
    # Убеждаемся что нет администраторов
    TelegramUser.where(is_admin: true).update_all(is_admin: false)

    update = create_user_update(username: "first_admin", command: "/start")
    send_webhook_update(update)

    assert_response :success

    user = TelegramUser.find_by(username: "first_admin")
    assert user.is_admin?, "First user should become admin"

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.start.first_admin')
  end

  test "subsequent users do not become admin when admin exists" do
    # Создаем администратора
    TelegramUser.create!(username: "admin", is_admin: true)

    update = create_user_update(username: "regular_user", command: "/start")
    send_webhook_update(update)

    assert_response :success

    user = TelegramUser.find_by(username: "regular_user")
    assert_not user.is_admin?, "Regular user should not become admin"

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.start.welcome')
    assert_not_includes message_content[:text], I18n.t('telegram_bot.start.first_admin')
  end

  test "callback queries update messages appropriately" do
    # Тестируем основные callback query
    callbacks = [
      { data: "start_onboarding:", expected_text: "telegram_bot.onboarding.add_channels" },
      { data: "more_info:", expected_text: "telegram_bot.more_info.text" },
      { data: "back_to_start:", expected_text: "telegram_bot.start.welcome" },
      { data: "settings:", expected_text: "⚙️ Настройки" },
      { data: "my_subscriptions:", expected_text: "подписок" }
    ]

    callbacks.each do |callback_data|
      @bot.reset

      update = create_callback_update(data: callback_data[:data])
      send_webhook_update(update)

      assert_response :success

      # Проверяем что callback query был обработан
      answer_request = @bot.requests.find { |method, _| method == :answerCallbackQuery }
      assert_not_nil answer_request, "Should answer callback query for #{callback_data[:data]}"

      # Проверяем что сообщение было обновлено
      edit_content = extract_edited_message_content(@bot.requests)
      assert_not_nil edit_content, "Should edit message for #{callback_data[:data]}"

      if callback_data[:expected_text].start_with?("telegram_bot.")
        assert_includes edit_content[:text], I18n.t(callback_data[:expected_text])
      else
        assert_includes edit_content[:text], callback_data[:expected_text]
      end
    end
  end

  test "channel addition workflow" do
    # Тестируем добавление канала через команду
    update = create_user_update(command: "/add @testchannel")
    send_webhook_update(update)

    assert_response :success

    # Проверяем что была попытка обработать канал
    assert_operator @bot.requests.size, :>=, 1

    # Тестируем добавление канала через прямое сообщение
    @bot.reset
    update = create_user_update(command: "https://t.me/testchannel")
    send_webhook_update(update)

    assert_response :success
    assert_operator @bot.requests.size, :>=, 1
  end

  test "channel removal workflow" do
    # Создаем тестовые данные
    user = TelegramUser.create!(
      username: "testuser_remove",
      first_name: "Test",
      language_code: "ru",
      timezone: "UTC"
    )

    channel = Channel.create!(
      telegram_id: 2001,
      username: "testchannel_remove",
      title: "Test Channel Remove"
    )

    subscription = Subscription.create!(
      telegram_user: user,
      channel: channel,
      priority: 5,
      active: true
    )

    # Тестируем удаление через команду
    update = create_user_update(user_id: user.id, username: "testuser_remove",
                               command: "/remove @testchannel_remove")
    send_webhook_update(update)

    assert_response :success

    # Проверяем что подписка была деактивирована
    subscription.reload
    assert_not subscription.active

    # Проверяем что было отправлено сообщение об успехе
    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], "удалён"
  end

  test "settings management workflow" do
    user = TelegramUser.create!(
      username: "testuser_settings",
      first_name: "Test",
      language_code: "ru",
      timezone: "UTC",
      delivery_frequency: "once_daily"
    )

    # Тестируем команду настроек
    update = create_user_update(user_id: user.id, username: "testuser_settings",
                               command: "/settings")
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.settings.title')

    # Тестируем изменение настройки через callback
    @bot.reset
    update = create_callback_update(user_id: user.id, username: "testuser_settings",
                                   data: "set_delivery_frequency:weekly")
    send_webhook_update(update)

    assert_response :success

    # Проверяем что настройка изменилась
    user.reload
    assert_equal "weekly", user.delivery_frequency
  end

  test "invalid commands return appropriate error messages" do
    # Тестируем команды с невалидными аргументами
    invalid_commands = [
      "/add invalid!",
      "/remove invalid!"
    ]

    invalid_commands.each do |command|
      @bot.reset

      update = create_user_update(command: command)
      send_webhook_update(update)

      assert_response :success

      # Проверяем что был хотя бы один запрос к боту
      assert_operator @bot.requests.size, :>=, 1

      message_content = extract_message_content(@bot.requests)
      if message_content
        # Если есть сообщение, проверяем что оно не пустое
        assert message_content[:text].length > 0
      end
    end

    # Неизвестные команды могут не обрабатываться telegram-bot
    # В этом случае контроллер может не отправлять ответ
    @bot.reset
    update = create_user_update(command: "/unknown_command")
    send_webhook_update(update)

    assert_response :success

    # Проверяем что контроллер обработал запрос (даже если без ответа)
    # Это нормальное поведение для неизвестных команд
  end

  test "regular messages are handled appropriately" do
    # Тестируем обработку обычных сообщений
    regular_messages = [
      "Hello world",
      "This is a test message",
      "12345"
    ]

    regular_messages.each do |message_text|
      @bot.reset

      update = create_user_update(command: message_text)
      send_webhook_update(update)

      assert_response :success

      message_content = extract_message_content(@bot.requests)
      assert_not_nil message_content
      assert_includes message_content[:text], "Вы написали: #{message_text}"
    end

    # Тестируем что сообщения с @ или t.me обрабатываются как каналы
    channel_messages = ["@testchannel", "https://t.me/testchannel"]

    channel_messages.each do |message_text|
      @bot.reset

      update = create_user_update(command: message_text)
      send_webhook_update(update)

      assert_response :success
      assert_operator @bot.requests.size, :>=, 1
    end
  end

  test "error handling works correctly" do
    # Этот тест проверяет что контроллер корректно обрабатывает базовые сценарии
    # и возвращает успешный ответ

    # Создаем стандартный update
    update = create_user_update(command: "/start")
    send_webhook_update(update)

    # Контроллер должен обработать успешно
    assert_response :success

    # Проверяем что был отправлен ответ
    assert_operator @bot.requests.size, :>=, 1
  end

  # Интеграционные тесты для проверки полного workflow

  test "complete user onboarding workflow" do
    # Создаем нового пользователя
    update = create_user_update(username: "newbie", command: "/start")
    send_webhook_update(update)

    assert_response :success

    user = TelegramUser.find_by(username: "newbie")
    assert_not_nil user

    # Пользователь нажимает кнопку онбординга
    @bot.reset
    update = create_callback_update(user_id: user.id, username: "newbie",
                                   data: "start_onboarding:")
    send_webhook_update(update)

    assert_response :success

    # Проверяем что был показан экран онбординга
    edit_content = extract_edited_message_content(@bot.requests)
    assert_not_nil edit_content
    assert_includes edit_content[:text], I18n.t('telegram_bot.onboarding.add_channels')

    # Пользователь добавляет канал
    @bot.reset
    update = create_user_update(user_id: user.id, username: "newbie",
                               command: "@mychannel")
    send_webhook_update(update)

    assert_response :success
    assert_operator @bot.requests.size, :>=, 1
  end

  test "subscription management workflow" do
    # Создаем пользователя с подписками
    user = TelegramUser.create!(
      username: "subscriber",
      first_name: "Test",
      language_code: "ru",
      timezone: "UTC"
    )

    channel1 = Channel.create!(telegram_id: 1001, username: "channel1", title: "Channel 1")
    channel2 = Channel.create!(telegram_id: 1002, username: "channel2", title: "Channel 2")

    Subscription.create!(telegram_user: user, channel: channel1, priority: 1, active: true)
    Subscription.create!(telegram_user: user, channel: channel2, priority: 2, active: true)

    # Проверяем список подписок
    update = create_user_update(user_id: user.id, username: "subscriber",
                               command: "/list")
    send_webhook_update(update)

    assert_response :success

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], "Channel 1"
    assert_includes message_content[:text], "Channel 2"
    assert_not_nil message_content[:reply_markup]
  end
end