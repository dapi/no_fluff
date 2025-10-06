require "test_helper"

class Telegram::ChannelsListServiceTest < ActiveSupport::TestCase
  def setup
    @admin_user = create_admin_user
    @regular_user = create_regular_user
    @service = Telegram::ChannelsListService.new(nil, @admin_user)
  end

  # Тест проверки прав администратора
  test "should return access denied for non-admin user" do
    service = Telegram::ChannelsListService.new(nil, @regular_user)
    result = service.execute

    assert_equal :access_denied, result[:status]
    assert_match I18n.t('telegram_bot.channels.list.access_denied'), result[:message]
  end

  test "should allow access for admin user" do
    @admin_user.update!(is_admin: true)
    result = @service.execute

    assert_not_equal :access_denied, result[:status]
  end

  test "should return access denied for nil user" do
    service = Telegram::ChannelsListService.new(nil, nil)
    result = service.execute

    assert_equal :access_denied, result[:status]
  end

  # Тест получения списка каналов
  test "should return channels list for admin user" do
    @admin_user.update!(is_admin: true)
    result = @service.execute

    assert_equal :success, result[:status]
    assert_match I18n.t('telegram_bot.channels.list.title'), result[:message]
    assert_match /@popular_channel/, result[:message]
    assert_match /@medium_channel/, result[:message]
  end

  test "should include subscribers count in output" do
    @admin_user.update!(is_admin: true)
    result = @service.execute

    # popular_channel должен иметь 2 подписчиков из наших фикстур
    assert_match /2 подписчиков/, result[:message]
  end

  # Тест сортировки каналов
  test "should sort channels by subscribers count descending" do
    @admin_user.update!(is_admin: true)
    result = @service.execute

    # popular_channel (2 подписчика) должен быть раньше medium_channel (1 подписчик)
    popular_pos = result[:message].index('@popular_channel')
    medium_pos = result[:message].index('@medium_channel')

    assert popular_pos < medium_pos, "popular_channel should appear before medium_channel"
  end

  test "should show verification status" do
    @admin_user.update!(is_admin: true)
    result = @service.execute

    # popular_channel верифицирован (is_verified: true)
    assert_match /✅ @popular_channel/, result[:message]
    # medium_channel не верифицирован
    assert_match /⭕ @medium_channel/, result[:message]
  end

  test "should show active status" do
    @admin_user.update!(is_admin: true)
    result = @service.execute

    # active каналы показываем с зеленой точкой
    assert_match /🟢/, result[:message]
    # inactive каналы показываем с красной точкой
    assert_match /🔴/, result[:message]
  end

  # Тест обработки пустого списка
  test "should return empty response when no channels exist" do
    @admin_user.update!(is_admin: true)

    # Создаем новый сервис, который будет работать с пустым набором каналов
    service = Telegram::ChannelsListService.new(nil, @admin_user)

    # Мокаем метод получения каналов, чтобы он вернул пустой массив
    def service.fetch_channels_with_stats
      []
    end

    result = service.execute

    assert_equal :empty, result[:status]
    assert_match I18n.t('telegram_bot.channels.list.no_channels'), result[:message]
  end

  # Тест форматирования времени последнего поста
  test "should show last post information" do
    @admin_user.update!(is_admin: true)
    result = @service.execute

    # Должен содержать информацию о последнем посте
    assert_match /Последний пост:/, result[:message]
  end

  test "should handle channels with no posts" do
    @admin_user.update!(is_admin: true)

    # Создаем канал без постов
    channel_with_no_posts = Channel.create!(
      telegram_id: 1234567890,
      username: 'no_posts_channel',
      title: 'No Posts Channel',
      subscribers_count: 10,
      is_verified: false,
      active: true
    )

    result = @service.execute

    assert_match /Постов пока не было/, result[:message]

    # Очищаем
    channel_with_no_posts.destroy
  end

  private

  def create_admin_user
    TelegramUser.create!(
      username: 'admin_user',
      first_name: 'Admin',
      language_code: 'ru',
      timezone: 'UTC',
      is_admin: true
    )
  end

  def create_regular_user
    TelegramUser.create!(
      username: 'regular_user',
      first_name: 'Regular',
      language_code: 'ru',
      timezone: 'UTC',
      is_admin: false
    )
  end
end