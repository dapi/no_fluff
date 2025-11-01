# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_01_214739) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "channel_messages", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "channel_id", null: false
    t.string "channel_username"
    t.string "channel_title"
    t.bigint "sender_id"
    t.string "sender_username"
    t.string "sender_first_name"
    t.string "sender_last_name"
    t.text "content"
    t.string "message_type"
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id"], name: "index_channel_messages_on_channel_id"
    t.index ["message_id", "channel_id"], name: "index_channel_messages_on_unique", unique: true
  end

  create_table "channels", force: :cascade do |t|
    t.bigint "telegram_id", null: false
    t.string "username", null: false
    t.string "title"
    t.text "description"
    t.integer "subscribers_count"
    t.boolean "is_verified", default: false
    t.datetime "last_post_at"
    t.datetime "monitored_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_successful_update_at", precision: nil
    t.datetime "deactivated_at", precision: nil
    t.string "deactivation_reason"
    t.string "bot_join_status", default: "not_joined", null: false
    t.text "bot_join_error"
    t.datetime "bot_join_at"
    t.bigint "follower_user_id"
    t.integer "user_access_status", default: 0, null: false
    t.integer "assignment_status", default: 0, null: false
    t.datetime "assigned_at", precision: nil
    t.datetime "last_activity_at", precision: nil
    t.decimal "activity_score", precision: 5, scale: 2, default: "0.0", null: false
    t.index ["activity_score"], name: "index_channels_on_activity_score"
    t.index ["assignment_status"], name: "index_channels_on_assignment_status"
    t.index ["bot_join_status"], name: "index_channels_on_bot_join_status"
    t.index ["deactivated_at"], name: "index_channels_on_deactivated_at"
    t.index ["follower_user_id"], name: "index_channels_on_follower_user_id"
    t.index ["last_activity_at"], name: "index_channels_on_last_activity_at"
    t.index ["last_post_at"], name: "index_channels_on_last_post_at"
    t.index ["last_successful_update_at"], name: "index_channels_on_last_successful_update_at"
    t.index ["monitored_at"], name: "index_channels_on_monitored_at"
    t.index ["telegram_id"], name: "index_channels_on_telegram_id", unique: true
    t.index ["user_access_status"], name: "index_channels_on_user_access_status"
    t.index ["username"], name: "index_channels_on_username", unique: true
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "model_id"
    t.bigint "telegram_user_id", null: false
    t.integer "session_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.jsonb "context", default: {}
    t.datetime "last_activity_at"
    t.integer "messages_count", default: 0
    t.index ["context"], name: "index_chats_on_context", using: :gin
    t.index ["last_activity_at"], name: "index_chats_on_last_activity_at"
    t.index ["model_id"], name: "index_chats_on_model_id"
    t.index ["status"], name: "index_chats_on_status"
    t.index ["telegram_user_id", "session_type"], name: "index_chats_on_telegram_user_id_and_session_type"
    t.index ["telegram_user_id"], name: "index_chats_on_telegram_user_id"
  end

  create_table "deploy_notifications", force: :cascade do |t|
    t.string "version", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_deploy_notifications_on_created_at"
    t.index ["version"], name: "index_deploy_notifications_on_version", unique: true
  end

  create_table "feedbacks", force: :cascade do |t|
    t.bigint "telegram_user_id", null: false
    t.bigint "post_id", null: false
    t.integer "sentiment", default: 0, null: false
    t.text "comment"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_feedbacks_on_created_at"
    t.index ["post_id"], name: "index_feedbacks_on_post_id"
    t.index ["sentiment"], name: "index_feedbacks_on_sentiment"
    t.index ["telegram_user_id", "post_id"], name: "index_feedbacks_on_telegram_user_id_and_post_id", unique: true
    t.index ["telegram_user_id"], name: "index_feedbacks_on_telegram_user_id"
  end

  create_table "follower_users", force: :cascade do |t|
    t.string "phone_number", null: false
    t.integer "auth_status", default: 0, null: false
    t.text "session_string_encrypted"
    t.text "api_credentials_encrypted"
    t.jsonb "device_info", default: {}
    t.integer "daily_joins_limit", default: 50, null: false
    t.integer "daily_joins_count", default: 0, null: false
    t.date "last_reset_date"
    t.integer "max_channels", default: 400, null: false
    t.integer "channels_count", default: 0, null: false
    t.decimal "workload_score", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "health_score", precision: 5, scale: 2, default: "100.0", null: false
    t.integer "consecutive_errors", default: 0, null: false
    t.integer "priority", default: 0, null: false
    t.string "specialization"
    t.datetime "last_authorized_at", precision: nil
    t.datetime "last_successful_join", precision: nil
    t.datetime "last_activity_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auth_status"], name: "index_follower_users_on_auth_status"
    t.index ["channels_count"], name: "index_follower_users_on_channels_count"
    t.index ["daily_joins_count"], name: "index_follower_users_on_daily_joins_count"
    t.index ["health_score"], name: "index_follower_users_on_health_score"
    t.index ["last_activity_at"], name: "index_follower_users_on_last_activity_at"
    t.index ["phone_number"], name: "index_follower_users_on_phone_number", unique: true
    t.index ["priority"], name: "index_follower_users_on_priority"
    t.index ["specialization"], name: "index_follower_users_on_specialization"
  end

  create_table "messages", force: :cascade do |t|
    t.string "role", null: false
    t.text "content"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chat_id", null: false
    t.bigint "model_id"
    t.bigint "tool_call_id"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.string "model_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "family"
    t.datetime "model_created_at"
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.date "knowledge_cutoff"
    t.jsonb "modalities", default: {}
    t.jsonb "capabilities", default: []
    t.jsonb "pricing", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "post_classifications", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "telegram_user_id", null: false
    t.bigint "chat_id"
    t.float "importance_score", default: 0.0
    t.boolean "is_relevant", default: false
    t.text "reasoning"
    t.float "confidence", default: 0.0
    t.jsonb "classification_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_post_classifications_on_chat_id"
    t.index ["importance_score"], name: "index_post_classifications_on_importance_score"
    t.index ["is_relevant"], name: "index_post_classifications_on_is_relevant"
    t.index ["post_id"], name: "index_post_classifications_on_post_id"
    t.index ["telegram_user_id", "post_id"], name: "index_post_classifications_on_telegram_user_id_and_post_id", unique: true
    t.index ["telegram_user_id"], name: "index_post_classifications_on_telegram_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "channel_id", null: false
    t.bigint "telegram_message_id", null: false
    t.text "text"
    t.jsonb "media_urls", default: []
    t.datetime "published_at", null: false
    t.boolean "is_important", default: false
    t.float "importance_score", default: 0.0
    t.boolean "is_ad", default: false
    t.boolean "is_fluff", default: false
    t.bigint "is_duplicate_of"
    t.jsonb "topics", default: []
    t.text "classification_reasoning"
    t.float "confidence", default: 0.0
    t.jsonb "classification_data", default: {}
    t.bigint "classified_by_session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id", "published_at"], name: "index_posts_on_channel_id_and_published_at"
    t.index ["channel_id", "telegram_message_id"], name: "index_posts_on_channel_id_and_telegram_message_id", unique: true
    t.index ["channel_id"], name: "index_posts_on_channel_id"
    t.index ["importance_score"], name: "index_posts_on_importance_score"
    t.index ["is_ad"], name: "index_posts_on_is_ad"
    t.index ["is_duplicate_of"], name: "index_posts_on_is_duplicate_of"
    t.index ["is_fluff"], name: "index_posts_on_is_fluff"
    t.index ["is_important"], name: "index_posts_on_is_important"
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["telegram_message_id"], name: "index_posts_on_telegram_message_id"
    t.index ["topics"], name: "index_posts_on_topics", using: :gin
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "telegram_user_id", null: false
    t.bigint "channel_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_digest_sent_at"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_subscriptions_on_active"
    t.index ["channel_id"], name: "index_subscriptions_on_channel_id"
    t.index ["last_digest_sent_at"], name: "index_subscriptions_on_last_digest_sent_at"
    t.index ["telegram_user_id", "active"], name: "index_subscriptions_on_user_and_active"
    t.index ["telegram_user_id", "channel_id"], name: "index_subscriptions_on_telegram_user_id_and_channel_id", unique: true
    t.index ["telegram_user_id"], name: "index_subscriptions_on_telegram_user_id"
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key", null: false
    t.jsonb "value"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  create_table "telegram_users", force: :cascade do |t|
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "language_code", default: "ru"
    t.boolean "is_premium", default: false
    t.boolean "is_bot", default: false
    t.integer "delivery_frequency", default: 3
    t.integer "content_format", default: 3
    t.integer "filter_strictness", default: 1
    t.string "timezone", default: "UTC"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_admin", default: false, null: false
    t.jsonb "session_data", default: {}
    t.index ["content_format"], name: "index_telegram_users_on_content_format"
    t.index ["delivery_frequency"], name: "index_telegram_users_on_delivery_frequency"
    t.index ["is_admin"], name: "index_telegram_users_on_is_admin"
    t.index ["is_premium"], name: "index_telegram_users_on_is_premium"
    t.index ["session_data"], name: "index_telegram_users_on_session_data", using: :gin
    t.index ["username"], name: "index_telegram_users_on_username", unique: true
  end

  create_table "tool_calls", force: :cascade do |t|
    t.string "tool_call_id", null: false
    t.string "name", null: false
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "message_id", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "user_digest_items", force: :cascade do |t|
    t.bigint "user_digest_id", null: false
    t.bigint "post_id", null: false
    t.integer "position", null: false
    t.text "summary"
    t.text "formatted_content"
    t.boolean "is_original_content", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_user_digest_items_on_post_id"
    t.index ["user_digest_id", "position"], name: "index_user_digest_items_on_user_digest_id_and_position"
    t.index ["user_digest_id", "post_id"], name: "index_user_digest_items_on_user_digest_id_and_post_id", unique: true
    t.index ["user_digest_id"], name: "index_user_digest_items_on_user_digest_id"
  end

  create_table "user_digests", force: :cascade do |t|
    t.bigint "telegram_user_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "scheduled_for"
    t.datetime "sent_at"
    t.integer "posts_analyzed_count", default: 0
    t.integer "posts_included_count", default: 0
    t.text "content"
    t.jsonb "format_settings", default: {}
    t.string "telegram_message_id"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_for"], name: "index_user_digests_on_scheduled_for"
    t.index ["sent_at"], name: "index_user_digests_on_sent_at"
    t.index ["status"], name: "index_user_digests_on_status"
    t.index ["telegram_user_id", "scheduled_for"], name: "index_user_digests_on_telegram_user_id_and_scheduled_for"
    t.index ["telegram_user_id", "status"], name: "index_user_digests_on_telegram_user_id_and_status"
    t.index ["telegram_user_id"], name: "index_user_digests_on_telegram_user_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.bigint "telegram_user_id", null: false
    t.jsonb "topic_weights", default: {}
    t.jsonb "channel_weights", default: {}
    t.float "adjusted_importance_threshold", default: 50.0
    t.jsonb "personalization_data", default: {}
    t.datetime "last_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_weights"], name: "index_user_preferences_on_channel_weights", using: :gin
    t.index ["last_updated_at"], name: "index_user_preferences_on_last_updated_at"
    t.index ["telegram_user_id"], name: "index_user_preferences_on_telegram_user_id"
    t.index ["topic_weights"], name: "index_user_preferences_on_topic_weights", using: :gin
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "channels", "follower_users"
  add_foreign_key "chats", "models"
  add_foreign_key "chats", "telegram_users"
  add_foreign_key "feedbacks", "posts"
  add_foreign_key "feedbacks", "telegram_users"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "post_classifications", "chats"
  add_foreign_key "post_classifications", "posts"
  add_foreign_key "post_classifications", "telegram_users"
  add_foreign_key "posts", "channels"
  add_foreign_key "subscriptions", "channels"
  add_foreign_key "subscriptions", "telegram_users"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "user_digest_items", "posts"
  add_foreign_key "user_digest_items", "user_digests"
  add_foreign_key "user_digests", "telegram_users"
  add_foreign_key "user_preferences", "telegram_users"
end
