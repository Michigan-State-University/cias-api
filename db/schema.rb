# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_12_21_122003) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "uuid-ossp"

  create_table "active_storage_attachments", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "answers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "type"
    t.uuid "question_id", null: false
    t.uuid "user_id"
    t.jsonb "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["question_id", "user_id"], name: "index_answers_on_question_id_and_user_id", unique: true
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.index ["type"], name: "index_answers_on_type"
    t.index ["user_id"], name: "index_answers_on_user_id"
  end

  create_table "audios", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "sha256", null: false
    t.integer "usage_counter", default: 1
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["sha256"], name: "index_audios_on_sha256", unique: true
  end

  create_table "interventions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "user_id", null: false
    t.datetime "published_at"
    t.string "status", default: "draft"
    t.string "shared_to", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name", "user_id"], name: "index_interventions_on_name_and_user_id", using: :gin
    t.index ["name"], name: "index_interventions_on_name"
    t.index ["shared_to"], name: "index_interventions_on_shared_to"
    t.index ["status"], name: "index_interventions_on_status"
    t.index ["user_id"], name: "index_interventions_on_user_id"
  end

  create_table "question_groups", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "session_id", null: false
    t.string "title", null: false
    t.bigint "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "type"
    t.index ["session_id", "title"], name: "index_question_groups_on_session_id_and_title", using: :gin
    t.index ["session_id"], name: "index_question_groups_on_session_id"
    t.index ["title"], name: "index_question_groups_on_title"
    t.index ["type"], name: "index_question_groups_on_type"
  end

  create_table "questions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "type", null: false
    t.uuid "question_group_id", null: false
    t.jsonb "settings"
    t.integer "position", default: 0, null: false
    t.string "title", default: "", null: false
    t.string "subtitle"
    t.jsonb "narrator"
    t.string "video_url"
    t.jsonb "formula"
    t.jsonb "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["question_group_id"], name: "index_questions_on_question_group_id"
    t.index ["title"], name: "index_questions_on_title"
    t.index ["type", "question_group_id", "title"], name: "index_questions_on_type_and_question_group_id_and_title", using: :gin
    t.index ["type", "title"], name: "index_questions_on_type_and_title", using: :gin
    t.index ["type"], name: "index_questions_on_type"
  end

  create_table "session_invitations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "session_id", null: false
    t.string "email"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["session_id", "email"], name: "index_session_invitations_on_session_id_and_email", unique: true
  end

  create_table "sessions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "intervention_id", null: false
    t.jsonb "settings"
    t.integer "position", default: 0, null: false
    t.string "name", null: false
    t.string "schedule"
    t.integer "schedule_payload"
    t.date "schedule_at"
    t.jsonb "formula"
    t.jsonb "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["intervention_id", "name"], name: "index_sessions_on_intervention_id_and_name", using: :gin
    t.index ["intervention_id"], name: "index_sessions_on_intervention_id"
    t.index ["name"], name: "index_sessions_on_name"
    t.index ["schedule"], name: "index_sessions_on_schedule"
    t.index ["schedule_at"], name: "index_sessions_on_schedule_at"
  end

  create_table "user_log_requests", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "controller"
    t.string "action"
    t.jsonb "query_string"
    t.jsonb "params"
    t.string "user_agent"
    t.inet "remote_ip"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "user_sessions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "session_id", null: false
    t.datetime "submitted_at"
    t.date "schedule_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["session_id"], name: "index_user_sessions_on_session_id"
    t.index ["user_id", "session_id"], name: "index_user_sessions_on_user_id_and_session_id", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "email"
    t.string "phone"
    t.string "time_zone"
    t.string "roles", default: [], array: true
    t.jsonb "tokens"
    t.boolean "active", default: true, null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "allow_password_change", default: false, null: false
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by_type_and_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["roles"], name: "index_users_on_roles", using: :gin
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
    t.index ["uid", "roles"], name: "index_users_on_uid_and_roles", using: :gin
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "answers", "questions"
  add_foreign_key "answers", "users"
  add_foreign_key "interventions", "users"
  add_foreign_key "question_groups", "sessions"
  add_foreign_key "questions", "question_groups"
  add_foreign_key "session_invitations", "sessions"
  add_foreign_key "sessions", "interventions"
  add_foreign_key "user_log_requests", "users"
  add_foreign_key "user_sessions", "sessions"
  add_foreign_key "user_sessions", "users"
end
