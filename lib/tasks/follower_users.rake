# frozen_string_literal: true

namespace :follower_users do
  desc 'Create a new follower user'
  task :create, [ :phone_number ] => :environment do |t, args|
    phone_number = args[:phone_number]

    if phone_number.blank?
      puts '❌ Phone number is required'
      puts 'Usage: rails follower_users:create[+1234567890]'
      next
    end

    begin
      user = FollowerUser.create!(
        phone_number: phone_number
      )

      puts '✅ FollowerUser created successfully:'
      puts "   ID: #{user.id}"
      puts "   Phone: #{user.phone_number}"
      puts "   Auth Status: #{user.auth_status}"
      puts ''
      puts '📝 Next steps:'
      puts '1. Start authorization: user.start_authorization!'
      puts "2. Confirm with code: user.confirm_authorization!('12345')"

    rescue ActiveRecord::RecordInvalid => e
      puts "❌ Failed to create follower user: #{e.message}"
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
    end
  end

  desc 'List all follower users'
  task list: :environment do
    users = FollowerUser.all.order(:created_at)

    if users.empty?
      puts '📭 No follower users found'
      next
    end

    puts "📋 Follower Users (#{users.count} total):"
    puts ''
    users.each do |user|
      status_icon = case user.auth_status
      when 'authorized' then '✅'
      when 'pending' then '⏳'
      when 'failed' then '❌'
      when 'banned' then '🚫'
      when 'revoked' then '🔄'
      else '❓'
      end

      puts "#{status_icon} ##{user.id} - #{user.phone_number}"
      puts "   Status: #{user.auth_status}"
      puts "   Channels: #{user.channels_count}/#{user.max_channels}"
      puts "   Health: #{user.health_score}%"
      puts "   Workload: #{(user.workload_score * 100).round(1)}%"
      puts "   Last activity: #{user.last_activity_at || 'Never'}"
      puts "   Created: #{user.created_at}"
      puts ''
    end
  end

  desc 'Show details of a specific follower user'
  task :show, [ :id ] => :environment do |t, args|
    id = args[:id]

    if id.blank?
      puts '❌ User ID is required'
      puts 'Usage: rails follower_users:show[1]'
      next
    end

    user = FollowerUser.find_by(id: id)

    unless user
      puts "❌ FollowerUser with ID #{id} not found"
      next
    end

    puts "👤 Follower User ##{user.id}"
    puts '=' * 40
    puts "Phone: #{user.phone_number}"
    puts "Auth Status: #{user.auth_status}"
    puts ''
    puts '📊 Statistics:'
    puts "   Channels: #{user.channels_count}/#{user.max_channels}"
    puts "   Daily joins: #{user.daily_joins_count}/#{user.daily_joins_limit}"
    puts "   Health Score: #{user.health_score}%"
    puts "   Workload: #{(user.workload_score * 100).round(1)}%"
    puts "   Consecutive errors: #{user.consecutive_errors}"
    puts "   Priority: #{user.priority}"
    puts ''
    puts '📅 Timeline:'
    puts "   Created: #{user.created_at}"
    puts "   Last authorized: #{user.last_authorized_at || 'Never'}"
    puts "   Last successful join: #{user.last_successful_join || 'Never'}"
    puts "   Last activity: #{user.last_activity_at || 'Never'}"
    puts ''
    puts '🔐 Security:'
    puts "   Has session: #{user.has_session? ? '✅' : '❌'}"
    puts "   Has custom credentials: #{user.has_custom_credentials? ? '✅' : '❌'}"
    puts "   Session active: #{user.session_active? ? '✅' : '❌'}"
    puts "   Needs reauthorization: #{user.needs_reauthorization? ? '✅' : '❌'}"
    puts ''
    puts '🚀 Capabilities:'
    puts "   Can join channel: #{user.can_join_channel? ? '✅' : '❌'}"
    puts "   Healthy: #{user.healthy? ? '✅' : '❌'}"
    puts "   Overloaded: #{user.overloaded? ? '✅' : '❌'}"

    if user.channels.any?
      puts ''
      puts "📺 Assigned Channels (#{user.channels.count}):"
      user.channels.includes(:subscriptions).each do |channel|
        puts "   - #{channel.username} (#{channel.user_access_status})"
      end
    end
  end

  desc 'Authorize a follower user'
  task :authorize, [ :id, :code ] => :environment do |t, args|
    id = args[:id]
    code = args[:code]

    if id.blank?
      puts '❌ User ID is required'
      puts "Usage: rails follower_users:authorize[1,'12345']"
      next
    end

    user = FollowerUser.find_by(id: id)

    unless user
      puts "❌ FollowerUser with ID #{id} not found"
      next
    end

    if user.authorized?
      puts "ℹ️ User ##{id} is already authorized"
      next
    end

    if code.present?
      puts "🔐 Confirming authorization with code: #{code}"
      result = user.confirm_authorization!(code)

      if result[:success]
        puts '✅ Authorization successful!'
        puts "   User: #{result[:user].phone_number}"
        puts "   Status: #{result[:user].auth_status}"
        puts "   Channels assigned: #{result[:user].channels_count}"
      else
        puts "❌ Authorization failed: #{result[:error]}"
      end
    else
      puts '📱 Starting authorization process...'
      result = user.start_authorization!

      if result[:success]
        puts "✅ Verification code sent to #{user.phone_number}"
        puts "🔑 Phone code hash: #{result[:phone_code_hash]}"
        puts ''
        puts '📝 To confirm authorization, run:'
        puts "   rails follower_users:authorize[#{id},'YOUR_CODE']"
        puts ''
        puts "💡 For demo, you can use: rails follower_users:authorize[#{id},'12345']"
      else
        puts "❌ Failed to start authorization: #{result[:error]}"
      end
    end
  end

  desc 'Revoke authorization for a follower user'
  task :revoke, [ :id ] => :environment do |t, args|
    id = args[:id]

    if id.blank?
      puts '❌ User ID is required'
      puts 'Usage: rails follower_users:revoke[1]'
      next
    end

    user = FollowerUser.find_by(id: id)

    unless user
      puts "❌ FollowerUser with ID #{id} not found"
      next
    end

    unless user.authorized?
      puts "ℹ️ User ##{id} is not authorized"
      next
    end

    if user.revoke_authorization!
      puts "✅ Authorization revoked for user ##{id}"
      puts "   Removed from #{user.channels_count} channels"
      puts '   Session data cleared'
    else
      puts '❌ Failed to revoke authorization'
    end
  end

  desc 'Cleanup expired authorizations'
  task cleanup: :environment do
    service = Telegram::AuthorizationService.instance
    service.cleanup_expired_authorizations

    stats = service.authorization_stats
    puts '🧹 Cleanup complete'
    puts "   Pending: #{stats[:pending]}"
    puts "   In progress: #{stats[:in_progress]}"
    puts "   Expired: #{stats[:expired]}"
  end

  desc 'Test authorization flow'
  task :test, [ :phone_number ] => :environment do |t, args|
    phone_number = args[:phone_number] || '+1234567890'

    puts '🧪 Testing authorization flow...'
    puts "📱 Creating user: #{phone_number}"

    user = FollowerUser.create!(
      phone_number: phone_number
    )

    puts "✅ User created: ##{user.id}"
    puts '📱 Starting authorization...'

    auth_result = user.start_authorization!

    if auth_result[:success]
      puts "✅ Code sent to #{phone_number}"
      puts "🔑 Phone code hash: #{auth_result[:phone_code_hash]}"
      puts ''
      puts "📝 Confirming with demo code '12345'..."

      confirm_result = user.confirm_authorization!('12345')

      if confirm_result[:success]
        puts '✅ Test authorization successful!'
        puts "   User: #{confirm_result[:user].phone_number}"
        puts "   Status: #{confirm_result[:user].auth_status}"
        puts "   Session: #{confirm_result[:user].has_session? ? 'Saved ✅' : 'Not saved ❌'}"

        # Test channel assignment
        puts ''
        puts '📺 Testing channel assignment...'

        test_channel = Channel.find_or_create_by(telegram_id: 12345678) do |channel|
          channel.username = "test_channel_#{Time.current.to_i}"
          channel.title = 'Test Channel'
        end

        if test_channel.assign_to_follower_user(user)
          puts "✅ Channel assigned: #{test_channel.username}"
          puts "   User channels: #{user.reload.channels_count}"
        else
          puts '❌ Failed to assign channel'
        end
      else
        puts "❌ Test authorization failed: #{confirm_result[:error]}"
      end
    else
      puts "❌ Failed to start test authorization: #{auth_result[:error]}"
    end

    puts ''
    puts '📊 Final user state:'
    user.reload
    puts "   Status: #{user.auth_status}"
    puts "   Channels: #{user.channels_count}"
    puts "   Health: #{user.health_score}%"
  end

  desc 'Show authorization statistics'
  task stats: :environment do
    service = Telegram::AuthorizationService.instance
    stats = service.authorization_stats

    puts '📊 Authorization Statistics'
    puts '=' * 25
    puts "Pending: #{stats[:pending]}"
    puts "In Progress: #{stats[:in_progress]}"
    puts "Expired: #{stats[:expired]}"
    puts ''

    puts '👥 Follower User Statistics'
    puts '=' * 30
    total = FollowerUser.count
    authorized = FollowerUser.authorized.count
    pending = FollowerUser.pending.count
    failed = FollowerUser.where(auth_status: :failed).count
    banned = FollowerUser.where(auth_status: :banned).count
    revoked = FollowerUser.where(auth_status: :revoked).count

    puts "Total Users: #{total}"
    puts "Authorized: #{authorized} (#{(authorized.to_f / total * 100).round(1)}%)"
    puts "Pending: #{pending} (#{(pending.to_f / total * 100).round(1)}%)"
    puts "Failed: #{failed} (#{(failed.to_f / total * 100).round(1)}%)"
    puts "Banned: #{banned} (#{(banned.to_f / total * 100).round(1)}%)"
    puts "Revoked: #{revoked} (#{(revoked.to_f / total * 100).round(1)}%)"
    puts ''

    puts '🔧 Session Statistics'
    puts '=' * 25
    session_manager = Telegram::SessionManager.instance
    session_stats = session_manager.session_stats

    puts "Total Sessions: #{session_stats[:total]}"
    puts "Active Sessions: #{session_stats[:active]}"
    puts "Connected Sessions: #{session_stats[:connected]}"
    puts "Authorized Sessions: #{session_stats[:authorized]}"
  end
end
