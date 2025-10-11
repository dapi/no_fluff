# Сервис для сканирования и определения команд Telegram бота
# Автоматически находит все методы команд в контроллерах и concerns
module Telegram
  class CommandsScanner
    # Основной контроллер бота
    MAIN_CONTROLLER = TelegramWebhookController

    def initialize
      @commands = {}
    end

    # Сканирует все команды и возвращает список
    def scan_commands(exclude_admin: true)
      scan_main_controller
      scan_concerns
      commands = format_commands
      exclude_admin ? filter_admin_commands(commands) : commands
    end

    # Возвращает список всех найденных команд (включая админские)
    def all_commands
      scan_commands(exclude_admin: false)
    end

    # Возвращает только пользовательские команды
    def user_commands
      scan_commands(exclude_admin: true)
    end

    # Возвращает только административные команды
    def admin_commands
      all_commands.select { |cmd| cmd[:admin_only] }
    end

    # Фильтрует административные команды
    def filter_admin_commands(commands)
      commands.reject { |cmd| cmd[:admin_only] }
    end

    # Проверяет, является ли метод командой (заканчивается на !)
    def command_method?(method_name)
      method_name.to_s.end_with?('!') && !method_name.to_s.start_with?('_')
    end

    private

    # Сканирует основной контроллер
    def scan_main_controller
      scan_class_methods(MAIN_CONTROLLER)
    end

    # Сканирует все включенные concerns
    def scan_concerns
      MAIN_CONTROLLER.included_modules.each do |mod|
        next unless mod.name&.start_with?('Telegram::')

        scan_class_methods(mod)
      end
    end

    # Сканирует методы класса/модуля
    def scan_class_methods(klass)
      klass.instance_methods(false).each do |method_name|
        next unless command_method?(method_name)

        command_name = method_name.to_s.chomp('!')
        add_command(command_name, klass)
      end
    end

    # Добавляет команду в список
    def add_command(command_name, source_class)
      @commands[command_name] ||= {
        command: command_name,
        description: get_command_description(command_name),
        source: source_class.name,
        admin_only: admin_command?(command_name)
      }
    end

    # Проверяет, является ли команда административной
    def admin_command?(command_name)
      %w[debug channels set_commands].include?(command_name.to_s)
    end

    # Исключает административные команды из общего списка
    def exclude_admin_commands?
      true
    end

    # Получает описание команды из локализации
    def get_command_description(command_name)
      I18n.t("telegram_bot.commands.#{command_name}", default: generate_default_description(command_name))
    rescue
      generate_default_description(command_name)
    end

    # Генерирует описание по умолчанию, если нет в локали
    def generate_default_description(command_name)
      case command_name.to_s
      when 'start'
        'Начать работу с ботом'
      when 'help'
        'Показать справку'
      when 'settings'
        'Настройки бота'
      when 'add'
        'Добавить канал'
      when 'remove'
        'Удалить канал'
      when 'list'
        'Показать мои подписки'
      when 'debug'
        'Режим отладки (админам)'
      when 'channels'
        'Список всех каналов (админам)'
      when 'set_commands'
        'Установить команды бота (админам)'
      else
        command_name.to_s.humanize
      end
    end

    # Форматирует команды для API
    def format_commands
      @commands.values.map do |cmd|
        {
          command: cmd[:command],
          description: cmd[:description]
        }
      end.sort_by { |cmd| cmd[:command] }
    end
  end
end
