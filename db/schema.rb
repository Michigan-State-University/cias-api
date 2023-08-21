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

ActiveRecord::Schema.define(version: 2023_08_21_081907) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
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
    t.string "description"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "alert_phones", force: :cascade do |t|
    t.uuid "sms_plan_id", null: false
    t.bigint "phone_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "answers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "type"
    t.uuid "question_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "user_session_id"
    t.text "body_ciphertext"
    t.boolean "skipped", default: false
    t.uuid "next_session_id"
    t.boolean "draft", default: false
    t.boolean "alternative_branch", default: false
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.index ["type"], name: "index_answers_on_type"
    t.index ["user_session_id"], name: "index_answers_on_user_session_id"
  end

  create_table "audios", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "sha256", null: false
    t.integer "usage_counter", default: 1
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "language"
    t.string "voice_type"
    t.index ["sha256", "language", "voice_type"], name: "index_audios_on_sha256_and_language_and_voice_type", unique: true
    t.index ["sha256"], name: "index_audios_on_sha256", unique: true
  end

  create_table "cat_mh_google_tts_voices", force: :cascade do |t|
    t.integer "google_tts_voice_id"
    t.integer "cat_mh_language_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cat_mh_languages", force: :cascade do |t|
    t.integer "language_id"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cat_mh_populations", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cat_mh_test_attributes", force: :cascade do |t|
    t.string "name"
    t.string "variable_type"
    t.string "range"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cat_mh_test_type_languages", force: :cascade do |t|
    t.integer "cat_mh_language_id"
    t.integer "cat_mh_test_type_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cat_mh_test_type_time_frames", force: :cascade do |t|
    t.integer "cat_mh_time_frame_id"
    t.integer "cat_mh_test_type_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cat_mh_test_types", force: :cascade do |t|
    t.string "short_name"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "cat_mh_population_id"
    t.index ["cat_mh_population_id"], name: "index_cat_mh_test_types_on_cat_mh_population_id"
  end

  create_table "cat_mh_time_frames", force: :cascade do |t|
    t.integer "timeframe_id"
    t.string "description"
    t.string "short_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cat_mh_variables", force: :cascade do |t|
    t.bigint "cat_mh_test_attribute_id"
    t.bigint "cat_mh_test_type_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cat_mh_test_attribute_id"], name: "index_cat_mh_variables_on_cat_mh_test_attribute_id"
    t.index ["cat_mh_test_type_id"], name: "index_cat_mh_variables_on_cat_mh_test_type_id"
  end

  create_table "chart_statistics", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "label"
    t.uuid "organization_id", null: false
    t.uuid "health_system_id", null: false
    t.uuid "health_clinic_id", null: false
    t.uuid "chart_id", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "filled_at"
    t.index ["chart_id"], name: "index_chart_statistics_on_chart_id"
    t.index ["health_clinic_id"], name: "index_chart_statistics_on_health_clinic_id"
    t.index ["health_system_id"], name: "index_chart_statistics_on_health_system_id"
    t.index ["organization_id"], name: "index_chart_statistics_on_organization_id"
    t.index ["user_id"], name: "index_chart_statistics_on_user_id"
  end

  create_table "charts", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "status", default: "draft"
    t.jsonb "formula"
    t.uuid "dashboard_section_id"
    t.datetime "published_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "chart_type", default: "bar_chart"
    t.boolean "trend_line", default: false, null: false
    t.integer "position", default: 1, null: false
    t.index ["dashboard_section_id"], name: "index_charts_on_dashboard_section_id"
  end

  create_table "clinic_locations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "department", null: false
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "external_id"
    t.index ["external_id"], name: "index_clinic_locations_on_external_id", unique: true
  end

  create_table "collaborators", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.boolean "view", default: true, null: false
    t.boolean "edit", default: false, null: false
    t.boolean "data_access", default: false, null: false
    t.uuid "user_id", null: false
    t.uuid "intervention_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["intervention_id"], name: "index_collaborators_on_intervention_id"
    t.index ["user_id", "intervention_id"], name: "index_collaborators_on_user_id_and_intervention_id", unique: true
    t.index ["user_id"], name: "index_collaborators_on_user_id"
  end

  create_table "consumption_results", force: :cascade do |t|
    t.jsonb "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "day_id", null: false
    t.index ["day_id"], name: "index_consumption_results_on_day_id"
  end

  create_table "dashboard_sections", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.uuid "reporting_dashboard_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "position", default: 1, null: false
    t.index ["name", "reporting_dashboard_id"], name: "index_dashboard_sections_on_name_and_reporting_dashboard_id", unique: true
    t.index ["reporting_dashboard_id"], name: "index_dashboard_sections_on_reporting_dashboard_id"
  end

  create_table "days", force: :cascade do |t|
    t.date "exact_date", null: false
    t.uuid "user_session_id", null: false
    t.uuid "question_group_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["question_group_id"], name: "index_days_on_question_group_id"
    t.index ["user_session_id"], name: "index_days_on_user_session_id"
  end

  create_table "downloaded_reports", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "generated_report_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["generated_report_id"], name: "index_downloaded_reports_on_generated_report_id"
    t.index ["user_id", "generated_report_id"], name: "index_downloaded_reports_on_user_id_and_generated_report_id"
    t.index ["user_id"], name: "index_downloaded_reports_on_user_id"
  end

  create_table "e_intervention_admin_organizations", force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "organization_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["organization_id"], name: "index_e_intervention_admin_organizations_on_organization_id"
    t.index ["user_id"], name: "index_e_intervention_admin_organizations_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "name", default: ""
    t.bigint "day_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["day_id"], name: "index_events_on_day_id"
  end

  create_table "generated_reports", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "report_template_id"
    t.uuid "user_session_id"
    t.string "report_for", default: "third_party", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "participant_id"
    t.index ["participant_id"], name: "index_generated_reports_on_participant_id"
    t.index ["report_for"], name: "index_generated_reports_on_report_for"
    t.index ["report_template_id"], name: "index_generated_reports_on_report_template_id"
    t.index ["user_session_id"], name: "index_generated_reports_on_user_session_id"
  end

  create_table "generated_reports_third_party_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "generated_report_id"
    t.uuid "third_party_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["generated_report_id"], name: "index_reports_third_party_users_on_reports_id"
    t.index ["third_party_id"], name: "index_third_party_users_reports_on_reports_id"
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at", unique: true
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "google_languages", force: :cascade do |t|
    t.string "language_code"
    t.string "language_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "google_tts_language_id"
    t.index ["google_tts_language_id"], name: "index_google_languages_on_google_tts_language_id"
  end

  create_table "google_tts_languages", force: :cascade do |t|
    t.string "language_name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "google_tts_voices", force: :cascade do |t|
    t.integer "google_tts_language_id"
    t.string "voice_label"
    t.string "voice_type"
    t.string "language_code"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["google_tts_language_id"], name: "index_google_tts_voices_on_google_tts_language_id"
  end

  create_table "health_clinic_invitations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "health_clinic_id"
    t.string "invitation_token"
    t.datetime "accepted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["health_clinic_id"], name: "index_health_clinic_invitations_on_health_clinic_id"
    t.index ["invitation_token"], name: "index_health_clinic_invitations_on_invitation_token"
    t.index ["user_id"], name: "index_health_clinic_invitations_on_user_id"
  end

  create_table "health_clinics", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "health_system_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_health_clinics_on_deleted_at"
    t.index ["health_system_id"], name: "index_health_clinics_on_health_system_id"
    t.index ["name", "health_system_id"], name: "index_health_clinics_on_name_and_health_system_id", unique: true
  end

  create_table "health_system_invitations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "health_system_id"
    t.string "invitation_token"
    t.datetime "accepted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["health_system_id"], name: "index_health_system_invitations_on_health_system_id"
    t.index ["invitation_token"], name: "index_health_system_invitations_on_invitation_token"
    t.index ["user_id"], name: "index_health_system_invitations_on_user_id"
  end

  create_table "health_systems", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "organization_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_health_systems_on_deleted_at"
    t.index ["name", "organization_id"], name: "index_health_systems_on_name_and_organization_id", unique: true
    t.index ["organization_id"], name: "index_health_systems_on_organization_id"
  end

  create_table "hfhs_patient_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "patient_id_ciphertext"
    t.string "first_name_ciphertext", null: false
    t.string "last_name_ciphertext", null: false
    t.string "dob_ciphertext", null: false
    t.string "sex_ciphertext", null: false
    t.string "visit_id_ciphertext", default: ""
    t.string "zip_code_ciphertext", default: "", null: false
    t.string "patient_id_bidx"
    t.string "first_name_bidx"
    t.string "last_name_bidx"
    t.string "dob_bidx"
    t.string "sex_bidx"
    t.string "zip_code_bidx"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "phone_number_ciphertext"
    t.string "phone_number_bidx"
    t.string "phone_type_ciphertext"
    t.string "phone_type_bidx"
    t.index ["first_name_bidx", "last_name_bidx", "dob_bidx", "sex_bidx", "zip_code_bidx"], name: "index_basic_hfhs_patient_details"
    t.index ["patient_id_bidx"], name: "index_hfhs_patient_details_on_patient_id_bidx"
  end

  create_table "intervention_accesses", force: :cascade do |t|
    t.uuid "intervention_id", null: false
    t.string "email", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["intervention_id"], name: "index_intervention_accesses_on_intervention_id"
  end

  create_table "intervention_locations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "intervention_id"
    t.uuid "clinic_location_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["clinic_location_id"], name: "index_intervention_locations_on_clinic_location_id"
    t.index ["intervention_id"], name: "index_intervention_locations_on_intervention_id"
  end

  create_table "intervention_navigators", force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "intervention_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["intervention_id"], name: "index_intervention_navigators_on_intervention_id"
    t.index ["user_id"], name: "index_intervention_navigators_on_user_id"
  end

  create_table "interventions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "user_id", null: false
    t.datetime "published_at"
    t.string "status", default: "draft"
    t.string "shared_to", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "organization_id"
    t.bigint "google_language_id", null: false
    t.boolean "from_deleted_organization", default: false, null: false
    t.string "type", default: "Intervention", null: false
    t.string "additional_text", default: ""
    t.jsonb "original_text"
    t.string "cat_mh_application_id"
    t.string "cat_mh_organization_id"
    t.integer "cat_mh_pool"
    t.integer "created_cat_mh_session_count", default: 0
    t.boolean "is_access_revoked", default: true
    t.string "license_type", default: "limited"
    t.boolean "is_hidden", default: false
    t.integer "sessions_count"
    t.boolean "quick_exit", default: false
    t.boolean "live_chat_enabled", default: false, null: false
    t.integer "current_narrator", default: 0
    t.uuid "current_editor_id"
    t.integer "conversations_count"
    t.boolean "hfhs_access", default: false
    t.boolean "starred", default: false, null: false
    t.index ["current_editor_id"], name: "index_interventions_on_current_editor_id"
    t.index ["google_language_id"], name: "index_interventions_on_google_language_id"
    t.index ["name", "user_id"], name: "index_interventions_on_name_and_user_id", using: :gin
    t.index ["name"], name: "index_interventions_on_name"
    t.index ["organization_id"], name: "index_interventions_on_organization_id"
    t.index ["shared_to"], name: "index_interventions_on_shared_to"
    t.index ["status"], name: "index_interventions_on_status"
    t.index ["user_id"], name: "index_interventions_on_user_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.uuid "invitable_id"
    t.string "invitable_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "email_ciphertext"
    t.string "email_bidx"
    t.uuid "health_clinic_id"
    t.index ["email_bidx"], name: "index_invitations_on_email_bidx"
    t.index ["health_clinic_id"], name: "index_invitations_on_health_clinic_id"
  end

  create_table "live_chat_conversations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "intervention_id", null: false
    t.string "current_screen_title"
    t.string "participant_location_history", default: [], null: false, array: true
    t.datetime "archived_at"
  end

  create_table "live_chat_interlocutors", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "conversation_id", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "live_chat_links", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "url", null: false
    t.string "display_name", default: "", null: false
    t.uuid "navigator_setup_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "link_for", default: 0
  end

  create_table "live_chat_messages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "content_ciphertext", default: "", null: false
    t.uuid "conversation_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "live_chat_interlocutor_id", null: false
    t.boolean "is_read", default: false, null: false
  end

  create_table "live_chat_navigator_setups", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "no_navigator_available_message", default: "Welcome to our in-session support!", null: false
    t.string "contact_email", default: "", null: false
    t.uuid "intervention_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "contact_message", default: "You can contact us directly by using details below"
  end

  create_table "live_chat_summoning_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "intervention_id", null: false
    t.datetime "unlock_next_call_out_time"
    t.boolean "participant_handled", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["intervention_id"], name: "index_live_chat_summoning_users_on_intervention_id"
    t.index ["user_id"], name: "index_live_chat_summoning_users_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.string "status", default: "new", null: false
    t.datetime "schedule_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "phone_ciphertext"
    t.string "attachment_url"
  end

  create_table "navigator_invitations", force: :cascade do |t|
    t.text "email_ciphertext"
    t.string "email_bidx"
    t.uuid "intervention_id"
    t.datetime "accepted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email_bidx"], name: "index_navigator_invitations_on_email_bidx"
    t.index ["intervention_id"], name: "index_navigator_invitations_on_intervention_id"
  end

  create_table "notifications", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "notifiable_type", null: false
    t.uuid "notifiable_id", null: false
    t.boolean "is_read", default: false
    t.jsonb "data"
    t.uuid "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "event", default: 0, null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri"
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.index ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "organization_invitations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "organization_id"
    t.string "invitation_token"
    t.datetime "accepted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["invitation_token"], name: "index_organization_invitations_on_invitation_token"
    t.index ["organization_id"], name: "index_organization_invitations_on_organization_id"
    t.index ["user_id"], name: "index_organization_invitations_on_user_id"
  end

  create_table "organizations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "phones", force: :cascade do |t|
    t.uuid "user_id"
    t.string "iso", null: false
    t.string "prefix", null: false
    t.string "confirmation_code"
    t.boolean "confirmed", default: false, null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "number_ciphertext"
    t.uuid "navigator_setup_id"
    t.string "communication_way"
    t.index ["user_id"], name: "index_phones_on_user_id"
  end

  create_table "question_groups", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "session_id", null: false
    t.string "title", null: false
    t.bigint "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "type"
    t.integer "questions_count", default: 0
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
    t.jsonb "formulas"
    t.jsonb "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "original_text"
    t.index ["question_group_id"], name: "index_questions_on_question_group_id"
    t.index ["title"], name: "index_questions_on_title"
    t.index ["type", "question_group_id", "title"], name: "index_questions_on_type_and_question_group_id_and_title", using: :gin
    t.index ["type", "title"], name: "index_questions_on_type_and_title", using: :gin
    t.index ["type"], name: "index_questions_on_type"
  end

  create_table "report_template_section_variants", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "report_template_section_id", null: false
    t.boolean "preview", default: false, null: false
    t.string "formula_match"
    t.string "title"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "original_text"
    t.integer "position", default: 0, null: false
    t.index ["report_template_section_id", "preview"], name: "index_variants_on_preview_and_section_id"
    t.index ["report_template_section_id"], name: "index_variants_on_section_id"
  end

  create_table "report_template_sections", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "formula"
    t.uuid "report_template_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "position", default: 0, null: false
    t.index ["report_template_id"], name: "index_report_template_sections_on_report_template_id"
  end

  create_table "report_templates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "report_for", default: "third_party", null: false
    t.uuid "session_id"
    t.text "summary"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "original_text"
    t.boolean "is_duplicated_from_other_session", default: false, null: false
    t.boolean "duplicated_from_other_session_warning_dismissed", default: false, null: false
    t.index ["report_for"], name: "index_report_templates_on_report_for"
    t.index ["session_id", "name"], name: "index_report_templates_on_session_id_and_name", unique: true
    t.index ["session_id"], name: "index_report_templates_on_session_id"
  end

  create_table "reporting_dashboards", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "organization_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["organization_id"], name: "index_reporting_dashboards_on_organization_id"
  end

  create_table "sessions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "intervention_id", null: false
    t.jsonb "settings"
    t.integer "position", default: 0, null: false
    t.string "name", null: false
    t.string "schedule", default: "after_fill"
    t.integer "schedule_payload"
    t.date "schedule_at"
    t.jsonb "formulas"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "report_templates_count", default: 0
    t.integer "sms_plans_count", default: 0, null: false
    t.integer "last_report_template_number", default: 0
    t.string "variable"
    t.string "days_after_date_variable_name"
    t.bigint "google_tts_voice_id"
    t.string "type", default: "Session::Classic", null: false
    t.jsonb "original_text"
    t.bigint "cat_mh_language_id"
    t.bigint "cat_mh_time_frame_id"
    t.bigint "cat_mh_population_id"
    t.integer "estimated_time"
    t.integer "current_narrator", default: 0
    t.boolean "multiple_fill", default: false, null: false
    t.boolean "autofinish_enabled", default: true, null: false
    t.integer "autofinish_delay", default: 24, null: false
    t.index ["cat_mh_language_id"], name: "index_sessions_on_cat_mh_language_id"
    t.index ["cat_mh_population_id"], name: "index_sessions_on_cat_mh_population_id"
    t.index ["cat_mh_time_frame_id"], name: "index_sessions_on_cat_mh_time_frame_id"
    t.index ["google_tts_voice_id"], name: "index_sessions_on_google_tts_voice_id"
    t.index ["intervention_id", "name"], name: "index_sessions_on_intervention_id_and_name", using: :gin
    t.index ["intervention_id"], name: "index_sessions_on_intervention_id"
    t.index ["name"], name: "index_sessions_on_name"
    t.index ["schedule"], name: "index_sessions_on_schedule"
    t.index ["schedule_at"], name: "index_sessions_on_schedule_at"
  end

  create_table "short_links", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "linkable_type", null: false
    t.uuid "linkable_id", null: false
    t.uuid "health_clinic_id"
    t.string "name", null: false
    t.index ["health_clinic_id"], name: "index_short_links_on_health_clinic_id"
    t.index ["linkable_type", "linkable_id"], name: "index_short_links_on_linkable"
    t.index ["name"], name: "index_short_links_on_name", unique: true
  end

  create_table "sms_plan_variants", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "sms_plan_id"
    t.string "formula_match"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "original_text"
    t.integer "position", default: 0, null: false
    t.index ["sms_plan_id"], name: "index_sms_plan_variants_on_sms_plan_id"
  end

  create_table "sms_plans", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "session_id"
    t.string "name", null: false
    t.string "schedule", null: false
    t.integer "schedule_payload", default: 0
    t.string "frequency", default: "once", null: false
    t.datetime "end_at"
    t.string "formula"
    t.text "no_formula_text"
    t.boolean "is_used_formula", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "original_text"
    t.string "type", default: "SmsPlan::Normal", null: false
    t.boolean "include_first_name"
    t.boolean "include_last_name"
    t.boolean "include_phone_number"
    t.boolean "include_email"
    t.index ["session_id"], name: "index_sms_plans_on_session_id"
  end

  create_table "team_invitations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "team_id"
    t.string "invitation_token"
    t.datetime "accepted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["accepted_at"], name: "index_team_invitations_on_accepted_at"
    t.index ["invitation_token"], name: "index_team_invitations_on_invitation_token", unique: true
    t.index ["user_id", "team_id"], name: "unique_not_accepted_team_invitation", unique: true, where: "(accepted_at IS NULL)"
  end

  create_table "teams", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "team_admin_id"
    t.index ["name"], name: "index_teams_on_name", unique: true
    t.index ["team_admin_id"], name: "index_teams_on_team_admin_id"
  end

  create_table "tests", force: :cascade do |t|
    t.uuid "session_id"
    t.bigint "cat_mh_test_type_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cat_mh_test_type_id"], name: "index_tests_on_cat_mh_test_type_id"
    t.index ["session_id"], name: "index_tests_on_session_id"
  end

  create_table "time_ranges", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.integer "from", null: false
    t.integer "to", null: false
    t.integer "position", default: 0, null: false
    t.string "label", null: false
    t.boolean "default", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "user_health_clinics", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "health_clinic_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["health_clinic_id"], name: "index_user_health_clinics_on_health_clinic_id"
    t.index ["user_id"], name: "index_user_health_clinics_on_user_id"
  end

  create_table "user_interventions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "intervention_id"
    t.uuid "health_clinic_id"
    t.integer "completed_sessions", default: 0, null: false
    t.string "status", default: "ready_to_start"
    t.datetime "finished_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["health_clinic_id"], name: "index_user_interventions_on_health_clinic_id"
    t.index ["intervention_id"], name: "index_user_interventions_on_intervention_id"
    t.index ["user_id"], name: "index_user_interventions_on_user_id"
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
    t.datetime "finished_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_answer_at"
    t.string "timeout_job_id"
    t.uuid "name_audio_id"
    t.uuid "health_clinic_id"
    t.string "type", default: "UserSession::Classic", null: false
    t.integer "cat_interview_id"
    t.string "identifier"
    t.string "signature"
    t.string "jsession_id"
    t.string "awselb"
    t.uuid "user_intervention_id", null: false
    t.datetime "scheduled_at"
    t.boolean "quick_exit", default: false
    t.integer "number_of_attempts", default: 1
    t.boolean "started", default: false, null: false
    t.index ["health_clinic_id"], name: "index_user_sessions_on_health_clinic_id"
    t.index ["name_audio_id"], name: "index_user_sessions_on_name_audio_id"
    t.index ["session_id"], name: "index_user_sessions_on_session_id"
    t.index ["user_id", "session_id", "health_clinic_id"], name: "index_user_session_on_u_id_and_s_id_and_hc_id", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
    t.index ["user_intervention_id"], name: "index_user_sessions_on_user_intervention_id"
  end

  create_table "user_verification_codes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "code", null: false
    t.boolean "confirmed", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_user_verification_codes_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "provider", default: "email", null: false
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
    t.boolean "sms_notification", default: true, null: false
    t.uuid "team_id"
    t.uuid "preview_session_id"
    t.boolean "email_notification", default: true, null: false
    t.boolean "feedback_completed", default: false, null: false
    t.string "description", default: ""
    t.uuid "organizable_id"
    t.text "email_ciphertext"
    t.text "first_name_ciphertext"
    t.text "last_name_ciphertext"
    t.text "uid_ciphertext"
    t.string "email_bidx"
    t.string "uid_bidx"
    t.string "organizable_type"
    t.boolean "terms", default: false, null: false
    t.datetime "terms_confirmed_at"
    t.boolean "quick_exit_enabled", default: false, null: false
    t.boolean "online", default: false, null: false
    t.uuid "hfhs_patient_detail_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email_bidx"], name: "index_users_on_email_bidx", unique: true
    t.index ["hfhs_patient_detail_id"], name: "index_users_on_hfhs_patient_detail_id"
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by_type_and_invited_by_id"
    t.index ["organizable_id", "organizable_type"], name: "index_users_on_organizable_id_and_organizable_type"
    t.index ["organizable_id"], name: "index_users_on_organizable_id"
    t.index ["preview_session_id"], name: "index_users_on_preview_session_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["roles"], name: "index_users_on_roles", using: :gin
    t.index ["team_id"], name: "index_users_on_team_id"
    t.index ["uid_bidx"], name: "index_users_on_uid_bidx", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "alert_phones", "phones"
  add_foreign_key "alert_phones", "sms_plans"
  add_foreign_key "answers", "questions"
  add_foreign_key "answers", "user_sessions"
  add_foreign_key "cat_mh_google_tts_voices", "cat_mh_languages"
  add_foreign_key "cat_mh_google_tts_voices", "google_tts_voices"
  add_foreign_key "cat_mh_test_type_languages", "cat_mh_languages"
  add_foreign_key "cat_mh_test_type_languages", "cat_mh_test_types"
  add_foreign_key "cat_mh_test_type_time_frames", "cat_mh_test_types"
  add_foreign_key "cat_mh_test_type_time_frames", "cat_mh_time_frames"
  add_foreign_key "collaborators", "interventions"
  add_foreign_key "collaborators", "users"
  add_foreign_key "consumption_results", "days"
  add_foreign_key "days", "question_groups"
  add_foreign_key "days", "user_sessions"
  add_foreign_key "downloaded_reports", "generated_reports"
  add_foreign_key "downloaded_reports", "users"
  add_foreign_key "events", "days"
  add_foreign_key "google_languages", "google_tts_languages"
  add_foreign_key "intervention_accesses", "interventions"
  add_foreign_key "interventions", "google_languages"
  add_foreign_key "interventions", "organizations"
  add_foreign_key "interventions", "users"
  add_foreign_key "interventions", "users", column: "current_editor_id"
  add_foreign_key "invitations", "health_clinics"
  add_foreign_key "live_chat_conversations", "interventions"
  add_foreign_key "live_chat_interlocutors", "live_chat_conversations", column: "conversation_id"
  add_foreign_key "live_chat_interlocutors", "users"
  add_foreign_key "live_chat_links", "live_chat_navigator_setups", column: "navigator_setup_id"
  add_foreign_key "live_chat_messages", "live_chat_conversations", column: "conversation_id"
  add_foreign_key "live_chat_messages", "live_chat_interlocutors"
  add_foreign_key "live_chat_navigator_setups", "interventions"
  add_foreign_key "live_chat_summoning_users", "interventions"
  add_foreign_key "live_chat_summoning_users", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "phones", "live_chat_navigator_setups", column: "navigator_setup_id"
  add_foreign_key "question_groups", "sessions"
  add_foreign_key "questions", "question_groups"
  add_foreign_key "sessions", "cat_mh_languages"
  add_foreign_key "sessions", "cat_mh_populations"
  add_foreign_key "sessions", "cat_mh_time_frames"
  add_foreign_key "sessions", "google_tts_voices"
  add_foreign_key "sessions", "interventions"
  add_foreign_key "user_log_requests", "users"
  add_foreign_key "user_sessions", "audios", column: "name_audio_id"
  add_foreign_key "user_sessions", "health_clinics"
  add_foreign_key "user_sessions", "sessions"
  add_foreign_key "user_sessions", "user_interventions"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "users", "hfhs_patient_details"
end
