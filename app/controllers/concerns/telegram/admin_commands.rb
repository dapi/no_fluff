# Модуль с административными командами Telegram бота
module Telegram::AdminCommands
  extend ActiveSupport::Concern

  # Команда /channels - вывод списка каналов
  def channels!(*args)
    # Проверяем права доступа
    unless current_user&.is_admin?
      Rails.logger.warn "Unauthorized access attempt to /channels by user #{current_user&.username}"
      respond_with :message, text: I18n.t('telegram_bot.channels.admin_list.admin_only')
      return
    end

    Rails.logger.info "Admin user #{current_user.username} accessed channels list"

    begin
      # Извлекаем номер страницы из аргументов
      page = extract_page_from_args(args) || 1
      per_page = 20

      # Получаем каналы с количеством активных подписчиков
      channels_with_subscribers = get_channels_with_subscribers(page, per_page)

      if channels_with_subscribers[:channels].empty?
        respond_with :message, text: I18n.t('telegram_bot.channels.admin_list.empty')
        return
      end

      # Формируем сообщение со списком каналов
      message_text = build_channels_list_message(channels_with_subscribers)

      # Создаем клавиатуру с пагинацией если нужно
      reply_markup = build_channels_list_keyboard(channels_with_subscribers, page)

      respond_with :message, text: message_text, reply_markup: reply_markup

    rescue => e
      Bugsnag.notify(e) { |b| b.metadata = { command: '/channels', user: current_user&.username } }
      Rails.logger.error "Error in channels command: #{e.message}"
      respond_with :message, text: I18n.t('telegram_bot.errors.general')
    end
  end

  # Callback query для пагинации списка каналов
  def channels_page_callback_query(page = nil)
    unless current_user&.is_admin?
      answer_callback_query(I18n.t('telegram_bot.channels.admin_list.admin_only'))
      return
    end

    page = page.to_i if page
    page ||= 1

    answer_callback_query('')

    begin
      per_page = 20
      channels_with_subscribers = get_channels_with_subscribers(page, per_page)

      if channels_with_subscribers[:channels].empty?
        edit_message :text, text: I18n.t('telegram_bot.channels.admin_list.empty')
        return
      end

      message_text = build_channels_list_message(channels_with_subscribers)
      reply_markup = build_channels_list_keyboard(channels_with_subscribers, page)

      edit_message :text, text: message_text, reply_markup: reply_markup

    rescue => e
      Bugsnag.notify(e) { |b| b.metadata = { callback: 'channels_page', page: page, user: current_user&.username } }
      Rails.logger.error "Error in channels_page callback: #{e.message}"
      answer_callback_query(I18n.t('telegram_bot.errors.general'))
    end
  end

  private

  # Извлекает номер страницы из аргументов команды
  def extract_page_from_args(args)
    return nil if args.empty?

    page_str = args.first.to_s.strip
    page_str.to_i if page_str.match?(/^\d+$/) && page_str.to_i > 0
  end

  # Получает каналы с количеством активных подписчиков
  def get_channels_with_subscribers(page = 1, per_page = 20)
    # Базовый запрос для получения всех каналов
    base_query = Channel.all

    # Получаем общее количество
    total_count = base_query.count

    # Применяем пагинацию
    offset = (page - 1) * per_page
    channels = base_query.limit(per_page).offset(offset)

    # Для каждого канала получаем количество активных подписчиков
    channels_with_counts = channels.map do |channel|
      active_subscribers = channel.subscriptions.active.count
      channel.define_singleton_method(:active_subscribers_count) { active_subscribers }
      channel
    end

    # Сортируем по количеству подписчиков
    channels_with_counts.sort_by! { |c| -c.active_subscribers_count }

    total_pages = (total_count.to_f / per_page).ceil

    {
      channels: channels_with_counts,
      current_page: page,
      total_pages: total_pages,
      total_count: total_count,
      per_page: per_page
    }
  end

  # Формирует текст сообщения со списком каналов
  def build_channels_list_message(channels_data)
    channels = channels_data[:channels]
    current_page = channels_data[:current_page]
    total_pages = channels_data[:total_pages]
    total_count = channels_data[:total_count]

    message_parts = []
    message_parts << I18n.t('telegram_bot.channels.admin_list.title', count: total_count)
    message_parts << ''

    channels.each_with_index do |channel, index|
      global_index = (current_page - 1) * channels_data[:per_page] + index + 1

      # Определяем иконку статуса
      status_icon = get_channel_status_icon(channel)

      # Форматируем информацию о подписчиках
      subscribers_text = format_subscribers_count(channel.active_subscribers_count)

      # Форматируем время последнего поста
      last_post_text = format_last_post_time(channel.last_post_at)

      # Собираем информацию о канале
      channel_info = "#{global_index}. #{status_icon} @#{channel.username} - 📊 #{subscribers_text}"

      # Добавляем описание если есть
      if channel.description.present?
        channel_info += "\n   📝 #{channel.description.truncate(100)}"
      end

      # Добавляем информацию о последнем посте
      if last_post_text.present?
        channel_info += "\n   📅 #{last_post_text}"
      end

      message_parts << channel_info
      message_parts << ''  # Пустая строка между каналами
    end

    # Добавляем информацию о пагинации
    if total_pages > 1
      message_parts << ''
      message_parts << I18n.t('telegram_bot.channels.admin_list.pagination_info', current: current_page, total: total_pages)
    end

    message_parts.join("\n")
  end

  # Возвращает иконку статуса канала
  def get_channel_status_icon(channel)
    return '❌' unless channel.active?

    if channel.last_post_at && channel.last_post_at < 7.days.ago
      '⚠️'
    else
      '✅'
    end
  end

  # Форматирует количество подписчиков
  def format_subscribers_count(count)
    count = count.to_i

    if count == 0
      I18n.t('telegram_bot.channels.admin_list.subscribers', count: 0)
    elsif count == 1
      '1 подписчик'
    elsif count >= 2 && count <= 4
      "#{count} подписчика"
    elsif count >= 5 && count <= 20
      I18n.t('telegram_bot.channels.admin_list.subscribers', count: count)
    elsif count % 10 == 1
      "#{count} подписчик"
    elsif count % 10 >= 2 && count % 10 <= 4
      "#{count} подписчика"
    else
      I18n.t('telegram_bot.channels.admin_list.subscribers', count: count)
    end
  end

  # Форматирует время последнего поста
  def format_last_post_time(last_post_at)
    return 'Нет постов' unless last_post_at

    time_ago = time_ago_in_words(last_post_at)
    "#{I18n.t('telegram_bot.channels.admin_list.last_post')} #{time_ago}"
  end

  # Создает клавиатуру для списка каналов
  def build_channels_list_keyboard(channels_data, current_page)
    total_pages = channels_data[:total_pages]

    return nil if total_pages <= 1  # Нет пагинации - не нужна клавиатура

    buttons = []

    # Кнопки навигации
    nav_buttons = []

    # Кнопка "Предыдущая"
    if current_page > 1
      nav_buttons << callback_button(
        I18n.t('telegram_bot.channels.admin_list.previous_page'),
        "channels_page:#{current_page - 1}"
      )
    end

    # Кнопка "Следующая"
    if current_page < total_pages
      nav_buttons << callback_button(
        I18n.t('telegram_bot.channels.admin_list.next_page'),
        "channels_page:#{current_page + 1}"
      )
    end

    buttons << nav_buttons if nav_buttons.any?

    # Кнопка закрытия
    buttons << [ callback_button(I18n.t('telegram_bot.channels.admin_list.close'), 'close_channels_list:') ]

    inline_keyboard(*buttons)
  end

  # Callback query для закрытия списка каналов
  def close_channels_list_callback_query(*)
    unless current_user&.is_admin?
      answer_callback_query(I18n.t('telegram_bot.channels.admin_list.admin_only'))
      return
    end

    answer_callback_query(I18n.t('telegram_bot.channels.admin_list.closed'))

    # Удаляем сообщение или заменяем его на простое сообщение
    begin
      delete_message(payload['message']['message_id'])
    rescue
      # Если не можем удалить, просто отвечаем на callback
    end
  end

  # Вспомогательный метод для форматирования времени
  def time_ago_in_words(time)
    seconds = Time.current - time
    minutes = seconds / 60
    hours = minutes / 60
    days = hours / 24

    if days > 0
      days.round == 1 ? '1 день назад' : "#{days.round} дней назад"
    elsif hours > 0
      hours.round == 1 ? '1 час назад' : "#{hours.round} часов назад"
    elsif minutes > 0
      minutes.round == 1 ? '1 минуту назад' : "#{minutes.round} минут назад"
    else
      'только что'
    end
  end
end
