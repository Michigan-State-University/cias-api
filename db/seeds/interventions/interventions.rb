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
  NUM_OF_USERS = 3
  INTERVENTIONS_PER_USER = 100
  SESSIONS_PER_INTERVENTION = 10
  QUESTION_GROUPS_PER_SESSION = 5
  QUESTIONS_PER_QUESTION_GROUP = 5
  ANSWERS_PER_QUESTION = 5

  INTERVENTION_STATUS = %w[draft published closed archived].freeze
  INTERVENTION_NAMES = ['Drugs intervention', 'Smoking intervention', 'Alcohol intervention'].freeze
  INTERVENTION_NAMES_DIRECTED = ['Husbands', 'Pregnant women', 'Underage teenagers'].freeze

  QUESTIONS = [single_q, number_q, date_q].freeze

  CURRENT_TIME = Time.zone.now

  intervention_columns = %w[id name user_id status shared_to created_at updated_at google_language_id sessions_count]

  session_columns = %w[id intervention_id name variable created_at updated_at position settings schedule formulas type
                       google_tts_voice_id schedule_payload schedule_at estimated_time]

  question_group_columns = %w[id session_id title position created_at updated_at type questions_count]

  question_columns = %w[id type question_group_id settings position title subtitle narrator formulas body
                        created_at updated_at original_text]

  user_intervention_columns = %w[id user_id intervention_id completed_sessions status finished_at created_at updated_at]

  user_session_columns = %w[id user_id session_id finished_at created_at updated_at last_answer_at type user_intervention_id]

  file = Rails.root.join('tmp/db_seed.csv')
  data_handler = DBHandler.new(file)

  NUM_OF_USERS.times do |index|
    @user = create(
      :user,
      email: "#{Time.current.to_i}_#{SecureRandom.hex(10)}@researcher.true",
      password: 'Qwerty!@#456',
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      roles: %w[researcher participant]
    )
    @user.skip_confirmation!
    @user.save!
    p "#{index + 1}/#{NUM_OF_USERS} users created"
  end

  user_ids = User.ids
  data_handler.new_table('interventions', intervention_columns)
  index = 0
  max_index = user_ids.count * INTERVENTIONS_PER_USER
  data = []
  user_ids.each do |user_id|
    INTERVENTIONS_PER_USER.times do
      fake_uuid = Faker::Internet.unique.uuid
      intervention_name = INTERVENTION_NAMES.sample + " for #{INTERVENTION_NAMES_DIRECTED.sample}"
      data.append(
        [fake_uuid, intervention_name, user_id, INTERVENTION_STATUS.sample,
         'anyone', CURRENT_TIME.to_s, CURRENT_TIME.to_s, 27, SESSIONS_PER_INTERVENTION]
      )
      p "#{index += 1}/#{max_index} interventions created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('sessions', session_columns)
  intervention_ids = Intervention.ids
  session_settings = { 'narrator' => { 'voice' => true, 'animation' => true } }.to_json
  index = 0
  max_index = intervention_ids.count * SESSIONS_PER_INTERVENTION
  data = []
  intervention_ids.each do |intervention_id|
    position_counter = 0
    SESSIONS_PER_INTERVENTION.times do
      fake_uuid = Faker::Internet.unique.uuid

      data.append(
        [fake_uuid, intervention_id, 'Pregnancy 1st Trimester', 's123', CURRENT_TIME.to_s, CURRENT_TIME.to_s, position_counter,
         session_settings, 'after_fill', [{ 'payload' => '', 'patterns' => [] }.to_json], 'Session::Classic',
         144, 1, CURRENT_TIME.to_s, 3000]
      )

      position_counter += 1
      p "#{index += 1}/#{max_index} sessions created"
    end
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('question_groups', question_group_columns)
  session_ids = Session.ids
  index = 0
  max_index = session_ids.count * QUESTION_GROUPS_PER_SESSION
  data = []
  session_ids.each do |session_id|
    position_counter = 0
    (QUESTION_GROUPS_PER_SESSION - 1).times do
      fake_uuid = Faker::Internet.unique.uuid
      data.append(
        [fake_uuid, session_id, "Group #{position_counter + 1}", position_counter, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
         'QuestionGroup::Plain', QUESTIONS_PER_QUESTION_GROUP]
      )
      position_counter += 1
      p "#{index += 1}/#{max_index} question groups created"
    end
    data.append(
      [Faker::Internet.unique.uuid, session_id, 'Finish Group', 999_999, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
       'QuestionGroup::Finish', 1]
    )
    p "#{index += 1}/#{max_index} question groups created"
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('questions', question_columns)
  question_group_ids = QuestionGroup.ids
  index = 0
  max_index = question_group_ids.count * QUESTIONS_PER_QUESTION_GROUP
  data = []
  question_group_ids.each do |question_group_id|
    position = 0
    (QUESTIONS_PER_QUESTION_GROUP - 1).times do
      fake_uuid = Faker::Internet.unique.uuid
      question = QUESTIONS.sample

      data.append(
        [fake_uuid, question.type, question_group_id, question.settings, position, question.title, question.subtitle,
         question.narrator, question.formulas, question.body, CURRENT_TIME.to_s, CURRENT_TIME.to_s, question.original_text]
      )

      position += 1
      p "#{index += 1}/#{max_index} questions created"
    end
    next unless QuestionGroup.find_by(id: question_group_id).title == 'Finish Group'

    data.append(
      [Faker::Internet.unique.uuid, final_q.type, question_group_id, final_q.settings, position, final_q.title, final_q.subtitle,
       final_q.narrator, final_q.formulas, final_q.body, CURRENT_TIME.to_s, CURRENT_TIME.to_s, final_q.original_text]
    )
    p "#{index += 1}/#{max_index} questions created"
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('user_interventions', user_intervention_columns)
  index = 0
  max_index = intervention_ids.count
  data = []
  intervention_ids.each do |intervention_id|
    fake_uuid = Faker::Internet.unique.uuid

    data.append(
      [fake_uuid, Intervention.find_by(id: intervention_id).user.id, intervention_id, 3, 'completed',
       CURRENT_TIME.to_s, CURRENT_TIME.to_s, CURRENT_TIME.to_s]
    )
    p "#{index += 1}/#{max_index} user interventions created"
  end
  data_handler.save_data_to_db(data)

  data_handler.new_table('user_sessions', user_session_columns)
  user_interventions_ids = UserIntervention.ids[0..ANSWERS_PER_QUESTION]
  index = 0
  max_index = user_ids.count * ANSWERS_PER_QUESTION
  data = []
  user_ids.each do |user_id|
    session_ids[0..ANSWERS_PER_QUESTION - 1].zip(user_interventions_ids).each do |session_id, user_intervention_id|
      @user_intervention_id ||= user_intervention_id
      fake_uuid = Faker::Internet.unique.uuid

      data.append(
        [fake_uuid, user_id, session_id, CURRENT_TIME.to_s, CURRENT_TIME.to_s, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
         'UserSession::Classic', @user_intervention_id]
      )
      p "#{index += 1}/#{max_index} user sessions created"
    end
  end
  data_handler.save_data_to_db(data)

  index = 0
  max_index = Question.count * ANSWERS_PER_QUESTION
  Question.find_each do |question|
    UserSession.limit(ANSWERS_PER_QUESTION).find_each do |user_session|
      case question.type.demodulize
      when 'Single'
        type = :answer_single
      when 'Number'
        type = :answer_number
      when 'Date'
        type = :answer_date
      else
        next
      end
      create(type, question: question, user_session: user_session, next_session_id: nil, created_at: CURRENT_TIME, updated_at: CURRENT_TIME)
      p "#{index += 1}/#{max_index} answers created"
    end
  end

  p "Example user email: #{@user.email}"
  p 'Example user password: Qwerty!@#456'
  p "Example user verification code: verification_code_#{@user.uid}"
end
# rubocop:enable Metrics/ClassLength, Rails/Output
