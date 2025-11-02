# frozen_string_literal: true

# BaseTestHelper - унифицированные хелперы для базовых тестовых паттернов
# Позволяет сократить дублирование кода в тестах через параметризацию

module BaseTestHelper
  extend ActiveSupport::Concern

  class_methods do
    # Генерирует базовые тесты для фикстур
    # @param model_class [Class] класс модели
    # @param fixture_name [Symbol] имя фикстуры (по умолчанию :one)
    def test_fixture_basics(model_class, fixture_name = :one)
      test "should load #{model_class.name.underscore} fixture" do
        record = send(model_class.name.underscore.pluralize.to_sym, fixture_name)
        assert_not_nil record, "#{model_class.name} fixture should be loaded"
      end

      test "loaded #{model_class.name.underscore} fixture should be valid" do
        record = send(model_class.name.underscore.pluralize.to_sym, fixture_name)
        assert record.valid?, "#{model_class.name} fixture should be valid"
      end
    end

    # Генерирует тест базовой валидации
    # @param model_class [Class] класс модели
    # @param valid_attributes [Hash] валидные атрибуты для создания
    def test_basic_validity(model_class, valid_attributes)
      test 'should be valid with valid attributes' do
        instance = model_class.new(valid_attributes)
        assert instance.valid?, "#{model_class.name} should be valid with valid attributes"
      end
    end

    # ===== ЗАПРЕЩЕНО: Не тестировать валидации моделей =====
    # Валидации - ответственность Rails framework, не требуют дублирования в тестах
    # Вместо этого тестируйте бизнес-логику, ассоциации, scope и кастомные методы

    # Генерирует тесты ассоциаций
    # @param model_class [Class] класс модели
    # @param association_config [Hash] конфигурация ассоциаций
    def test_model_associations(model_class, association_config)
      test 'should have correct associations' do
        # Используем первую запись из фикстур или создаем новую
        instance = model_class.first || create_test_instance(model_class)

        association_config.each do |association_type, association_names|
          Array(association_names).each do |association_name|
            assert_respond_to instance, association_name,
              "#{model_class.name} should respond to #{association_name}"
          end
        end
      end
    end

    # Генерирует тесты для enum полей
    # @param model_class [Class] класс модели
    # @param enum_definitions [Hash] определения enum полей
    def test_enum_functionality(model_class, enum_definitions)
      test 'should have and work with all enum types' do
        instance = model_class.first || create_test_instance(model_class)

        enum_definitions.each do |enum_name, enum_values|
          # Проверяем наличие самого enum
          assert_respond_to instance, enum_name, "Should have #{enum_name} enum"

          # Проверяем наличие query методов для всех значений
          enum_values.each do |enum_value|
            query_method = "#{enum_name}_#{enum_value}?"
            assert_respond_to instance, query_method, "Should have #{query_method} query method"
          end

          # Проверяем работу с enum значениями (только первое и последнее для экономии)
          test_values = [ enum_values.first, enum_values.last ].uniq
          test_values.each do |enum_value|
            # Устанавливаем значение
            instance.send("#{enum_name}=", enum_value.to_sym)

            # Проверяем query метод
            query_method = "#{enum_name}_#{enum_value}?"
            assert instance.send(query_method),
              "Should return true for #{enum_value} in #{enum_name}"

            # Проверяем сохраненное значение
            assert_equal enum_value, instance.send(enum_name),
              "Should store #{enum_value} in #{enum_name}"
          end
        end
      end
    end

    # Генерирует тесты для scope
    # @param model_class [Class] класс модели
    # @param scope_tests [Array] массив тестов для scope
    def test_model_scopes(model_class, scope_tests)
      scope_tests.each do |scope_test_config|
        scope_name = scope_test_config[:name]
        setup_data = scope_test_config[:setup_data]
        expectations = scope_test_config[:expectations]

        test "#{scope_name} scope should work correctly" do
          # Выполняем настройку данных через безопасный метод
          setup_scope_test_data(setup_data) if setup_data

          # Получаем результаты через scope
          results = model_class.send(scope_name)

          # Проверяем ожидания
          expectations.each do |expectation|
            case expectation[:type]
            when :includes
              assert_includes results, expectation[:record],
                "#{scope_name} should include #{expectation[:record].class.name}"
            when :excludes
              assert_not_includes results, expectation[:record],
                "#{scope_name} should not include #{expectation[:record].class.name}"
            when :count
              assert_equal expectation[:count], results.count,
                "#{scope_name} should return #{expectation[:count]} records"
            when :ordered
              expected_order = expectation[:order].map(&:id)
              actual_order = results.map(&:id)
              assert_equal expected_order, actual_order,
                "#{scope_name} should return records in correct order"
            end
          end
        end
      end
    end
  end

  private

  # Создает тестовый экземпляр модели
  # @param model_class [Class] класс модели
  # @return [ActiveRecord::Base] экземпляр модели
  def create_test_instance(model_class)
    # Пытаемся использовать фикстуру, если доступна
    fixture_name = model_class.name.underscore.pluralize.to_sym
    if respond_to?(fixture_name)
      record = send(fixture_name, :one)
      return record if record
    end

    # Если фикстуры нет, создаем минимально валидную запись
    case model_class.name
    when 'TelegramUser'
      TelegramUser.new(username: 'test_user', timezone: 'UTC', language_code: 'en')
    when 'Channel'
      Channel.new(telegram_id: '123456789', username: 'test_channel')
    when 'Subscription'
      Subscription.new(
        telegram_user: TelegramUser.first || TelegramUser.create!(username: 'test_user', timezone: 'UTC', language_code: 'en'),
        channel: Channel.first || Channel.create!(telegram_id: '123456789', username: 'test_channel')
      )
    else
      model_class.new
    end
  end

  # Безопасная настройка данных для тестов scope
  # @param setup_data [Hash] данные для настройки
  def setup_scope_test_data(setup_data)
    setup_data.each do |model_name, records_config|
      model_class = model_name.to_s.camelize.constantize

      records_config.each do |record_config|
        attributes = record_config[:attributes]

        if record_config[:find_or_create]
          # Ищем или создаем запись
          record = model_class.find_by(attributes)
          record ||= model_class.create!(attributes)
        else
          # Создаем новую запись
          record = model_class.create!(attributes)
        end

        # Дополнительные обновления если нужно
        if record_config[:updates]
          record.update!(record_config[:updates])
        end
      end
    end
  end
end
