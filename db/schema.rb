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

ActiveRecord::Schema.define(version: 20_200_716_184_141) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'btree_gin'
  enable_extension 'btree_gist'
  enable_extension 'fuzzystrmatch'
  enable_extension 'pg_trgm'
  enable_extension 'pgcrypto'
  enable_extension 'plpgsql'
  enable_extension 'uuid-ossp'

  create_table 'active_storage_attachments', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'name', null: false
    t.uuid 'record_id', null: false
    t.string 'record_type', null: false
    t.uuid 'blob_id', null: false
    t.datetime 'created_at', null: false
    t.index %w[record_type record_id name blob_id], name: 'index_active_storage_attachments_uniqueness', unique: true
  end

  create_table 'active_storage_blobs', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'key', null: false
    t.string 'filename', null: false
    t.string 'content_type'
    t.text 'metadata'
    t.bigint 'byte_size', null: false
    t.string 'checksum', null: false
    t.datetime 'created_at', null: false
    t.index ['key'], name: 'index_active_storage_blobs_on_key', unique: true
  end

  create_table 'answers', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'type'
    t.uuid 'question_id', null: false
    t.uuid 'user_id'
    t.jsonb 'body', default: { 'data' => [] }
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['question_id'], name: 'index_answers_on_question_id'
    t.index %w[type question_id user_id], name: 'index_answers_on_type_and_question_id_and_user_id', using: :gin
    t.index ['type'], name: 'index_answers_on_type'
    t.index ['user_id'], name: 'index_answers_on_user_id'
  end

  create_table 'friendly_id_slugs', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'slug', null: false
    t.uuid 'sluggable_id', null: false
    t.string 'sluggable_type', limit: 50
    t.string 'scope'
    t.datetime 'created_at'
    t.index %w[slug sluggable_type scope], name: 'index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope', unique: true
    t.index %w[slug sluggable_type], name: 'index_friendly_id_slugs_on_slug_and_sluggable_type', using: :gin
    t.index %w[sluggable_type sluggable_id], name: 'index_friendly_id_slugs_on_sluggable_type_and_sluggable_id', using: :gin
  end

  create_table 'interventions', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'type', null: false
    t.uuid 'user_id', null: false
    t.jsonb 'settings'
    t.boolean 'allow_guests', default: false, null: false
    t.string 'status'
    t.string 'name', null: false
    t.string 'slug'
    t.jsonb 'body', default: { 'data' => [] }
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index %w[allow_guests status], name: 'index_interventions_on_allow_guests_and_status', using: :gin
    t.index ['allow_guests'], name: 'index_interventions_on_allow_guests'
    t.index ['name'], name: 'index_interventions_on_name'
    t.index ['slug'], name: 'index_interventions_on_slug', unique: true
    t.index ['status'], name: 'index_interventions_on_status'
    t.index %w[type name], name: 'index_interventions_on_type_and_name', using: :gin
    t.index %w[type user_id name], name: 'index_interventions_on_type_and_user_id_and_name', using: :gin
    t.index ['type'], name: 'index_interventions_on_type'
    t.index ['user_id'], name: 'index_interventions_on_user_id'
  end

  create_table 'questions', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'type', null: false
    t.uuid 'intervention_id', null: false
    t.jsonb 'settings'
    t.integer 'position', default: 0, null: false
    t.string 'title', default: '', null: false
    t.string 'subtitle'
    t.jsonb 'narrator'
    t.string 'video_url'
    t.jsonb 'formula', default: { 'payload' => '', 'patterns' => [] }
    t.jsonb 'body', default: { 'data' => [] }
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['intervention_id'], name: 'index_questions_on_intervention_id'
    t.index ['title'], name: 'index_questions_on_title'
    t.index %w[type intervention_id title], name: 'index_questions_on_type_and_intervention_id_and_title', using: :gin
    t.index %w[type title], name: 'index_questions_on_type_and_title', using: :gin
    t.index ['type'], name: 'index_questions_on_type'
  end

  create_table 'user_log_requests', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.uuid 'user_id'
    t.string 'controller'
    t.string 'action'
    t.jsonb 'query_string'
    t.jsonb 'params'
    t.string 'user_agent'
    t.inet 'remote_ip'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
  end

  create_table 'users', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'provider', default: 'email', null: false
    t.string 'uid', default: '', null: false
    t.string 'first_name', default: '', null: false
    t.string 'last_name', default: '', null: false
    t.string 'email'
    t.string 'phone'
    t.text 'roles', default: [], array: true
    t.jsonb 'tokens'
    t.boolean 'deactivated', default: false, null: false
    t.string 'confirmation_token'
    t.datetime 'confirmed_at'
    t.datetime 'confirmation_sent_at'
    t.string 'unconfirmed_email'
    t.string 'encrypted_password', default: '', null: false
    t.string 'reset_password_token'
    t.datetime 'reset_password_sent_at'
    t.boolean 'allow_password_change', default: false, null: false
    t.datetime 'remember_created_at'
    t.integer 'sign_in_count', default: 0, null: false
    t.datetime 'current_sign_in_at'
    t.datetime 'last_sign_in_at'
    t.inet 'current_sign_in_ip'
    t.inet 'last_sign_in_ip'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['confirmation_token'], name: 'index_users_on_confirmation_token', unique: true
    t.index ['email'], name: 'index_users_on_email', unique: true
    t.index ['reset_password_token'], name: 'index_users_on_reset_password_token', unique: true
    t.index ['roles'], name: 'index_users_on_roles', using: :gin
    t.index %w[uid provider], name: 'index_users_on_uid_and_provider', unique: true
    t.index %w[uid roles], name: 'index_users_on_uid_and_roles', using: :gin
    t.index ['uid'], name: 'index_users_on_uid', unique: true
  end

  add_foreign_key 'active_storage_attachments', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'answers', 'questions'
  add_foreign_key 'interventions', 'users'
  add_foreign_key 'questions', 'interventions'
  add_foreign_key 'user_log_requests', 'users'
end
