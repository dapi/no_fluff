# frozen_string_literal: true

# Rake задачи для управления спецификациями
namespace :specs do
  DOCS_SPECS_DIR = 'docs/Specs'.freeze
  DOCS_IMPL_DIR = 'docs/Implementation'.freeze
  TEMPLATES_DIR = 'docs/.templates'.freeze

  desc 'Создать новую спецификацию'
  task :generate, [ :feature_name ] => :environment do |_t, args|
    feature_name = args[:feature_name]

    unless feature_name
      puts '❌ Ошибка: Укажите название функции'
      puts 'Пример: rake specs:generate[user_analytics]'
      exit 1
    end

    puts "📝 Создание спецификации для: #{feature_name}"
    puts '=' * 50

    # Генерируем номер спецификации
    spec_number = generate_spec_number
    spec_filename = "#{spec_number}_#{feature_name.gsub(/[^a-zA-Z0-9]/, '_')}_Specification.md"
    spec_path = File.join(DOCS_SPECS_DIR, spec_filename)

    # Проверяем, что файл не существует
    if File.exist?(spec_path)
      puts "❌ Спецификация уже существует: #{spec_path}"
      exit 1
    end

    # Создаем директорию если нужно
    FileUtils.mkdir_p(DOCS_SPECS_DIR)

    # Получаем шаблон спецификации
    template_content = get_spec_template(feature_name, spec_number)

    # Записываем файл
    File.write(spec_path, template_content)

    puts "✅ Спецификация создана: #{spec_path}"
    puts '📋 Не забудьте:'
    puts '   1. Заполнить все разделы спецификации'
    puts '   2. Установить статус: draft'
    puts "   3. Создать план реализации: rake specs:create_plan[#{spec_number}]"
  end

  desc 'Обновить статус спецификации'
  task :update_status, [ :spec_number, :status ] => :environment do |_t, args|
    spec_number = args[:spec_number]
    new_status = args[:status]

    unless spec_number && new_status
      puts '❌ Ошибка: Укажите номер спецификации и новый статус'
      puts 'Пример: rake specs:update_status[048,approved]'
      exit 1
    end

    valid_statuses = %w[draft business_review need_plan tech_review approved in_progress testing implemented delivered]
    unless valid_statuses.include?(new_status)
      puts "❌ Неверный статус: #{new_status}"
      puts "Доступные статусы: #{valid_statuses.join(', ')}"
      exit 1
    end

    spec_file = find_spec_file(spec_number)
    unless spec_file
      puts "❌ Спецификация не найдена: #{spec_number}"
      exit 1
    end

    update_spec_status(spec_file, new_status)
    puts "✅ Статус обновлен: #{spec_file} -> #{new_status}"
  end

  desc 'Массово обновить статус для старых спецификаций'
  task :legacy_status, [ :status ] => :environment do |_t, args|
    new_status = args[:status] || 'delivered'

    valid_statuses = %w[draft business_review need_plan tech_review approved in_progress testing implemented delivered]
    unless valid_statuses.include?(new_status)
      puts "❌ Неверный статус: #{new_status}"
      puts "Доступные статусы: #{valid_statuses.join(', ')}"
      exit 1
    end

    puts "🔄 Массовое обновление статуса для старых спецификаций: #{new_status}"
    puts '=' * 60

    spec_files = Dir.glob(File.join(DOCS_SPECS_DIR, '*.md'))
    updated_count = 0
    skipped_count = 0

    spec_files.sort.each do |file|
      content = File.read(file, encoding: 'UTF-8')

      # Проверяем, есть ли уже статус
      status_match = content.match(/\*\*Статус:\*\*\s*([a-z_]+)/)

      if status_match
        current_status = status_match[1]
        puts "⏭️  Пропуск: #{File.basename(file)} - уже имеет статус '#{current_status}'"
        skipped_count += 1
        next
      end

      # Добавляем мета-информацию в начало файла
      basename = File.basename(file, '.md')
      spec_number = basename.match(/^(\d+)/)[1]
      title = basename.gsub(/^\d+_/, '').gsub(/_Specification/, '').gsub(/_/, ' ').split.map(&:capitalize).join(' ')

      new_meta = <<~MARKDOWN
        ## Мета информация

        - **Номер:** #{spec_number}
        - **Название:** #{title}
        - **Автор:**
        - **Создана:** #{Time.now.strftime('%Y-%m-%d')}
        - **Статус:** #{new_status}
        - **Связанные спецификации:**

      MARKDOWN

      # Вставляем мета-информацию после заголовка
      if content.match(/^#\s*Спецификация\s+\d+:/)
        updated_content = content.sub(
          /^#\s*Спецификация\s+\d+:.*$/,
          "\\&\n\n#{new_meta}"
        )
      else
        # Если нет стандартного заголовка, добавляем в начало
        updated_content = "# Спецификация #{spec_number}: #{title}\n\n#{new_meta}\n\n#{content}"
      end

      File.write(file, updated_content)
      puts "✅ Обновлена: #{File.basename(file)} -> #{new_status}"
      updated_count += 1
    end

    puts "\n" + '=' * 60
    puts '📊 Итоги массового обновления:'
    puts "   Обновлено спецификаций: #{updated_count}"
    puts "   Пропущено (с уже имеющимся статусом): #{skipped_count}"
    puts "   Общий статус: #{new_status}"
  end

  desc 'Создать план реализации'
  task :create_plan, [ :spec_number ] => :environment do |_t, args|
    spec_number = args[:spec_number]

    unless spec_number
      puts '❌ Ошибка: Укажите номер спецификации'
      puts 'Пример: rake specs:create_plan[048]'
      exit 1
    end

    spec_file = find_spec_file(spec_number)
    unless spec_file
      puts "❌ Спецификация не найдена: #{spec_number}"
      exit 1
    end

    plan_filename = "Spec_#{spec_number}_#{extract_spec_title(spec_file)}_Implementation.md"
    plan_path = File.join(DOCS_IMPL_DIR, plan_filename)

    if File.exist?(plan_path)
      puts "❌ План реализации уже существует: #{plan_path}"
      exit 1
    end

    # Создаем директорию если нужно
    FileUtils.mkdir_p(DOCS_IMPL_DIR)

    # Генерируем план
    plan_content = generate_implementation_plan(spec_file, spec_number)

    # Записываем файл
    File.write(plan_path, plan_content)

    puts "✅ План реализации создан: #{plan_path}"
    puts '📋 Не забудьте:'
    puts '   1. Заполнить все этапы плана'
    puts "   2. Обновить статус спецификации: rake specs:update_status[#{spec_number},need_plan]"
  end

  desc 'Проверить качество спецификации'
  task :validate, [ :spec_number ] => :environment do |_t, args|
    spec_number = args[:spec_number]

    unless spec_number
      puts '❌ Ошибка: Укажите номер спецификации'
      puts 'Пример: rake specs:validate[048]'
      exit 1
    end

    spec_file = find_spec_file(spec_number)
    unless spec_file
      puts "❌ Спецификация не найдена: #{spec_number}"
      exit 1
    end

    puts "🔍 Проверка спецификации: #{spec_file}"
    puts '=' * 50

    validation_result = validate_spec(spec_file)

    # Выходим с ошибкой только если валидация не прошла и спецификация не в статусе draft
    unless validation_result
      puts "\n❌ Валидация не пройдена. Исправьте ошибки перед коммитом."
      exit 1
    end

    puts "\n✅ Валидация завершена"
  end

  desc 'Показать все спецификации с статусами'
  task list: :environment do
    puts '📋 Список всех спецификаций:'
    puts '=' * 50

    spec_files = Dir.glob(File.join(DOCS_SPECS_DIR, '*.md'))

    if spec_files.empty?
      puts '📭 Спецификации не найдены'
      exit 0
    end

    spec_files.sort.each do |file|
      spec_info = extract_spec_info(file)
      status = spec_info[:status] || '❌ нет статуса'
      title = spec_info[:title] || File.basename(file, '.md')

      puts "#{spec_info[:number]}: #{title}"
      puts "   Статус: #{status}"
      puts "   Файл: #{file}"
      puts
    end
  end

  desc 'Валидировать все спецификации'
  task validate_all: :environment do
    puts '🔍 Валидация всех спецификаций'
    puts '=' * 50

    spec_files = Dir.glob(File.join(DOCS_SPECS_DIR, '*.md'))

    if spec_files.empty?
      puts '📭 Спецификации не найдены'
      exit 0
    end

    all_passed = true
    draft_specs_with_issues = []

    spec_files.sort.each do |file|
      basename = File.basename(file, '.md')
      spec_number = basename.match(/^(\d+)/)[1]

      puts "\n🔍 Проверка спецификации: #{basename}"

      validation_result = validate_spec(file)

      unless validation_result
        all_passed = false
      end

      # Проверяем статус для дополнительной информации
      content = File.read(file, encoding: 'UTF-8')
      status_match = content.match(/\*\*Статус:\*\*\s*([a-z_]+)/)
      status = status_match ? status_match[1] : 'no_status'

      if status == 'draft' && !validation_result
        draft_specs_with_issues << spec_number
      end
    end

    puts "\n" + '=' * 50
    puts '📊 Итоги валидации:'
    puts "   Всего спецификаций: #{spec_files.count}"
    puts "   Прошли валидацию: #{all_passed ? 'Все' : 'Не все'}"

    if draft_specs_with_issues.any?
      puts "\n📝 Черновики с замечаниями (не блокируют коммит):"
      draft_specs_with_issues.each { |spec| puts "   • Спецификация #{spec}" }
    end

    unless all_passed
      puts "\n❌ Некоторые спецификации не прошли валидацию."
      puts '   Черновики можно коммитить с ошибками.'
      puts '   Остальные спецификации нужно исправить перед коммитом.'
      exit 1
    end

    puts "\n✅ Все спецификации прошли валидацию"
  end

  desc 'Сгенерировать отчет по качеству'
  task quality_report: :environment do
    puts '📊 Отчет по качеству спецификаций'
    puts '=' * 50

    spec_files = Dir.glob(File.join(DOCS_SPECS_DIR, '*.md'))
    impl_files = Dir.glob(File.join(DOCS_IMPL_DIR, '*.md'))

    total_specs = spec_files.count
    total_impl = impl_files.count

    puts '📈 Общая статистика:'
    puts "   Спецификаций: #{total_specs}"
    puts "   Планах реализации: #{total_impl}"

    if total_specs > 0
      # Считаем статусы
      status_counts = Hash.new(0)
      spec_files.each do |file|
        info = extract_spec_info(file)
        status = info[:status] || 'no_status'
        status_counts[status] += 1
      end

      puts "\n📊 Распределение по статусам:"
      status_counts.each do |status, count|
        percentage = (count.to_f / total_specs * 100).round(1)
        puts "   #{status}: #{count} (#{percentage}%)"
      end

      # Проверяем проблемы
      puts "\n⚠️  Обнаруженные проблемы:"
      problems = []

      if status_counts['draft'] > 2
        problems << "Много черновиков (#{status_counts['draft']})"
      end

      if status_counts['no_status'] > 0
        problems << "Спецификации без статуса (#{status_counts['no_status']})"
      end

      if total_impl < total_specs * 0.8
        problems << 'Меньше 80% спецификаций имеют планы реализации'
      end

      if problems.empty?
        puts '   ✅ Проблем не обнаружено'
      else
        problems.each { |problem| puts "   ⚠️  #{problem}" }
      end
    end

    puts "\n📝 Рекомендации:"
    puts '   • Регулярно обновляйте статусы спецификаций'
    puts '   • Создавайте планы реализации для утвержденных спецификаций'
    puts '   • Проводите валидацию качества спецификаций'
  end

  private

  def generate_spec_number
    existing_specs = Dir.glob(File.join(DOCS_SPECS_DIR, '*.md'))
    max_number = existing_specs.map do |file|
      match = File.basename(file, '.md').match(/^(\d+)/)
      match ? match[1].to_i : 0
    end.max || 0

    format('%03d', max_number + 1)
  end

  def get_spec_template(feature_name, spec_number)
    title = feature_name.gsub(/_/, ' ').split.map(&:capitalize).join(' ')

    <<~MARKDOWN
      # Спецификация #{spec_number}: #{title}

      ## Мета информация

      - **Номер:** #{spec_number}
      - **Название:** #{title}
      - **Автор:**
      - **Создана:** #{Time.now.strftime('%Y-%m-%d')}
      - **Статус:** draft
      - **Связанные спецификации:**

      ## 1. Обзор и цель

      ### 1.1. Краткое описание
      <!-- Краткое описание функциональности -->

      ### 1.2. Цель
      <!-- Какую бизнес-цель достигаем -->

      ### 1.3. Затрагиваемые компоненты
      <!-- Какие части системы затронет -->

      ## 2. Требования

      ### 2.1. Функциональные требования
      <!-- Что система должна делать -->

      ### 2.2. Нефункциональные требования
      <!-- Как система должна работать (производительность, безопасность и т.д.) -->

      ### 2.3. Ограничения и допущения
      <!-- Технические и бизнес ограничения -->

      ## 3. Пользовательские сценарии

      ### 3.1. Основные сценарии
      <!-- Основные пути использования -->

      ### 3.2. Альтернативные сценарии
      <!-- Пограничные случаи и исключения -->

      ### 3.3. Пользовательский интерфейс
      <!-- Описание интерфейса если применимо -->

      ## 4. Техническая реализация

      ### 4.1. Архитектурные изменения
      <!-- Изменения в архитектуре системы -->

      ### 4.2. Модели данных
      <!-- Новые или измененные модели -->

      ### 4.3. API эндпоинты
      <!-- Новые или измененные API -->

      ### 4.4. Интеграции
      <!-- Внешние системы и сервисы -->

      ## 5. Тестирование

      ### 5.1. Требования к тестированию
      <!-- Какие тесты необходимы -->

      ### 5.2. Тестовые данные
      <!-- Необходимые тестовые данные -->

      ### 5.3. Критерии приемки
      <!-- Когда считать функцию реализованной -->

      ## 6. Риски и зависимости

      ### 6.1. Технические риски
      <!-- Возможные технические проблемы -->

      ### 6.2. Бизнес риски
      <!-- Бизнес риски и их митигация -->

      ### 6.3. Зависимости
      <!-- Зависимости от других задач и систем -->

      ## 7. Внедрение

      ### 7.1. Этапы внедрения
      <!-- План внедрения -->

      ### 7.2. Требования к миграции
      <!-- Если необходима миграция данных -->

      ### 7.3. Откат изменений
      <!-- Как откатить изменения -->

      ## 8. Метрики и мониторинг

      ### 8.1. Ключевые метрики
      <!-- Метрики успеха -->

      ### 8.2. Мониторинг
      <!-- Что мониторить в продакшене -->

      ## 9. Документация

      ### 9.1. Пользовательская документация
      <!-- Необходимая документация -->

      ### 9.2. Техническая документация
      <!-- Необходимая техническая документация -->

      ## 10. История изменений

      | Дата | Версия | Изменение | Автор |
      |------|--------|-----------|--------|
      | #{Time.now.strftime('%Y-%m-%d')} | 1.0 | Initial version | |

    MARKDOWN
  end

  def find_spec_file(spec_number)
    pattern = File.join(DOCS_SPECS_DIR, "#{spec_number}_*.md")
    Dir.glob(pattern).first
  end

  def extract_spec_title(spec_file)
    basename = File.basename(spec_file, '.md')
    match = basename.match(/^\d+_(.+)_Specification$/)
    return 'Unknown' unless match

    match[1].gsub(/_/, ' ').split.map(&:capitalize).join(' ')
  end

  def extract_spec_info(spec_file)
    content = File.read(spec_file, encoding: 'UTF-8')

    # Извлекаем номер
    number_match = content.match(/-\s*\*\*Номер:\s*\*\*\s*(\d+)/)
    number = number_match ? number_match[1] : File.basename(spec_file, '.md').match(/^(\d+)/)[1]

    # Извлекаем заголовок
    title_match = content.match(/^#\s*Спецификация\s+\d+:\s*(.+)$/)
    title = title_match ? title_match[1] : File.basename(spec_file, '.md')

    # Извлекаем статус
    status_match = content.match(/-\s*\*\*Статус:\s*\*\*\s*([a-z_]+)/)
    status = status_match ? status_match[1] : 'no_status'

    {
      number: number,
      title: title,
      status: status,
      file: spec_file
    }
  end

  def update_spec_status(spec_file, new_status)
    content = File.read(spec_file, encoding: 'UTF-8')

    # Обновляем статус
    updated_content = content.gsub(
      /-\s*\*\*Статус:\s*\*\*\s*[a-z_]+/,
      "- **Статус:** #{new_status}"
    )

    # Добавляем историю изменений
    history_entry = "| #{Time.now.strftime('%Y-%m-%d')} | Status | Статус изменен на '#{new_status}' | System |"

    if content.include?('## 10. История изменений')
      updated_content = updated_content.gsub(
        /(| #{Time.now.strftime('%Y-%m-%d')} \| Status \| Статус изменен на '[a-z_]+' \| System \|)/,
        history_entry
      )
    else
      updated_content += "\n\n## 10. История изменений\n\n"
      updated_content += "| Дата | Версия | Изменение | Автор |\n"
      updated_content += "|------|--------|-----------|--------|\n"
      updated_content += "#{history_entry}\n"
    end

    File.write(spec_file, updated_content)
  end

  def generate_implementation_plan(spec_file, spec_number)
    spec_info = extract_spec_info(spec_file)
    spec_title = spec_info[:title]

    <<~MARKDOWN
      # План реализации спецификации #{spec_number}: #{spec_title}

      ## Мета информация

      - **Спецификация:** [#{spec_number}_#{spec_title.gsub(/[^a-zA-Z0-9]/, '_')}_Specification.md](../Specs/#{File.basename(spec_file)})
      - **Номер плана:** #{spec_number}
      - **Автор:**
      - **Создан:** #{Time.now.strftime('%Y-%m-%d')}
      - **Статус:** draft
      - **Оценка времени:**

      ## Этапы реализации

      ### Этап 1: Подготовка и анализ
      - [ ] Анализ текущей кодовой базы
      - [ ] Подготовка окружения разработки
      - [ ] Изучение зависимостей и требований

      ### Этап 2: Проектирование
      - [ ] Проектирование архитектуры изменений
      - [ ] Проектирование схемы данных
      - [ ] Проектирование API интерфейсов
      - [ ] Подготовка технической документации

      ### Этап 3: Разработка основного функционала
      - [ ] Создание/модификация моделей данных
      - [ ] Реализация бизнес-логики
      - [ ] Создание API эндпоинтов
      - [ ] Реализация пользовательского интерфейса

      ### Этап 4: Тестирование
      - [ ] Написание unit тестов
      - [ ] Написание integration тестов
      - [ ] Написание E2E тестов
      - [ ] Тестирование производительности

      ### Этап 5: Интеграция и развертывание
      - [ ] Интеграция с существующими системами
      - [ ] Настройка CI/CD пайплайна
      - [ ] Подготовка миграций данных
      - [ ] Развертывание в тестовом окружении

      ### Этап 6: Внедрение
      - [ ] Финальное тестирование
      - [ ] Развертывание в production
      - [ ] Мониторинг после внедрения
      - [ ] Обновление документации

      ## Риски и митигация

      ### Технические риски
      - **Риск:**
      - **Митигация:**

      ### Сроки
      - **Риск:**
      - **Митигация:**

      ## Зависимости

      ### Внешние зависимости
      -

      ### Внутренние зависимости
      -

      ## Критерии готовности

      - [ ] Все тесты проходят успешно
      - [ ] Код проходит code review
      - [ ] Документация обновлена
      - [ ] Производительность соответствует требованиям
      - [ ] Безопасность проверена
      - [ ] Пользовательское приемочное тестирование пройдено

      ## История изменений

      | Дата | Этап | Статус | Комментарий | Автор |
      |------|------|--------|-------------|--------|
      | #{Time.now.strftime('%Y-%m-%d')} | Создание плана | draft | Первоначальная версия плана | System |

    MARKDOWN
  end

  def validate_spec(spec_file)
    content = File.read(spec_file, encoding: 'UTF-8')
    errors = []
    warnings = []

    # Получаем статус спецификации
    status_match = content.match(/\*\*Статус:\*\*\s*([a-z_]+)/)
    status = status_match ? status_match[1] : 'no_status'

    # Определяем, блокируют ли ошибки коммит для этого статуса
    non_blocking_statuses = %w[draft implemented delivered]
    blocking_errors = !non_blocking_statuses.include?(status)

    # Проверяем обязательные секции
    required_sections = [
      '## 1. Обзор и цель',
      '## 2. Требования',
      '## 3. Пользовательские сценарии',
      '## 4. Техническая реализация',
      '## 5. Тестирование',
      '## 6. Риски и зависимости',
      '## 7. Внедрение'
    ]

    required_sections.each do |section|
      unless content.include?(section)
        if status == 'draft'
          warnings << "Отсутствует секция: #{section}"
        elsif status == 'implemented' || status == 'delivered'
          warnings << "Отсутствует секция: #{section} (уже реализовано)"
        else
          errors << "Отсутствует секция: #{section}"
        end
      end
    end

    # Проверяем мета информацию
    meta_fields = [ 'Номер', 'Название', 'Статус' ]
    meta_fields.each do |field|
      unless content.match(/\*\*#{field}:\*\*/)
        warnings << "Отсутствует поле в мета информации: #{field}"
      end
    end

    # Проверяем статус
    if status_match
      valid_statuses = %w[draft business_review need_plan tech_review approved in_progress testing implemented delivered]
      unless valid_statuses.include?(status)
        errors << "Неверный статус: #{status}"
      end
    else
      if status != 'draft'
        errors << 'Отсутствует статус'
      else
        warnings << 'Отсутствует статус'
      end
    end

    # Проверяем качество контента
    if content.length < 2000
      if status == 'implemented' || status == 'delivered'
        warnings << 'Спецификация короткая, но уже реализована'
      else
        warnings << 'Спецификация слишком короткая, возможно недостаточно деталей'
      end
    end

    # Выводим результаты
    if errors.empty? && warnings.empty?
      puts '✅ Спецификация в порядке'
    else
      if errors.any?
        if status == 'draft'
          puts '📝 Замечания для черновика (не блокируют коммит):'
          errors.each { |error| puts "   • #{error}" }
        elsif status == 'implemented' || status == 'delivered'
          puts '📝 Замечания для реализованной спецификации (не блокируют коммит):'
          errors.each { |error| puts "   • #{error}" }
        else
          puts '❌ Ошибки:'
          errors.each { |error| puts "   • #{error}" }
        end
      end

      if warnings.any?
        puts '⚠️  Предупреждения:'
        warnings.each { |warning| puts "   • #{warning}" }
      end
    end

    puts "\n📊 Статистика:"
    puts "   Статус: #{status}"
    puts "   Размер: #{content.length} символов"
    puts "   Ошибки: #{errors.count}"
    puts "   Предупреждения: #{warnings.count}"

    # Для статусов, которые не блокируют коммит, возвращаем true
    if !blocking_errors && errors.any?
      puts "\n✨ Статус '#{status}': ошибки не блокируют коммит"
      return true
    end

    # Для остальных статусов возвращаем false если есть ошибки
    errors.empty?
  end
end
