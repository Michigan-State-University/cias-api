# frozen_string_literal: true

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

ActiveRecord::Schema.define(version: 20_200_525_105_341) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'plpgsql'

  create_table 'interventions', force: :cascade do |t|
    t.string 'type', null: false
    t.bigint 'user_id', null: false
    t.string 'name', null: false
    t.jsonb 'settings'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index %w[type name], name: 'index_interventions_on_type_and_name'
    t.index ['type'], name: 'index_interventions_on_type'
    t.index ['user_id'], name: 'index_interventions_on_user_id'
  end

  create_table 'questions', force: :cascade do |t|
    t.string 'type', null: false
    t.bigint 'intervention_id', null: false
    t.bigint 'previous_id'
    t.string 'title', null: false
    t.string 'subtitle'
    t.jsonb 'body'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['intervention_id'], name: 'index_questions_on_intervention_id'
    t.index ['previous_id'], name: 'index_questions_on_previous_id'
    t.index ['title'], name: 'index_questions_on_title'
  end

  create_table 'user_log_requests', force: :cascade do |t|
    t.bigint 'user_id'
    t.string 'action'
    t.jsonb 'query_string'
    t.jsonb 'params'
    t.string 'user_agent'
    t.inet 'remote_ip'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['user_id'], name: 'index_user_log_requests_on_user_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'provider', default: 'email', null: false
    t.string 'uid', default: '', null: false
    t.string 'first_name'
    t.string 'last_name'
    t.string 'login'
    t.string 'email'
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
    t.index %w[uid provider], name: 'index_users_on_uid_and_provider', unique: true
  end

  add_foreign_key 'interventions', 'users'
  add_foreign_key 'questions', 'interventions'
  add_foreign_key 'user_log_requests', 'users'
end
