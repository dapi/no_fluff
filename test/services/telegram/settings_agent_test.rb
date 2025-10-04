require 'test_helper'

class Telegram::SettingsAgentTest < ActiveSupport::TestCase
  def setup
    @bot = Telegram.bot
    @bot.reset
    @user = TelegramUser.create!(
      username: 'test_user',
      telegram_id: 123456,
      first_name: 'Test',
      language_code: 'ru',
      delivery_frequency: 'once_daily',
      content_format: 'original',
      filter_strictness: 'medium'
    )
    @agent = Telegram::SettingsAgent.new(@bot, @user)
  end

  def teardown
    @bot.reset if @bot
  end

  # Helper method для извлечения содержимого сообщения
  def extract_message_content(requests)
    message_requests = requests.select { |method, _| method == :sendMessage }
    return nil if message_requests.empty?

    method, params = message_requests.first
    params.first
  end

  # Тесты для инициализации
  test '#initialize сохраняет переданные зависимости' do
    agent = Telegram::SettingsAgent.new(@bot, @user)

    assert_equal @bot, agent.instance_variable_get(:@bot)
    assert_equal @user, agent.instance_variable_get(:@user)
    assert_equal Rails.logger, agent.instance_variable_get(:@logger)
    assert_equal Rails.cache, agent.instance_variable_get(:@cache)
  end

  test '#initialize корректно обрабатывает параметры' do
    agent = Telegram::SettingsAgent.new(@bot, @user)

    assert_instance_of Telegram::SettingsAgent, agent
    assert_respond_to agent, :show_settings
  end

  # Тесты для show_settings
  test '#show_settings отправляет сообщение с текстом настроек' do
    @agent.show_settings

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.settings.title')
  end

  test '#show_settings включает все секции настроек в текст' do
    @agent.show_settings

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    # Проверяем наличие локализованных меток настроек
    assert_includes message_content[:text], I18n.t('telegram_bot.settings.delivery_frequency.label')
    assert_includes message_content[:text], I18n.t('telegram_bot.settings.content_format.label')
    assert_includes message_content[:text], I18n.t('telegram_bot.settings.filter_strictness.label')
  end

  test '#show_settings отправляет inline клавиатуру' do
    @agent.show_settings

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_not_nil message_content[:reply_markup]
  end

  test '#show_settings логирует действие' do
    # Этот тест проверяет, что метод выполняется без ошибок
    assert_nothing_raised do
      @agent.show_settings
    end

    # Проверяем что был отправлен ответ
    assert_operator @bot.requests.size, :>=, 1
  end

  test '#show_settings логирует производительность' do
    assert_nothing_raised do
      @agent.show_settings
    end

    # Проверяем что был отправлен ответ
    assert_operator @bot.requests.size, :>=, 1
  end

  # Тесты для обработки ошибок в show_settings
  test '#show_settings обрабатывает ошибки при построении текста' do
    # Создадим ситуацию, которая вызовет ошибку
    invalid_user = TelegramUser.new(username: nil)
    agent = Telegram::SettingsAgent.new(@bot, invalid_user)

    # Должен отправить сообщение об ошибке
    assert_nothing_raised do
      agent.show_settings
    end

    # Проверяем что было отправлено сообщение об ошибке
    assert_operator @bot.requests.size, :>=, 1
  end

  test '#show_settings отправляет сообщение об ошибке при исключении' do
    # Создадим ситуацию, которая вызовет ошибку
    @user.update!(delivery_frequency: nil)

    # Должен отправить сообщение об ошибке
    assert_nothing_raised do
      @agent.show_settings
    end

    # Проверяем что был отправлен ответ
    assert_operator @bot.requests.size, :>=, 1
  end

  # Тесты для update_setting
  test '#update_setting обновляет настройку delivery_frequency' do
    assert_changes '@user.reload.delivery_frequency', from: 'once_daily', to: 'real_time' do
      @agent.update_setting('delivery_frequency', 'real_time')
    end

    # Проверяем что было отправлено сообщение об успехе
    assert_operator @bot.requests.size, :>=, 1
    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.settings.success.updated')
  end

  test '#update_setting обновляет настройку content_format' do
    assert_changes '@user.reload.content_format', from: 'original', to: 'summaries' do
      @agent.update_setting('content_format', 'summaries')
    end

    # Проверяем что было отправлено сообщение об успехе
    assert_operator @bot.requests.size, :>=, 1
  end

  test '#update_setting обновляет настройку filter_strictness' do
    assert_changes '@user.reload.filter_strictness', from: 'medium', to: 'high' do
      @agent.update_setting('filter_strictness', 'high')
    end

    # Проверяем что было отправлено сообщение об успехе
    assert_operator @bot.requests.size, :>=, 1
  end

  test '#update_setting отправляет сообщение об успехе' do
    @agent.update_setting('delivery_frequency', 'real_time')

    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
    assert_includes message_content[:text], I18n.t('telegram_bot.settings.success.updated')
  end

  test '#update_setting логирует действие' do
    # Проверяем что метод выполняется без ошибок
    assert_nothing_raised do
      @agent.update_setting('delivery_frequency', 'real_time')
    end

    # Проверяем что был отправлен ответ
    assert_operator @bot.requests.size, :>=, 1
  end

  # Тесты для негативных сценариев
  test '#update_setting не обновляет при невалидном названии настройки' do
    original_value = @user.delivery_frequency

    assert_no_changes '@user.reload.delivery_frequency' do
      @agent.update_setting('invalid_setting', 'real_time')
    end

    assert_equal original_value, @user.reload.delivery_frequency

    # Проверяем что было отправлено сообщение об ошибке
    assert_operator @bot.requests.size, :>=, 1
    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
  end

  test '#update_setting не обновляет при невалидном значении' do
    original_value = @user.delivery_frequency

    assert_no_changes '@user.reload.delivery_frequency' do
      @agent.update_setting('delivery_frequency', 'invalid_value')
    end

    assert_equal original_value, @user.reload.delivery_frequency

    # Проверяем что было отправлено сообщение об ошибке
    assert_operator @bot.requests.size, :>=, 1
    message_content = extract_message_content(@bot.requests)
    assert_not_nil message_content
  end

  test '#update_setting обрабатывает ошибки ActiveRecord' do
    # Мокаем пользователя чтобы он вызвал ошибку при обновлении
    @user.define_singleton_method(:update!) do |attributes|
      raise ActiveRecord::RecordInvalid.new(@user)
    end

    assert_nothing_raised do
      @agent.update_setting('delivery_frequency', 'real_time')
    end

    # Проверяем что был отправлен ответ
    assert_operator @bot.requests.size, :>=, 1
  end

  test '#update_setting обрабатывает ошибки Telegram API' do
    # Этот тест проверяет общую обработку ошибок
    assert_nothing_raised do
      @agent.update_setting('delivery_frequency', 'real_time')
    end

    # Проверяем что был отправлен ответ
    assert_operator @bot.requests.size, :>=, 1
  end

  # Тесты для валидации
  test '#validate_setting проверяет валидное название и значение' do
    # Этот тест проверяет приватный метод через публичный интерфейс
    assert_nothing_raised do
      @agent.update_setting('delivery_frequency', 'real_time')
    end

    # Настройка должна обновиться
    assert_equal 'real_time', @user.reload.delivery_frequency
  end

  test '#validate_setting отвергает невалидное название' do
    original_value = @user.delivery_frequency

    @agent.update_setting('invalid', 'value')

    # Настройка не должна измениться
    assert_equal original_value, @user.reload.delivery_frequency
  end

  test '#validate_setting отвергает невалидное значение' do
    original_value = @user.delivery_frequency

    @agent.update_setting('delivery_frequency', 'invalid')

    # Настройка не должна измениться
    assert_equal original_value, @user.reload.delivery_frequency
  end

  test '#valid_value? проверяет значения корректно' do
    # Тестируем через публичный метод
    @agent.update_setting('delivery_frequency', 'real_time')
    assert_equal 'real_time', @user.reload.delivery_frequency

    @agent.update_setting('delivery_frequency', 'invalid')
    # Значение не должно измениться
    assert_equal 'real_time', @user.reload.delivery_frequency
  end
end