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

ActiveRecord::Schema.define(version: 20_201_123_161_626) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'btree_gin'
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

  create_table 'addresses', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.uuid 'user_id'
    t.string 'name'
    t.string 'country'
    t.string 'state'
    t.string 'state_abbreviation'
    t.string 'city'
    t.string 'zip_code'
    t.string 'street'
    t.string 'building_address'
    t.string 'apartment_number'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['user_id'], name: 'index_addresses_on_user_id'
  end

  create_table 'answers', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'type'
    t.uuid 'question_id', null: false
    t.uuid 'user_id'
    t.jsonb 'body'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['question_id'], name: 'index_answers_on_question_id'
    t.index ['type'], name: 'index_answers_on_type'
    t.index ['user_id'], name: 'index_answers_on_user_id'
  end

  create_table 'audios', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'sha256', null: false
    t.integer 'usage_counter', default: 1
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['sha256'], name: 'index_audios_on_sha256', unique: true
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

  create_table 'intervention_invitations', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.uuid 'intervention_id', null: false
    t.string 'email'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index %w[intervention_id email], name: 'index_intervention_invitations_on_intervention_id_and_email', unique: true
  end

  create_table 'interventions', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.uuid 'problem_id', null: false
    t.jsonb 'settings'
    t.integer 'position', default: 0, null: false
    t.string 'name', null: false
    t.string 'slug'
    t.string 'schedule'
    t.integer 'schedule_payload'
    t.date 'schedule_at'
    t.jsonb 'formula'
    t.jsonb 'body'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['name'], name: 'index_interventions_on_name'
    t.index %w[problem_id name], name: 'index_interventions_on_problem_id_and_name', using: :gin
    t.index ['problem_id'], name: 'index_interventions_on_problem_id'
    t.index ['schedule'], name: 'index_interventions_on_schedule'
    t.index ['schedule_at'], name: 'index_interventions_on_schedule_at'
    t.index ['slug'], name: 'index_interventions_on_slug', unique: true
  end

  create_table 'problems', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'name'
    t.uuid 'user_id', null: false
    t.datetime 'published_at'
    t.string 'status'
    t.string 'shared_to', null: false
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index %w[name user_id], name: 'index_problems_on_name_and_user_id', using: :gin
    t.index ['name'], name: 'index_problems_on_name'
    t.index ['shared_to'], name: 'index_problems_on_shared_to'
    t.index ['status'], name: 'index_problems_on_status'
    t.index ['user_id'], name: 'index_problems_on_user_id'
  end

  create_table 'question_groups', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.uuid 'intervention_id', null: false
    t.string 'title', null: false
    t.bigint 'position', default: 0, null: false
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.string 'type'
    t.index %w[intervention_id title], name: 'index_question_groups_on_intervention_id_and_title', using: :gin
    t.index ['intervention_id'], name: 'index_question_groups_on_intervention_id'
    t.index ['title'], name: 'index_question_groups_on_title'
    t.index ['type'], name: 'index_question_groups_on_type'
  end

  create_table 'questions', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.string 'type', null: false
    t.uuid 'question_group_id', null: false
    t.jsonb 'settings'
    t.integer 'position', default: 0, null: false
    t.string 'title', default: '', null: false
    t.string 'subtitle'
    t.jsonb 'narrator'
    t.string 'video_url'
    t.jsonb 'formula'
    t.jsonb 'body'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['question_group_id'], name: 'index_questions_on_question_group_id'
    t.index ['title'], name: 'index_questions_on_title'
    t.index %w[type question_group_id title], name: 'index_questions_on_type_and_question_group_id_and_title', using: :gin
    t.index %w[type title], name: 'index_questions_on_type_and_title', using: :gin
    t.index ['type'], name: 'index_questions_on_type'
  end

  create_table 'user_interventions', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.uuid 'user_id', null: false
    t.uuid 'intervention_id', null: false
    t.datetime 'submitted_at'
    t.date 'schedule_at'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['intervention_id'], name: 'index_user_interventions_on_intervention_id'
    t.index %w[user_id intervention_id], name: 'index_user_interventions_on_user_id_and_intervention_id', unique: true
    t.index ['user_id'], name: 'index_user_interventions_on_user_id'
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
    t.string 'time_zone'
    t.string 'roles', default: [], array: true
    t.jsonb 'tokens'
    t.boolean 'active', default: true, null: false
    t.string 'confirmation_token'
    t.datetime 'confirmed_at'
    t.datetime 'confirmation_sent_at'
    t.string 'unconfirmed_email'
    t.string 'invitation_token'
    t.datetime 'invitation_created_at'
    t.datetime 'invitation_sent_at'
    t.datetime 'invitation_accepted_at'
    t.integer 'invitation_limit'
    t.string 'invited_by_type'
    t.bigint 'invited_by_id'
    t.integer 'invitations_count', default: 0
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
    t.index ['invitation_token'], name: 'index_users_on_invitation_token', unique: true
    t.index ['invitations_count'], name: 'index_users_on_invitations_count'
    t.index %w[invited_by_type invited_by_id], name: 'index_users_on_invited_by_type_and_invited_by_id'
    t.index ['reset_password_token'], name: 'index_users_on_reset_password_token', unique: true
    t.index ['roles'], name: 'index_users_on_roles', using: :gin
    t.index %w[uid provider], name: 'index_users_on_uid_and_provider', unique: true
    t.index %w[uid roles], name: 'index_users_on_uid_and_roles', using: :gin
    t.index ['uid'], name: 'index_users_on_uid', unique: true
  end

  add_foreign_key 'active_storage_attachments', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'addresses', 'users'
  add_foreign_key 'answers', 'questions'
  add_foreign_key 'answers', 'users'
  add_foreign_key 'intervention_invitations', 'interventions'
  add_foreign_key 'interventions', 'problems'
  add_foreign_key 'problems', 'users'
  add_foreign_key 'question_groups', 'interventions'
  add_foreign_key 'questions', 'question_groups'
  add_foreign_key 'user_interventions', 'interventions'
  add_foreign_key 'user_interventions', 'users'
  add_foreign_key 'user_log_requests', 'users'
end
