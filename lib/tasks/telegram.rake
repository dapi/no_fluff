# Rake задачи для управления Telegram ботом
namespace :telegram do
  desc 'Set bot commands from source code'
  task set_commands: :environment do
    puts '🔧 Установка команд Telegram бота...'
    puts '=' * 50

    manager = Telegram::CommandsManager.new

    # Показываем найденные команды
    puts '📋 Найденные команды:'
    puts manager.format_user_commands_for_display
    puts

    if ENV['DRY_RUN'] == 'true'
      puts '🔍 DRY RUN: Команды не будут установлены'
      puts "📊 Всего команд: #{manager.all_commands.count}"
      exit 0
    end

    # Устанавливаем команды
    puts '📤 Установка команд в Telegram API...'
    result = manager.set_commands!

    if result[:success]
      puts "✅ #{result[:message]}"
      puts "📊 Установлено команд: #{result[:commands_count]}"
    else
      puts "❌ #{result[:message]}"
      if result[:errors].any?
        puts '🔍 Ошибки:'
        result[:errors].each { |error| puts "  • #{error}" }
      end
      exit 1
    end
  end

  desc 'Show current bot commands'
  task show_commands: :environment do
    puts '📋 Текущие команды бота:'
    puts '=' * 50

    manager = Telegram::CommandsManager.new

    # Показываем локальные команды
    puts '🔍 Локальные команды:'
    puts manager.format_user_commands_for_display
    puts

    # Показываем команды из API
    puts '🌐 Команды из Telegram API:'
    current_commands = manager.current_commands
    if current_commands.any?
      current_commands.each do |cmd|
        puts "📱 /#{cmd['command']} - #{cmd['description']}"
      end
      puts
      puts "📊 Всего команд в API: #{current_commands.count}"
    else
      puts '📭 Команды не найдены в API'
    end

    # Проверяем, нужно ли обновление
    if manager.commands_outdated?
      puts '⚠️ Команды устарели и требуют обновления'
      puts "💡 Выполните 'rake telegram:set_commands' для обновления"
    else
      puts '✅ Команды актуальны'
    end
  end

  desc 'Show all commands including admin commands'
  task show_all_commands: :environment do
    puts '📋 Все команды бота (включая административные):'
    puts '=' * 60

    manager = Telegram::CommandsManager.new
    puts manager.format_all_commands_for_display
  end

  desc 'Sync commands if outdated'
  task sync_commands: :environment do
    puts '🔄 Проверка и синхронизация команд бота...'
    puts '=' * 50

    manager = Telegram::CommandsManager.new

    if manager.commands_outdated?
      puts '⚠️ Команды устарели, выполняю обновление...'
      result = manager.set_commands!

      if result[:success]
        puts "✅ #{result[:message]}"
      else
        puts "❌ #{result[:message]}"
        exit 1
      end
    else
      puts '✅ Команды актуальны, обновление не требуется'
    end
  end

  desc 'Validate commands format'
  task validate_commands: :environment do
    puts '🔍 Валидация команд бота...'
    puts '=' * 50

    manager = Telegram::CommandsManager.new
    commands = manager.all_commands

    validation_errors = manager.validate_commands(commands)

    if validation_errors.empty?
      puts '✅ Все команды прошли валидацию'
      puts "📊 Проверено команд: #{commands.count}"
    else
      puts '❌ Найдены ошибки валидации:'
      validation_errors.each { |error| puts "  • #{error}" }
      exit 1
    end
  end

  desc 'Set webhook for bot'
  task set_webhook: :environment do
    puts '🔧 Установка webhook для Telegram бота...'
    puts '=' * 50

    webhook_url = ENV['WEBHOOK_URL'] || Rails.application.credentials.telegram&.dig(:webhook_url)

    unless webhook_url
      puts '❌ URL вебхука не указан'
      puts '💡 Установите переменную окружения WEBHOOK_URL или добавьте webhook_url в credentials'
      exit 1
    end

    bot = Telegram.bot
    result = bot.set_webhook(url: webhook_url)

    if result['ok']
      puts '✅ Webhook успешно установлен'
      puts "🌐 URL: #{webhook_url}"
      puts "🔑 Токен: #{bot.token[0..10]}..."
    else
      puts "❌ Ошибка установки webhook: #{result['description']}"
      exit 1
    end
  end

  desc 'Get bot info'
  task bot_info: :environment do
    puts 'ℹ️ Информация о боте:'
    puts '=' * 50

    bot = Telegram.bot
    result = bot.get_me

    if result['ok']
      info = result['result']
      puts "🤖 Имя: #{info['first_name']}"
      puts "👤 Username: @#{info['username']}" if info['username']
      puts "🆔 ID: #{info['id']}"
      puts "ℹ️ Может получать сообщения: #{info['can_read_all_group_messages'] ? 'Да' : 'Нет'}"
      puts "👥 Поддерживает inline режим: #{info['supports_inline_queries'] ? 'Да' : 'Нет'}"
    else
      puts "❌ Ошибка получения информации: #{result['description']}"
      exit 1
    end
  end

  # Комплексная задача для первоначальной настройки
  desc 'Setup bot (webhook + commands)'
  task setup: :environment do
    puts '🚀 Первоначальная настройка Telegram бота...'
    puts '=' * 50

    # 1. Проверка информации о боте
    puts '1️⃣ Проверка информации о боте...'
    Rake::Task['telegram:bot_info'].invoke
    puts

    # 2. Установка команд
    puts '2️⃣ Установка команд...'
    Rake::Task['telegram:set_commands'].invoke
    puts

    # 3. Установка webhook если указан URL
    if ENV['WEBHOOK_URL'] || Rails.application.credentials.telegram&.dig(:webhook_url)
      puts '3️⃣ Установка webhook...'
      Rake::Task['telegram:set_webhook'].invoke
    else
      puts '3️⃣ Webhook не указан, пропускаем'
    end

    puts
    puts '🎉 Настройка завершена!'
    puts '💡 Бот готов к работе'
  end
end
