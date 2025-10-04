# Модуль для обработки медиа-сообщений в Telegram боте
# Подключает обработчики для различных типов контента: фото, аудио, видео и т.д.
module Telegram::MediaHandlers
  extend ActiveSupport::Concern

  # Обработка фотографий
  def photo(photo_sizes)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка аудиофайлов
  def audio(audio)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка голосовых сообщений
  def voice(voice)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка видео
  def video(video)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка документов
  def document(document)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка видео-кружочков (video notes)
  def video_note(video_note)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка стикеров
  def sticker(sticker)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка локации
  def location(location)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка контактов
  def contact(contact)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка venue (место с адресом)
  def venue(venue)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка опросов
  def poll(poll)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка игровых данных
  def game(game)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка инвойсов
  def invoice(invoice)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка успешного платежа
  def successful_payment(successful_payment)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка связанных данных платежа
  def connected_website(connected_website)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка passport данных
  def passport_data(passport_data)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка прокси-платежа
  def pre_checkout_query(pre_checkout_query)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка данных о доставке
  def shipping_query(shipping_query)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end

  # Обработка данных авторизации
  def passport_data_received(passport_data)
    respond_with :message, text: I18n.t('telegram_bot.media.not_supported')
  end
end
