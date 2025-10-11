require 'test_helper'

module Telegram
  class CommandsManagerTest < ActiveSupport::TestCase
    def setup
      @mock_bot = mock('bot')
      @manager = CommandsManager.new(bot: @mock_bot)
    end

    test 'should initialize with default bot' do
      Telegram.stubs(:bot).returns(mock('default_bot'))
      manager = CommandsManager.new

      assert_not_nil manager.bot
    end

    test 'should get all user commands' do
      commands = @manager.all_commands

      assert_kind_of Array, commands
      commands.each do |cmd|
        assert cmd.key?(:command)
        assert cmd.key?(:description)
        refute cmd[:admin_only]  # все команды должны быть пользовательскими
      end
    end

    test 'should get commands including admin' do
      commands = @manager.commands_with_admin

      assert_kind_of Array, commands
      assert commands.any? { |cmd| cmd[:admin_only] }, 'Should include admin commands'
    end

    test 'should get current commands from API' do
      mock_response = {
        'ok' => true,
        'result' => [
          { 'command' => 'start', 'description' => 'Start the bot' },
          { 'command' => 'help', 'description' => 'Show help' }
        ]
      }

      @mock_bot.expects(:get_my_commands).returns(mock_response)

      current_commands = @manager.current_commands

      assert_equal 2, current_commands.count
      assert_equal 'start', current_commands.first['command']
    end

    test 'should handle API errors gracefully' do
      @mock_bot.expects(:get_my_commands).returns({ 'ok' => false })

      current_commands = @manager.current_commands

      assert_equal [], current_commands
    end

    test 'should detect outdated commands' do
      # Мокируем локальные команды
      @manager.stubs(:all_commands).returns([
        { command: 'start', description: 'Start the bot' },
        { command: 'help', description: 'Show help' }
      ])

      # Мокируем удаленные команды (отличаются от локальных)
      @manager.stubs(:current_commands).returns([
        { 'command' => 'start', 'description' => 'Start the bot' },
        { 'command' => 'settings', 'description' => 'Show settings' }
      ])

      assert @manager.commands_outdated?
    end

    test 'should detect up-to-date commands' do
      commands = [
        { command: 'start', description: 'Start the bot' },
        { command: 'help', description: 'Show help' }
      ]

      remote_commands = [
        { 'command' => 'start', 'description' => 'Start the bot' },
        { 'command' => 'help', 'description' => 'Show help' }
      ]

      @manager.stubs(:all_commands).returns(commands)
      @manager.stubs(:current_commands).returns(remote_commands)

      refute @manager.commands_outdated?
    end

    test 'should set commands successfully' do
      mock_response = { 'ok' => true }
      @mock_bot.expects(:set_my_commands).with(has_entries(commands: is_a(Array))).returns(mock_response)

      @manager.stubs(:all_commands).returns([
        { command: 'start', description: 'Start the bot' }
      ])

      result = @manager.set_commands!

      assert result[:success]
      assert_includes result[:message], 'успешно установлены'
      assert_equal 1, result[:commands_count]
    end

    test 'should handle API errors when setting commands' do
      mock_response = { 'ok' => false, 'description' => 'Bad Request: invalid command' }
      @mock_bot.expects(:set_my_commands).returns(mock_response)

      @manager.stubs(:all_commands).returns([
        { command: 'start', description: 'Start the bot' }
      ])

      result = @manager.set_commands!

      refute result[:success]
      assert_includes result[:message], 'Bad Request: invalid command'
      assert result[:errors].any?
    end

    test 'should handle exceptions when setting commands' do
      @mock_bot.expects(:set_my_commands).raises(StandardError.new('Network error'))

      @manager.stubs(:all_commands).returns([
        { command: 'start', description: 'Start the bot' }
      ])

      result = @manager.set_commands!

      refute result[:success]
      assert_includes result[:message], 'Network error'
      assert result[:errors].any?
    end

    test 'should validate command format' do
      invalid_commands = [
        { command: '', description: 'Empty command' },
        { command: 'Invalid Command!', description: 'Has space and exclamation' },
        { command: 'very_long_command_name_that_exceeds_32_characters_limit', description: 'Too long' },
        { command: 'valid', description: 'x' * 257 }  # Too long description
      ]

      errors = @manager.validate_commands(invalid_commands)

      assert errors.any?
      assert_includes errors.join, 'Invalid command format'
      assert_includes errors.join, 'Command name too long'
      assert_includes errors.join, 'Description too long'
    end

    test 'should validate command count limit' do
      too_many_commands = 101.times.map do |i|
        { command: "cmd#{i}", description: "Command #{i}" }
      end

      errors = @manager.validate_commands(too_many_commands)

      assert errors.any?
      assert_includes errors.join, 'Too many commands'
    end

    test 'should pass validation for valid commands' do
      valid_commands = [
        { command: 'start', description: 'Start the bot' },
        { command: 'help', description: 'Show help information' },
        { command: 'settings', description: 'Configure bot settings' }
      ]

      errors = @manager.validate_commands(valid_commands)

      assert_empty errors
    end

    test 'should format commands for display' do
      commands = [
        { command: 'start', description: 'Start the bot', admin_only: false },
        { command: 'debug', description: 'Debug mode', admin_only: true }
      ]

      formatted = @manager.format_commands_for_display(commands, include_admin: true)

      assert_includes formatted, '📋 Список команд бота'
      assert_includes formatted, '📱 /start - Start the bot'
      assert_includes formatted, '🔐 /debug - Debug mode'
      assert_includes formatted, 'Всего команд: 2'
    end

    test 'should handle empty commands list' do
      @manager.stubs(:all_commands).returns([])

      formatted = @manager.format_user_commands_for_display

      assert_includes formatted, 'Команды не найдены'
    end

    test 'should sync commands when needed' do
      @manager.stubs(:commands_outdated?).returns(true)
      @manager.stubs(:set_commands!).returns(success: true, message: 'Commands set')

      result = @manager.sync_commands_if_needed

      assert result[:success]
    end

    test 'should not sync commands when up-to-date' do
      @manager.stubs(:commands_outdated?).returns(false)

      result = @manager.sync_commands_if_needed

      assert result[:success]
      assert_includes result[:message], 'актуальны'
    end

    test 'should notify Bugsnag on exceptions' do
      @mock_bot.expects(:set_my_commands).raises(StandardError.new('Test error'))
      Bugsnag.expects(:notify).with(is_a(StandardError))

      @manager.stubs(:all_commands).returns([
        { command: 'start', description: 'Start the bot' }
      ])

      @manager.set_commands!
    end

    test 'should provide different formatting methods' do
      @manager.stubs(:all_commands).returns([
        { command: 'start', description: 'Start bot', admin_only: false }
      ])
      @manager.stubs(:commands_with_admin).returns([
        { command: 'start', description: 'Start bot', admin_only: false },
        { command: 'debug', description: 'Debug mode', admin_only: true }
      ])

      user_formatted = @manager.format_user_commands_for_display
      all_formatted = @manager.format_all_commands_for_display

      assert_includes user_formatted, '/start'
      refute_includes user_formatted, '/debug'

      assert_includes all_formatted, '/start'
      assert_includes all_formatted, '/debug'
    end
  end
end
