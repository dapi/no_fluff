Rails.application.routes.draw do
  default_url_options ApplicationConfig.default_url_options.symbolize_keys
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Telegram Bot webhook
  telegram_webhook TelegramWebhookController

  # Solid Queue Dashboard
  mount SolidQueueDashboard::Engine, at: '/solid-queue'
end
