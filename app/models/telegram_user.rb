class TelegramUser < ApplicationRecord
  has_many :subscriptions, dependent: :destroy
  has_many :channels, through: :subscriptions
  has_many :digests, dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_one :user_preference, dependent: :destroy
  has_many :chats, dependent: :destroy

  # Настройки
  enum delivery_frequency: {
    realtime: 0,
    three_times_daily: 1,
    twice_daily: 2,
    daily: 3,
    every_two_days: 4,
    weekly: 5,
    on_demand: 6
  }

  enum content_format: {
    original_posts: 0,
    short_summaries: 1,
    unified_digest: 2,
    combo: 3,
    headlines_only: 4
  }

  enum filter_strictness: {
    maximum: 0,
    high: 1,
    medium: 2,
    low: 3,
    adaptive: 4
  }

  # Валидации
  validates :username, uniqueness: { allow_blank: true }
  validates :language_code, presence: true
  validates :delivery_frequency, presence: true
  validates :content_format, presence: true
  validates :filter_strictness, presence: true

  # Получить или создать активную сессию определенного типа
  def chat_for(type)
    chats.active.find_or_create_by!(session_type: type) do |session|
      session.context = build_initial_context
      session.last_activity_at = Time.current
    end
  end

  # Построить начальный контекст для новой сессии
  def build_initial_context
    {
      user_preferences: {
        delivery_frequency: delivery_frequency,
        content_format: content_format,
        filter_strictness: filter_strictness,
        timezone: timezone || 'UTC'
      },
      feedback_history: recent_feedback_summary,
      subscription_priorities: subscriptions.pluck(:channel_id, :priority).to_h,
      created_at: Time.current.iso8601
    }
  end

  # Краткая сводка последнего фидбека
  def recent_feedback_summary(limit: 20)
    feedbacks.includes(:post).order(created_at: :desc).limit(limit).map do |f|
      {
        liked: f.like?,
        post_importance: f.post.importance_score,
        topics: f.post.topics || [],
        created_at: f.created_at.iso8601
      }
    end
  end

  # Архивировать неактивные сессии
  def archive_inactive_sessions
    chats.active
      .where("last_activity_at < ?", 90.days.ago)
      .update_all(status: :archived)
  end

  # Полное имя пользователя
  def full_name
    [first_name, last_name].compact.join(' ')
  end

  # Отображаемое имя (username или full_name)
  def display_name
    username || full_name || "Пользователь ##{id}"
  end
end
