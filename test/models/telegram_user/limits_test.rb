# frozen_string_literal: true

require 'test_helper'

class TelegramUser::LimitsTest < ActiveSupport::TestCase
  # Tests for subscription limits functionality
  test 'can_add_channel? should return true for premium users' do
    user = telegram_users(:premium_user)

    # У премиум пользователя должно быть 100+ подписок
    11.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 1000 + i, username: "test_channel_#{i}"),
        active: true
      )
    end

    assert user.can_add_channel?
  end

  test 'can_add_channel? should return true for regular users with less than 10 channels' do
    user = TelegramUser.create!(
      username: 'regular_user_less',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )

    # Добавляем 5 подписок
    5.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 2000 + i, username: "channel_#{i}"),
        active: true
      )
    end

    assert user.can_add_channel?
  end

  test 'can_add_channel? should return false for regular users with 10 or more channels' do
    user = telegram_users(:two)

    # Добавляем 10 подписок
    10.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 3000 + i, username: "channel_#{i}"),
        active: true
      )
    end

    assert_not user.can_add_channel?
  end

  test 'can_add_channel? should count all subscriptions regardless of active status' do
    user = TelegramUser.create!(
      username: 'mixed_status_user_new',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )

    # Добавляем 5 активных и 5 неактивных подписок
    5.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 4000 + i, username: "active_channel_#{i}"),
        active: true
      )
    end

    5.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 5000 + i, username: "inactive_channel_#{i}"),
        active: false
      )
    end

    # Всего 10 подписок, но только 5 активных - лимит все равно достигнут
    assert_not user.can_add_channel?
    assert_equal 10, user.channels_count
  end

  test 'channels_count should return total number of subscriptions' do
    user = TelegramUser.create!(
      username: 'counter_user_new',
      timezone: 'UTC',
      language_code: 'en'
    )

    assert_equal 0, user.channels_count

    # Добавляем подписки с разным статусом
    user.subscriptions.create!(
      channel: Channel.create!(telegram_id: 6001, username: 'channel_1'),
      active: true
    )
    assert_equal 1, user.channels_count

    user.subscriptions.create!(
      channel: Channel.create!(telegram_id: 6002, username: 'channel_2'),
      active: false
    )
    assert_equal 2, user.channels_count

    user.subscriptions.create!(
      channel: Channel.create!(telegram_id: 6003, username: 'channel_3'),
      active: true
    )
    assert_equal 3, user.channels_count
  end

  test 'channels_limit_reached? should return true for regular users with 10+ channels' do
    user = TelegramUser.create!(
      username: 'limit_user_new',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )

    # Добавляем 10 подписок
    10.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 7000 + i, username: "channel_#{i}"),
        active: true
      )
    end

    assert user.channels_limit_reached?
  end

  test 'channels_limit_reached? should return false for premium users regardless of channel count' do
    user = telegram_users(:premium_user)

    # Добавляем 15 подписок
    15.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 8000 + i, username: "channel_#{i}"),
        active: true
      )
    end

    assert_not user.channels_limit_reached?
  end

  test 'channels_limit_reached? should return false for regular users with less than 10 channels' do
    user = TelegramUser.create!(
      username: 'no_limit_user_new',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )

    # Добавляем 5 подписок
    5.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 9000 + i, username: "channel_#{i}"),
        active: true
      )
    end

    assert_not user.channels_limit_reached?
  end

  # Edge cases and boundary tests
  test 'should handle boundary case exactly at limit' do
    user = TelegramUser.create!(
      username: 'boundary_user_new',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )

    # Добавляем ровно 10 подписок (лимит для обычных пользователей)
    10.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 10000 + i, username: "boundary_channel_#{i}"),
        active: true
      )
    end

    assert_equal 10, user.channels_count
    assert user.channels_limit_reached?
    assert_not user.can_add_channel?
  end

  test 'should handle boundary case just under limit' do
    user = TelegramUser.create!(
      username: 'under_limit_user_new',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )

    # Добавляем 9 подписок (на одну меньше лимита)
    9.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 11000 + i, username: "under_limit_channel_#{i}"),
        active: true
      )
    end

    assert_equal 9, user.channels_count
    assert_not user.channels_limit_reached?
    assert user.can_add_channel?
  end

  test 'should handle user with no subscriptions' do
    user = TelegramUser.create!(
      username: 'no_subs_user',
      timezone: 'UTC',
      language_code: 'en'
    )

    assert_equal 0, user.channels_count
    assert_not user.channels_limit_reached?
    assert user.can_add_channel?
  end

  test 'should handle premium user with many subscriptions' do
    user = TelegramUser.create!(
      username: 'many_subs_premium_user',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: true
    )

    # Добавляем много подписок для премиум пользователя
    25.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 12000 + i, username: "premium_channel_#{i}"),
        active: true
      )
    end

    assert_equal 25, user.channels_count
    assert_not user.channels_limit_reached?
    assert user.can_add_channel?
  end

  test 'should handle mixed active/inactive subscriptions for limit calculation' do
    user = TelegramUser.create!(
      username: 'mixed_user',
      timezone: 'UTC',
      language_code: 'en',
      is_premium: false
    )

    # Добавляем 7 активных и 3 неактивные (всего 10)
    7.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 13000 + i, username: "mixed_active_#{i}"),
        active: true
      )
    end

    3.times do |i|
      user.subscriptions.create!(
        channel: Channel.create!(telegram_id: 14000 + i, username: "mixed_inactive_#{i}"),
        active: false
      )
    end

    # Лимит достигнут, так как считаются все подписки
    assert_equal 10, user.channels_count
    assert user.channels_limit_reached?
    assert_not user.can_add_channel?
  end
end
