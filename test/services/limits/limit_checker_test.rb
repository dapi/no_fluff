require 'test_helper'

class Limits::LimitCheckerTest < ActiveSupport::TestCase
  def setup
    @user = TelegramUser.create!(
      username: 'test_user',
      timezone: 'UTC',
      language_code: 'en'
    )
    @limit_checker = Limits::LimitChecker.new(@user)
  end

  def teardown
    @user.subscriptions.destroy_all
    @user.destroy
  end

  # Test can_add_channel? method
  test 'can_add_channel? should return true for premium users regardless of channel count' do
    @user.update!(is_premium: true)

    # Add 15 channels
    15.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 1000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert @limit_checker.can_add_channel?
  end

  test 'can_add_channel? should return true for regular users with less than 10 channels' do
    @user.update!(is_premium: false)

    # Add 5 channels
    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 2000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert @limit_checker.can_add_channel?
  end

  test 'can_add_channel? should return false for regular users with exactly 10 channels' do
    @user.update!(is_premium: false)

    # Add exactly 10 channels
    10.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 3000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_not @limit_checker.can_add_channel?
  end

  test 'can_add_channel? should return false for regular users with more than 10 channels' do
    @user.update!(is_premium: false)

    # Add 12 channels
    12.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 4000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_not @limit_checker.can_add_channel?
  end

  # Test limit_reached? method
  test 'limit_reached? should return false for premium users' do
    @user.update!(is_premium: true)

    # Add 20 channels
    20.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 5000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_not @limit_checker.limit_reached?
  end

  test 'limit_reached? should return false for regular users with less than 10 channels' do
    @user.update!(is_premium: false)

    # Add 8 channels
    8.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 6000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_not @limit_checker.limit_reached?
  end

  test 'limit_reached? should return true for regular users with 10 or more channels' do
    @user.update!(is_premium: false)

    # Add 10 channels
    10.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 7000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert @limit_checker.limit_reached?
  end

  # Test current_channels_count method
  test 'current_channels_count should return 0 for new user' do
    assert_equal 0, @limit_checker.current_channels_count
  end

  test 'current_channels_count should count all subscriptions regardless of active status' do
    # Add active subscriptions
    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 8000 + i, username: "active_channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    # Add inactive subscriptions
    3.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 8500 + i, username: "inactive_channel_#{i}"),
        priority: 5,
        active: false
      )
    end

    assert_equal 8, @limit_checker.current_channels_count
  end

  # Test remaining_free_channels method
  test 'remaining_free_channels should return 0 for premium users' do
    @user.update!(is_premium: true)

    # Add channels
    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 9000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_equal 0, @limit_checker.remaining_free_channels
  end

  test 'remaining_free_channels should return remaining slots for regular users' do
    @user.update!(is_premium: false)

    # Add 3 channels
    3.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 10000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_equal 7, @limit_checker.remaining_free_channels
  end

  test 'remaining_free_channels should return 0 when limit reached' do
    @user.update!(is_premium: false)

    # Add 10 channels (limit reached)
    10.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 11000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_equal 0, @limit_checker.remaining_free_channels
  end

  test 'remaining_free_channels should return 0 when limit exceeded' do
    @user.update!(is_premium: false)

    # Add 12 channels (limit exceeded)
    12.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 12000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_equal 0, @limit_checker.remaining_free_channels
  end

  # Test limit_status method
  test 'limit_status should return complete status for regular user' do
    @user.update!(is_premium: false)

    # Add 5 channels
    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 13000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    status = @limit_checker.limit_status

    assert_equal 5, status[:current_count]
    assert_equal 10, status[:limit]
    assert_equal 5, status[:remaining]
    assert_equal false, status[:is_premium]
    assert_equal true, status[:can_add_more]
    assert_equal false, status[:limit_reached]
  end

  test 'limit_status should return complete status for premium user' do
    @user.update!(is_premium: true)

    # Add 15 channels
    15.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 14000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    status = @limit_checker.limit_status

    assert_equal 15, status[:current_count]
    assert_equal 10, status[:limit]
    assert_equal 0, status[:remaining]
    assert_equal true, status[:is_premium]
    assert_equal true, status[:can_add_more]
    assert_equal false, status[:limit_reached]
  end

  # Test can_add_channels? method
  test 'can_add_channels? should return true for premium users regardless of count' do
    @user.update!(is_premium: true)

    # Add existing channels
    8.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 15000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert @limit_checker.can_add_channels?(5)
    assert @limit_checker.can_add_channels?(10)
    assert @limit_checker.can_add_channels?(100)
  end

  test 'can_add_channels? should return true if requested count fits within limit' do
    @user.update!(is_premium: false)

    # Add 7 channels
    7.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 16000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert @limit_checker.can_add_channels?(1)  # 7 + 1 = 8 <= 10
    assert @limit_checker.can_add_channels?(2)  # 7 + 2 = 9 <= 10
    assert @limit_checker.can_add_channels?(3)  # 7 + 3 = 10 <= 10
  end

  test 'can_add_channels? should return false if requested count exceeds limit' do
    @user.update!(is_premium: false)

    # Add 7 channels
    7.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 17000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_not @limit_checker.can_add_channels?(4)  # 7 + 4 = 11 > 10
    assert_not @limit_checker.can_add_channels?(5)  # 7 + 5 = 12 > 10
  end

  # Test limit_reached_message method
  test 'limit_reached_message should return localized message' do
    @user.update!(is_premium: false)

    # Add 12 channels to exceed limit
    12.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 18000 + i, username: "channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    message = @limit_checker.limit_reached_message
    assert_includes message, "10"
    assert_includes message, "12"
  end

  # Edge cases
  test 'should handle user with mixed active/inactive subscriptions' do
    @user.update!(is_premium: false)

    # Add 6 active and 4 inactive subscriptions (total 10)
    6.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 19000 + i, username: "active_#{i}"),
        priority: 5,
        active: true
      )
    end

    4.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 19500 + i, username: "inactive_#{i}"),
        priority: 5,
        active: false
      )
    end

    assert_equal 10, @limit_checker.current_channels_count
    assert_not @limit_checker.can_add_channel?
    assert @limit_checker.limit_reached?
    assert_equal 0, @limit_checker.remaining_free_channels
  end

  test 'should handle boundary case of exactly 10 channels' do
    @user.update!(is_premium: false)

    # Add exactly 10 channels
    10.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 20000 + i, username: "boundary_channel_#{i}"),
        priority: 5,
        active: true
      )
    end

    assert_equal 10, @limit_checker.current_channels_count
    assert_not @limit_checker.can_add_channel?
    assert @limit_checker.limit_reached?
    assert_equal 0, @limit_checker.remaining_free_channels
  end
end