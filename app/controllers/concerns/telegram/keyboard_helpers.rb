# Модуль с helper-методами для работы с Telegram клавиатурами
# Позволяет сократить дублирование кода при создании inline-кнопок
module Telegram::KeyboardHelpers
  extend ActiveSupport::Concern

  private

  # Создает inline-кнопку
  def button(text, callback_data = nil, url: nil, **options)
    if callback_data.present?
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: text,
        callback_data: callback_data,
        **options
      )
    elsif url.present?
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: text,
        url: url,
        **options
      )
    else
      Telegram::Bot::Types::InlineKeyboardButton.new(text: text, **options)
    end
  end

  # Создает inline-кнопку с callback_data
  def callback_button(text, data)
    button(text, data)
  end

  # Создает inline-кнопку с URL
  def url_button(text, url)
    button(text, nil, url: url)
  end

  # Создает inline-клавиатуру из массива кнопок
  def inline_keyboard(*rows)
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: rows)
  end

  # Создает row с кнопками
  def keyboard_row(*buttons)
    buttons
  end
end