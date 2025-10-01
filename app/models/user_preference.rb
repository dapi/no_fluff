# Динамические данные персонализации пользователя
#
# Эта модель отделена от TelegramUser по принципу Separation of Concerns:
# - TelegramUser хранит идентификационные данные и базовые настройки (стабильные данные)
# - UserPreference хранит данные персонализации на основе поведения (динамические данные)
#
# Содержит:
# - topic_weights: веса предпочтений по темам
# - channel_weights: веса предпочтений по каналам
# - adjusted_importance_threshold: порог важности контента
# - personalization_data: дополнительные ML-метрики
#
# Обновляется часто на основе активности пользователя (фидбек, взаимодействия)
class UserPreference < ApplicationRecord
  belongs_to :telegram_user
end
