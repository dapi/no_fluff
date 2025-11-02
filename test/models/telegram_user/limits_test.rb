# frozen_string_literal: true

require 'test_helper'

class TelegramUser::LimitsTest < ActiveSupport::TestCase
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
