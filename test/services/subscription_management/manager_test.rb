require 'test_helper'

class SubscriptionManagement::ManagerTest < ActiveSupport::TestCase
  def setup
    @user = TelegramUser.create!(
      username: 'test_user',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )
    @manager = SubscriptionManagement::Manager.new(@user)
  end

  def teardown
    @user.subscriptions.destroy_all
    @user.destroy
  end

  # Test activate_premium_subscription method
  test 'activate_premium_subscription should upgrade user to premium' do
    assert_not @user.is_premium?

    result = @manager.activate_premium_subscription

    assert result[:success]
    @user.reload
    assert @user.is_premium?
    assert_includes result[:message], 'Подписка активирована'
  end

  test 'activate_premium_subscription should return error for already premium user' do
    @user.update!(is_premium: true)

    result = @manager.activate_premium_subscription

    assert_not result[:success]
    assert_includes result[:message], 'уже имеет премиум статус'
    @user.reload
    assert @user.is_premium?  # Should still be premium
  end

  # test 'activate_premium_subscription should handle database errors gracefully' do
  #   # Mock save to raise an error using Mocha syntax
  #   @user.stubs(:update!).raises(StandardError.new("Database error"))
  #
  #   result = @manager.activate_premium_subscription
  #
  #   assert_not result[:success]
  #   assert_includes result[:message], "Ошибка при работе с подпиской"
  # end

  # Test deactivate_premium_subscription method
  test 'deactivate_premium_subscription should downgrade user from premium' do
    @user.update!(is_premium: true)

    result = @manager.deactivate_premium_subscription

    assert result[:success]
    @user.reload
    assert_not @user.is_premium?
    assert_includes result[:message], 'Подписка деактивирована'
  end

  test 'deactivate_premium_subscription should return error for non-premium user' do
    result = @manager.deactivate_premium_subscription

    assert_not result[:success]
    assert_includes result[:message], 'не имеет премиум статуса'
    assert_not @user.is_premium?
  end

  test 'deactivate_premium_subscription should show warning when user exceeds limit after deactivation' do
    @user.update!(is_premium: true)

    # Add 12 channels (exceeds free limit of 10)
    12.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 1000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    result = @manager.deactivate_premium_subscription

    assert result[:success]
    assert result[:warning]  # Should have warning flag
    assert_includes result[:message], 'превышает бесплатный лимит'
    assert_includes result[:message], '12'
    assert_includes result[:message], '10'
  end

  test 'deactivate_premium_subscription should not show warning when user within limit' do
    @user.update!(is_premium: true)

    # Add only 5 channels (within free limit)
    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 2000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    result = @manager.deactivate_premium_subscription

    assert result[:success]
    assert_not result[:warning]  # Should not have warning flag (should be nil or false)
    assert_not_includes result[:message], 'превышает бесплатный лимит'
  end

  # Test subscription_status method
  test 'subscription_status should return complete status for regular user' do
    # Add 5 channels
    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 3000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    status = @manager.subscription_status

    assert_equal false, status[:is_premium]
    assert_equal 5, status[:channels_count]
    assert_equal 10, status[:limit]
    assert_equal true, status[:can_add_more]
    assert_equal 5, status[:remaining_free]
    assert_equal false, status[:limit_reached]
  end

  test 'subscription_status should return complete status for premium user' do
    @user.update!(is_premium: true)

    # Add 15 channels
    15.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 4000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    status = @manager.subscription_status

    assert_equal true, status[:is_premium]
    assert_equal 15, status[:channels_count]
    assert_equal 10, status[:limit]
    assert_equal true, status[:can_add_more]
    assert_equal 0, status[:remaining_free]
    assert_equal false, status[:limit_reached]
  end

  test 'subscription_status should count all subscriptions regardless of active status' do
    # Add 6 active and 4 inactive subscriptions
    6.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 5000 + i, username: "active_#{i}"),
                active: true
      )
    end

    4.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 5500 + i, username: "inactive_#{i}"),
                active: false
      )
    end

    status = @manager.subscription_status

    assert_equal 10, status[:channels_count]
    assert_equal false, status[:can_add_more]
    assert_equal 0, status[:remaining_free]
    assert_equal true, status[:limit_reached]
  end

  # Test needs_subscription? method
  test 'needs_subscription? should return false for premium users' do
    @user.update!(is_premium: true)

    # Add many channels
    20.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 6000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    assert_not @manager.needs_subscription?
  end

  test 'needs_subscription? should return false for regular users within limit' do
    # Add 5 channels
    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 7000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    assert_not @manager.needs_subscription?
  end

  test 'needs_subscription? should return true for regular users at limit' do
    # Add exactly 10 channels
    10.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 8000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    assert @manager.needs_subscription?
  end

  test 'needs_subscription? should return true for regular users over limit' do
    # Add 12 channels
    12.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 9000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    assert @manager.needs_subscription?
  end

  # Test subscription_offer method
  test 'subscription_offer should return complete offer data' do
    # Add 12 channels
    12.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 10000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    offer = @manager.subscription_offer

    assert_equal 12, offer[:current_channels]
    assert_equal 10, offer[:limit]
    assert_equal 2, offer[:exceeded_by]
    assert_includes offer[:message], '12'
    assert_includes offer[:message], '10'
    assert_equal '💎 Оформить подписку', offer[:activate_button_text]
  end

  test 'subscription_offer should handle user exactly at limit' do
    # Add exactly 10 channels
    10.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 11000 + i, username: "channel_#{i}"),
                active: true
      )
    end

    offer = @manager.subscription_offer

    assert_equal 10, offer[:current_channels]
    assert_equal 10, offer[:limit]
    assert_equal 0, offer[:exceeded_by]
    assert_includes offer[:message], '10'
    assert_includes offer[:message], '10'
  end

  test 'subscription_offer should count all subscriptions regardless of active status' do
    # Add 6 active and 5 inactive subscriptions (total 11)
    6.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 12000 + i, username: "active_#{i}"),
                active: true
      )
    end

    5.times do |i|
      @user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 12500 + i, username: "inactive_#{i}"),
                active: false
      )
    end

    offer = @manager.subscription_offer

    assert_equal 11, offer[:current_channels]
    assert_equal 1, offer[:exceeded_by]
  end

  # Edge cases
  test 'should handle user with no subscriptions' do
    offer = @manager.subscription_offer

    assert_equal 0, offer[:current_channels]
    assert_equal 10, offer[:limit]
    assert_equal 0, offer[:exceeded_by]
  end

  # test 'should handle error logging for failed operations' do
  #   # Test that errors are properly logged and notified to Bugsnag
  #   Bugsnag.stubs(:notify)
  #
  #   @user.update!(is_premium: true)
  #   @user.stubs(:update!).raises(StandardError.new("Test error"))
  #
  #   result = @manager.deactivate_premium_subscription
  #
  #   assert_not result[:success]
  #   # Note: We can't easily test have_received with Mocha in this setup
  # end
end
