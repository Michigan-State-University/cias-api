# frozen_string_literal: true

require 'factory_bot_rails'
require 'faker'

require_relative './/db_handler'
require_relative './/question_data_handler'

# rubocop:disable Lint/TopLevelReturnWithArgument, Rails/Output
return puts '# Will not pollute database by fake data in production environment' if Rails.env.production?
# rubocop:enable Lint/TopLevelReturnWithArgument

# rubocop:disable Metrics/ClassLength
class SeedIntervention
  extend FactoryBot::Syntax::Methods

  NUM_OF_USERS = 10
  INTERVENTIONS_PER_USER = 100
  SESSIONS_PER_INTERVENTION = 10
  REPORTS_PER_SESSION = 20
  QUESTION_GROUPS_PER_SESSION = 5
  QUESTIONS_PER_QUESTION_GROUP = 5
  ANSWERS_PER_QUESTION = 1

  INTERVENTION_STATUS = %w[draft published closed archived].freeze
  INTERVENTION_NAMES = ['Drugs intervention', 'Smoking intervention', 'Alcohol intervention'].freeze
  INTERVENTION_NAMES_DIRECTED = ['Husbands', 'Pregnant women', 'Underage teenagers'].freeze

  QUESTIONS = [single_q, number_q, date_q, multi_q, free_q, currency_q].freeze

  CURRENT_TIME = Time.zone.now.to_s

  file = Rails.root.join('tmp/db_seed.csv')
  data_handler = DBHandler.new(file)

  (NUM_OF_USERS - 1).times do |index|
    create_user(%w[participant third_party])
    p "#{index + 1}/#{NUM_OF_USERS} users created"
  end

  researcher = create_user(%w[researcher admin])
  p "#{NUM_OF_USERS}/#{NUM_OF_USERS} users created"

  researcher_ids = User.researchers.ids
  data_handler.new_table('interventions', Intervention.column_names)
  index = 0
  max_index = researcher_ids.count * INTERVENTIONS_PER_USER

  intervention_name = INTERVENTION_NAMES.sample + " for #{INTERVENTION_NAMES_DIRECTED.sample}"
  published_at = CURRENT_TIME
  status = INTERVENTION_STATUS.sample
  shared_to = 'anyone'
  created_at = CURRENT_TIME
  updated_at = CURRENT_TIME
  organization_id = nil
  google_language_id = 27
  from_deleted_organization = false
  type = 'Intervention'
  additional_text = 'Eat your veggies!'
  original_text = nil
  cat_mh_application_id = nil
  cat_mh_organization_id = nil
  cat_mh_pool = nil
  created_cat_mh_session_count = 0
  is_access_revoked = true
  license_type = 'limited'
  is_hidden = false
  sessions_count = SESSIONS_PER_INTERVENTION
  quick_exit = false

  researcher_ids.each do |researcher_id|
    INTERVENTIONS_PER_USER.times do
      data_handler.store_data(
        [intervention_name, researcher_id, published_at, status, shared_to, created_at, updated_at, organization_id,
         google_language_id, from_deleted_organization, type, additional_text, original_text, cat_mh_application_id,
         cat_mh_organization_id, cat_mh_pool, created_cat_mh_session_count, is_access_revoked, license_type, is_hidden,
         sessions_count, quick_exit]
      )
      p "#{index += 1}/#{max_index} interventions created"
    end
  end
  data_handler.save_data_to_db

  data_handler.new_table('sessions', Session.column_names)
  intervention_ids = Intervention.ids
  session_settings = { 'narrator' => { 'voice' => true, 'animation' => true } }.to_json
  session_formulas = [{ 'payload' => '', 'patterns' => [] }.to_json]
  index = 0
  max_index = intervention_ids.count * SESSIONS_PER_INTERVENTION
  data = []
  intervention_ids.each do |intervention_id|
    position_counter = 0
    SESSIONS_PER_INTERVENTION.times do
      fake_uuid = Faker::Internet.unique.uuid

      data.append(
        [fake_uuid, intervention_id, session_settings, position_counter, 'Pregnancy 1st Trimester', 'after_fill', 1,
         CURRENT_TIME, session_formulas, CURRENT_TIME, CURRENT_TIME, 0, 0, '0', 's123', nil, 144,
         'Session::Classic', nil, nil, nil, nil, 3000]
      )

      position_counter += 1
      p "#{index += 1}/#{max_index} sessions created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('report_templates', ReportTemplate.column_names)
  session_ids = Session.ids
  index = 0
  max_index = session_ids.count
  data = []
  position = ReportTemplate.count
  session_ids.each do |session_id|
    next unless ReportTemplate.where('name = ? AND session_id = ?', "Report #{position}", session_id).empty?

    fake_uuid = Faker::Internet.unique.uuid
    if position.even?
      data.append(
        [fake_uuid, "Report #{position}", 'participant', session_id, 'Good job!', CURRENT_TIME, CURRENT_TIME,
         { 'name' => "Report #{position}", 'summary' => 'Good job!' }.to_json]
      )
    end

    if position.odd?
      data.append(
        [fake_uuid, "Report #{position}", 'third_party', session_id, 'Good job!', CURRENT_TIME, CURRENT_TIME,
         { 'name' => "Report #{position}", 'summary' => 'Good job!' }.to_json]
      )
    end

    position += 1
    p "#{index += 1}/#{max_index} report templates created"
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('question_groups', QuestionGroup.column_names)
  index = 0
  max_index = session_ids.count * QUESTION_GROUPS_PER_SESSION
  data = []
  session_ids.each do |session_id|
    position_counter = 0
    (QUESTION_GROUPS_PER_SESSION - 1).times do
      fake_uuid = Faker::Internet.unique.uuid
      data.append(
        [fake_uuid, session_id, "Group #{position_counter + 1}", position_counter, CURRENT_TIME, CURRENT_TIME,
         'QuestionGroup::Plain', QUESTIONS_PER_QUESTION_GROUP]
      )
      position_counter += 1
      p "#{index += 1}/#{max_index} question groups created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('questions', Question.column_names)
  question_group_ids = QuestionGroup.ids
  index = 0
  max_index = question_group_ids.count * QUESTIONS_PER_QUESTION_GROUP
  data = []
  question_group_ids.each do |question_group_id|
    position = 0
    QUESTIONS_PER_QUESTION_GROUP.times do
      fake_uuid = Faker::Internet.unique.uuid
      question = QUESTIONS.sample

      data.append(
        [fake_uuid, question.type, question_group_id, question.settings.to_s, position, question.title, question.subtitle,
         question.narrator.to_s, nil, question.formulas.to_s, question.body.to_s, CURRENT_TIME, CURRENT_TIME, question.original_text.to_s]
      )

      position += 1
      p "#{index += 1}/#{max_index} questions created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('user_interventions', UserIntervention.column_names)
  participants_ids = User.participants.ids
  index = 0
  max_index = intervention_ids.count * ANSWERS_PER_QUESTION
  data = []
  intervention_ids.each do |intervention_id|
    participants_ids[0..ANSWERS_PER_QUESTION - 1].each do |participant_id|
      fake_uuid = Faker::Internet.unique.uuid

      data.append(
        [fake_uuid, participant_id, intervention_id, nil, 3, 'completed',
         CURRENT_TIME, CURRENT_TIME, CURRENT_TIME]
      )
      p "#{index += 1}/#{max_index} user interventions created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('user_sessions', UserSession.column_names)
  user_interventions_ids = UserIntervention.ids
  index = 0
  max_index = participants_ids.count * session_ids.count
  data = []
  participants_ids.each do |participant_id|
    user_intervention_first_id = user_interventions_ids[0]
    session_ids.zip(user_interventions_ids).each do |session_id, user_intervention_id|
      user_intervention_id_fixed = user_intervention_id.nil? ? user_intervention_first_id : user_intervention_id
      fake_uuid = Faker::Internet.unique.uuid

      data.append(
        [fake_uuid, participant_id, session_id, CURRENT_TIME, CURRENT_TIME, CURRENT_TIME, CURRENT_TIME,
         nil, nil, nil, 'UserSession::Classic', nil, nil, nil, nil, nil, user_intervention_id_fixed, nil, false]
      )
      p "#{index += 1}/#{max_index} user sessions created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('generated_reports', GeneratedReport.column_names)
  data = []
  index = 0
  max_index = ReportTemplate.count * REPORTS_PER_SESSION
  ReportTemplate.all.zip(UserSession.all).each do |report_template, user_session|
    REPORTS_PER_SESSION.times do
      fake_uuid = Faker::Internet.unique.uuid
      data.append(
        [fake_uuid, "#{user_session.user.first_name} report", report_template.id,
         user_session.id, report_template.report_for,
         CURRENT_TIME, CURRENT_TIME, user_session.user.id]
      )
      p "#{index += 1}/#{max_index} generated reports created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('generated_reports_third_party_users', GeneratedReportsThirdPartyUser.column_names)
  data = []
  index = 0
  max_index = GeneratedReport.count / 2
  third_party_id = User.first.id
  GeneratedReport.all.each do |generated_report|
    next unless generated_report.report_for == 'third_party'

    fake_uuid = Faker::Internet.unique.uuid
    data.append(
      [fake_uuid, generated_report.id, third_party_id, CURRENT_TIME, CURRENT_TIME]
    )
    p "#{index += 1}/#{max_index} generated reports for third party created"
  end
  data_handler.save_data_to_db(data)

  index = 0
  max_index = Question.count * ANSWERS_PER_QUESTION
  Question.find_each do |question|
    UserSession.limit(ANSWERS_PER_QUESTION).each do |user_session_id|
      type = "Answer::#{question.type.demodulize}"
      create(:answer, id: Faker::Internet.unique.uuid, type: type, question_id: question.id, user_session_id: user_session_id,
             next_session_id: nil, created_at: CURRENT_TIME, updated_at: CURRENT_TIME, skipped: false)

      p "#{index += 1}/#{max_index} answers created"
    end
  end

  p "Example user email: #{researcher.email}"
  p 'Example user password: Password1!'
  p "Example user verification code: verification_code_#{researcher.uid}"

  private

  def self.create_user(roles)
    create(
      :user,
      :confirmed,
      email: "#{Time.current.to_i}_#{SecureRandom.hex(10)}@#{roles[0]}.true",
      password: 'Password1!',
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      roles: roles
    )
  end

end

# rubocop:enable Metrics/ClassLength, Rails/Output
