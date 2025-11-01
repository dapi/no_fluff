require 'test_helper'

module Telegram
  class CommandsScannerTest < ActiveSupport::TestCase
    def setup
      @scanner = CommandsScanner.new
    end

    test 'should identify command methods' do
      assert @scanner.command_method?('start!')
      assert @scanner.command_method?('help!')
      assert @scanner.command_method?('settings!')
      assert_not @scanner.command_method?('message')
      assert_not @scanner.command_method?('callback_query')
      assert_not @scanner.command_method?('_private_method!')
    end

    test 'should scan main controller commands' do
      commands = @scanner.scan_commands(exclude_admin: false)

      # Проверяем наличие основных команд
      command_names = commands.map { |cmd| cmd[:command] }
      assert_includes command_names, 'start'
      assert_includes command_names, 'help'
      assert_includes command_names, 'settings'
      assert_includes command_names, 'add'
      assert_includes command_names, 'remove'
    end

    test 'should scan concerns commands' do
      commands = @scanner.scan_commands(exclude_admin: false)

      # Проверяем команды из concerns
      command_names = commands.map { |cmd| cmd[:command] }
      assert_includes command_names, 'list' # из SubscriptionCommands
      assert_includes command_names, 'debug' # из основного контроллера
      assert_includes command_names, 'channels' # из AdminCommands
    end

    test 'should identify admin commands' do
      commands = @scanner.scan_commands(exclude_admin: false)

      debug_command = commands.find { |cmd| cmd[:command] == 'debug' }
      assert debug_command[:admin_only]

      channels_command = commands.find { |cmd| cmd[:command] == 'channels' }
      assert channels_command[:admin_only]

      start_command = commands.find { |cmd| cmd[:command] == 'start' }
      assert_not start_command[:admin_only]
    end

    test 'should exclude admin commands when requested' do
      all_commands = @scanner.scan_commands(exclude_admin: false)
      user_commands = @scanner.scan_commands(exclude_admin: true)

      assert user_commands.count < all_commands.count

      admin_command_names = all_commands.select { |cmd| cmd[:admin_only] }.map { |cmd| cmd[:command] }
      user_command_names = user_commands.map { |cmd| cmd[:command] }

      admin_command_names.each do |admin_cmd|
        assert_not_includes user_command_names, admin_cmd
      end
    end

    test 'should get command descriptions from I18n' do
      # Stub all I18n.t calls to avoid unexpected invocations
      I18n.stubs(:t).returns('Test description')

      commands = @scanner.scan_commands
      start_command = commands.find { |cmd| cmd[:command] == 'start' }

      assert_not_nil start_command
      assert_equal 'start', start_command[:command]
      assert_equal 'Test description', start_command[:description]
    end

    test 'should generate default descriptions for missing translations' do
      I18n.stubs(:t).with('telegram_bot.commands.unknown_command', default: 'Unknown command').returns('translation missing')

      # Добавляем тестовую команду напрямую
      @scanner.instance_variable_get(:@commands)['unknown_command'] = {
        command: 'unknown_command',
        description: @scanner.send(:generate_default_description, 'unknown_command'),
        source: 'TestClass',
        admin_only: false
      }

      commands = @scanner.send(:format_commands)
      unknown_command = commands.find { |cmd| cmd[:command] == 'unknown_command' }

      assert_equal 'Unknown command', unknown_command[:description]
    end

    test 'should format commands for API' do
      commands = @scanner.scan_commands

      # Проверяем структуру
      commands.each do |cmd|
        assert cmd.key?(:command)
        assert cmd.key?(:description)
        assert_kind_of String, cmd[:command]
        assert_kind_of String, cmd[:description]
        assert_not cmd[:command].empty?
        assert_not cmd[:description].empty?
      end
    end

    test 'should sort commands alphabetically' do
      commands = @scanner.scan_commands
      command_names = commands.map { |cmd| cmd[:command] }

      assert_equal command_names.sort, command_names
    end

    test 'should handle concerns correctly' do
      # Проверяем, что сканер находит команды из модулей
      commands = @scanner.scan_commands(exclude_admin: false)
      command_names = commands.map { |cmd| cmd[:command] }

      # Команды из SubscriptionCommands
      assert_includes command_names, 'list'

      # Команды из AdminCommands
      assert_includes command_names, 'channels'

      # Команды из SettingsCommands
      assert_includes command_names, 'settings'
    end

    test 'should provide separate methods for different command types' do
      all_commands = @scanner.all_commands
      user_commands = @scanner.user_commands
      admin_commands = @scanner.admin_commands

      assert all_commands.count >= user_commands.count
      assert admin_commands.count >= 1

      # Проверяем, что все команды - это объединение пользовательских и админских
      all_command_names = all_commands.map { |cmd| cmd[:command] }.sort
      combined_names = (user_commands + admin_commands).map { |cmd| cmd[:command] }.sort

      assert_equal all_command_names, combined_names
    end
  end
end
