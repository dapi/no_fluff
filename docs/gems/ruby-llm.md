# RubyLLM Gem Documentation

Unified Ruby API for multiple AI providers (OpenAI, Anthropic, Gemini, Bedrock, OpenRouter, DeepSeek, Ollama, VertexAI, Perplexity, Mistral, GPUStack и OpenAI-совместимые API).

**Версия:** 1.8+ (актуально на сентябрь 2025)
**Лицензия:** MIT
**Документация:** https://rubyllm.com/
**GitHub:** https://github.com/crmne/ruby_llm

## Установка

```ruby
# Gemfile
gem 'ruby_llm', '~> 1.8'
```

## Конфигурация

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  # и другие провайдеры
end
```

## Основные возможности

### 1. Чат (Chat)

```ruby
# Простой чат
chat = RubyLLM.chat
response = chat.ask "Как лучше учить Ruby?"

# Выбор модели
chat = RubyLLM.chat(model: 'gpt-4')
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')

# Контекст сохраняется автоматически
chat.ask "Что такое Ruby?"
chat.ask "А какие его преимущества?" # Модель помнит предыдущий вопрос
```

### 2. Работа с файлами

```ruby
# Анализ изображений
chat.ask "Что на этом изображении?", with: "photo.jpg"

# Работа с PDF
chat.ask "Суммаризируй этот документ", with: "report.pdf"

# Несколько файлов
chat.ask "Сравни эти изображения", with: ["image1.jpg", "image2.jpg"]

# CSV, JSON и другие форматы
chat.ask "Проанализируй данные", with: "data.csv"
```

### 3. Streaming (потоковая передача)

```ruby
chat = RubyLLM.chat
chat.ask "Расскажи длинную историю про Ruby" do |chunk|
  print chunk.content # Выводим токены по мере получения
end
# Метод ask всё равно возвращает полный RubyLLM::Message после завершения
```

### 4. Генерация изображений

```ruby
# Простая генерация
image = RubyLLM.paint "красная панда пишет код на Ruby"

# С параметрами модели
image = RubyLLM.paint "закат над горами акварелью",
                      model: 'dall-e-3'
```

### 5. Embeddings (векторные представления)

```ruby
# Одна строка
embedding = RubyLLM.embed "Ruby оптимизирован для счастья программиста"

# Множественные строки (эффективнее)
embeddings = RubyLLM.embed([
  "Первый текст",
  "Второй текст",
  "Третий текст"
])
```

### 6. Модерация контента

```ruby
result = RubyLLM.moderate "текст для проверки"
```

### 7. Structured Output (структурированный вывод)

```ruby
# Определение схемы
class ProductSchema < RubyLLM::Schema
  string :name
  number :price
  array :features do
    string
  end
  object :manufacturer do
    string :name
    string :country
  end
end

# Использование
chat = RubyLLM.chat.with_schema(ProductSchema)
response = chat.ask "Проанализируй этот продукт", with: "product.txt"
# response вернётся в виде структурированного объекта
```

### 8. Tools (Function Calling)

```ruby
class WeatherTool < RubyLLM::Tool
  description "Получает текущую погоду для города"

  param :city, type: :string, description: "Название города"
  param :units, type: :string, enum: ["celsius", "fahrenheit"], default: "celsius"

  def execute(city:, units: "celsius")
    # Ваша логика получения погоды
    { temperature: 22, conditions: "sunny", units: units }
  end
end

# Использование
chat = RubyLLM.chat(tools: [WeatherTool])
chat.ask "Какая погода в Москве?"
# Модель автоматически вызовет WeatherTool и использует результат
```

### 9. Async (асинхронность)

```ruby
# RubyLLM автоматически становится неблокирующим в async контексте
require 'async'

Async do
  chat = RubyLLM.chat

  # Параллельные запросы
  responses = Async::Barrier.new

  responses.async do
    chat.ask "Вопрос 1"
  end

  responses.async do
    chat.ask "Вопрос 2"
  end

  responses.wait
end
```

## Rails Integration

### Установка

```bash
rails generate ruby_llm:install
rails generate ruby_llm:chat_ui
```

### ActiveRecord интеграция

```ruby
# Модель
class Chat < ApplicationRecord
  acts_as_chat
end

# Использование
chat = Chat.create!
chat.ask "Привет!"
chat.ask "Как дела?" # История сохраняется в БД

# Доступ к сообщениям
chat.messages.each do |message|
  puts "#{message.role}: #{message.content}"
end
```

## Модели

### Обновление реестра моделей

```ruby
# Обновить список доступных моделей
RubyLLM.models.refresh!
```

### Популярные алиасы

```ruby
# OpenAI
chat = RubyLLM.chat(model: 'gpt-4')
chat = RubyLLM.chat(model: 'gpt-4-turbo')
chat = RubyLLM.chat(model: 'gpt-3.5-turbo')

# Anthropic
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')
chat = RubyLLM.chat(model: 'claude-3-opus')
chat = RubyLLM.chat(model: 'claude-3-haiku')

# Google
chat = RubyLLM.chat(model: 'gemini-pro')
chat = RubyLLM.chat(model: 'gemini-pro-vision')
```

## Полезные паттерны

### Чат с системным промптом

```ruby
chat = RubyLLM.chat(
  model: 'gpt-4',
  system: "Ты полезный ассистент, который отвечает на русском языке"
)
```

### Настройка параметров генерации

```ruby
chat = RubyLLM.chat(
  model: 'gpt-4',
  temperature: 0.7,    # Креативность (0.0 - 2.0)
  max_tokens: 1000,    # Максимум токенов в ответе
  top_p: 0.9          # Nucleus sampling
)
```

### Обработка ошибок

```ruby
begin
  chat = RubyLLM.chat
  response = chat.ask "Привет!"
rescue RubyLLM::Error => e
  puts "Ошибка API: #{e.message}"
rescue StandardError => e
  puts "Общая ошибка: #{e.message}"
end
```

### Доступ к метаданным ответа

```ruby
response = chat.ask "Привет!"
puts response.content        # Текст ответа
puts response.role          # 'assistant'
puts response.model         # Использованная модель
puts response.tokens        # Информация о токенах
```

## Важные замечания

1. **Контекст сохраняется:** Каждый вызов `ask` отправляет всю историю разговора
2. **Streaming:** Метод `ask` с блоком всё равно возвращает полный Message
3. **Async:** Автоматически работает в Fiber/Async контекстах
4. **Модели:** 500+ моделей в реестре, обновляется командой `models:refresh!`
5. **Rails:** `acts_as_chat` автоматически сохраняет историю в БД
6. **Безопасность:** Используйте переменные окружения для API ключей

## Дополнительная документация

- **Getting Started:** https://rubyllm.com/getting-started/
- **Tools:** https://rubyllm.com/tools/
- **Rails:** https://rubyllm.com/rails/
- **Streaming:** https://rubyllm.com/streaming/
- **Embeddings:** https://rubyllm.com/embeddings/
- **Async:** https://rubyllm.com/async/
- **Models:** https://rubyllm.com/models/
