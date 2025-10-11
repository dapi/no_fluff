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

ActiveRecord::Schema[8.0].define(version: 2025_10_11_155051) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "deploy_notifications", force: :cascade do |t|
    t.string "version", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_deploy_notifications_on_created_at"
    t.index ["version"], name: "index_deploy_notifications_on_version", unique: true
  end

  create_table "telegram_users", force: :cascade do |t|
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "language_code"
    t.string "timezone"
    t.boolean "is_admin", default: false
    t.boolean "is_bot", default: false
    t.boolean "is_premium", default: false
    t.integer "delivery_frequency", default: 0
    t.integer "content_format", default: 0
    t.integer "filter_strictness", default: 2
    t.jsonb "session_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
