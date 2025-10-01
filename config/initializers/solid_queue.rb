# Конфигурация Solid Queue
# Документация: https://github.com/basecamp/solid_queue

Rails.application.configure do
  config.solid_queue.connects_to = { database: { writing: :queue } }
end
