# frozen_string_literal: true

require 'factory_bot_rails'
require 'faker'
require 'json'

require_relative './/db_handler'
require_relative './/question_data_handler'

class SeedIntervention
  extend FactoryBot::Syntax::Methods

  NUM_OF_USERS = 3
  INTERVENTIONS_PER_USER = 3
  SESSIONS_PER_INTERVENTION = 3
  QUESTION_GROUPS_PER_SESSION = 3
  QUESTIONS_PER_QUESTION_GROUP = 3
  ANSWERS_PER_QUESTION = 3

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

  answer_columns = %w[id type question_id created_at updated_at user_session_id skipped next_session_id]

  file = Rails.root.join('tmp/csv/test.csv')
  intervention_handler = DBHandler.new(file, intervention_columns)
  session_handler = DBHandler.new(file, session_columns)
  question_group_handler = DBHandler.new(file, question_group_columns)
  question_handler = DBHandler.new(file, question_columns)
  user_intervention_handler = DBHandler.new(file, user_intervention_columns)
  user_session_handler = DBHandler.new(file, user_session_columns)
  answer_handler = DBHandler.new(file, answer_columns)

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
    p "#{index}/#{NUM_OF_USERS} users created"
  end

  user_ids = User.ids
  intervention_handler.clear_file
  index = 1
  user_ids.each do |user_id|
    INTERVENTIONS_PER_USER.times do
      fake_uuid = Faker::Internet.unique.uuid
      intervention_name = INTERVENTION_NAMES.sample + " for #{INTERVENTION_NAMES_DIRECTED.sample}"
      data = [
        fake_uuid, intervention_name, user_id, INTERVENTION_STATUS.sample,
        'anyone', CURRENT_TIME.to_s, CURRENT_TIME.to_s, 27, SESSIONS_PER_INTERVENTION
      ]

      intervention_handler.add_data(data)
      p "#{index += 1}/#{User.count * INTERVENTIONS_PER_USER} interventions created"
    end
  end
  intervention_handler.save_to_db('interventions')

  intervention_ids = Intervention.ids
  session_settings = { 'narrator' => { 'voice' => true, 'animation' => true } }.to_json

  session_handler.clear_file
  index = 1
  intervention_ids.each do |intervention_id|
    position_counter = 0
    SESSIONS_PER_INTERVENTION.times do
      fake_uuid = Faker::Internet.unique.uuid

      data = [
        fake_uuid, intervention_id, 'Pregnancy 1st Trimester', 's123', CURRENT_TIME.to_s, CURRENT_TIME.to_s, position_counter,
        session_settings, 'after_fill', [{ 'payload' => '', 'patterns' => [] }.to_json], 'Session::Classic',
        144, 1, CURRENT_TIME.to_s, 3000
      ]

      session_handler.add_data(data)
      position_counter += 1
      p "#{index += 1}/#{Intervention.count * SESSIONS_PER_INTERVENTION} sessions created"
    end
  end
  session_handler.save_to_db('sessions')

  question_group_handler.clear_file
  session_ids = Session.ids
  index = 1
  session_ids.each do |session_id|
    position_counter = 0
    QUESTION_GROUPS_PER_SESSION.times do
      fake_uuid = Faker::Internet.unique.uuid

      data = [
        fake_uuid, session_id, "Group #{position_counter + 1}", position_counter, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
        'QuestionGroup::Plain', QUESTIONS_PER_QUESTION_GROUP
      ]

      question_group_handler.add_data(data)
      position_counter += 1
      p "#{index += 1}/#{Session.count * QUESTION_GROUPS_PER_SESSION} question groups created"
    end
    finish_group = [
      Faker::Internet.unique.uuid, session_id, 'Finish Group', 999_999, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
      'QuestionGroup::Finish', 1
    ]
    question_group_handler.add_data(finish_group)
    p "#{index += 1}/#{Session.count * QUESTION_GROUPS_PER_SESSION} question groups created"
  end
  question_group_handler.save_to_db('question_groups')

  question_handler.clear_file
  question_group_ids = QuestionGroup.ids
  index = 1
  question_group_ids.each do |question_group_id|
    position = 0
    QUESTIONS_PER_QUESTION_GROUP.times do
      fake_uuid = Faker::Internet.unique.uuid
      question = QUESTIONS.sample

      data = [
        fake_uuid, question.type, question_group_id, question.settings, position, question.title, question.subtitle,
        question.narrator, question.formulas, question.body, CURRENT_TIME.to_s, CURRENT_TIME.to_s, question.original_text
      ]
      question_handler.add_data(data)
      position += 1
      p "#{index += 1}/#{QuestionGroup.count * QUESTIONS_PER_QUESTION_GROUP} questions created"
    end
    next unless QuestionGroup.find_by(id: question_group_id).title == 'Finish Group'

    final_question = [
      Faker::Internet.unique.uuid, final_q.type, question_group_id, final_q.settings, position, 'Thanks for your input!', 'Final screen',
      final_q.narrator, final_q.formulas, final_q.body, CURRENT_TIME.to_s, CURRENT_TIME.to_s, final_q.original_text
    ]
    question_handler.add_data(final_question)
    p "#{index += 1}/#{QuestionGroup.count * QUESTIONS_PER_QUESTION_GROUP} questions created"
  end
  question_handler.save_to_db('questions')

  user_intervention_handler.clear_file
  intervention_ids.each do |intervention_id|
    fake_uuid = Faker::Internet.unique.uuid

    data = [
      fake_uuid, Intervention.find_by(id: intervention_id).user.id, intervention_id, 3, 'completed',
      CURRENT_TIME.to_s, CURRENT_TIME.to_s, CURRENT_TIME.to_s
    ]
    user_intervention_handler.add_data(data)
  end
  user_intervention_handler.save_to_db('user_interventions')

  user_session_handler.clear_file
  user_interventions_ids = UserIntervention.ids
  user_ids.each do |user_id|
    session_ids.zip(user_interventions_ids).each do |session_id, user_intervention_id|
      @user_intervention_id ||= user_intervention_id
      fake_uuid = Faker::Internet.unique.uuid

      data = [
        fake_uuid, user_id, session_id, CURRENT_TIME.to_s, CURRENT_TIME.to_s, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
        'UserSession::Classic', @user_intervention_id
      ]
      user_session_handler.add_data(data)
    end
  end
  user_session_handler.save_to_db('user_sessions')

  answer_handler.clear_file
  Question.find_each do |question|
    UserSession.find_each do |user_session|
      create(:answer, user_session: user_session, type: "Answer::#{question.type.demodulize}")
    end
  end

  p "Example user email: #{@user.email}"
  p 'Example user password: Qwerty!@#456'
  p "Example user verification code: verification_code_#{@user.uid}"
end
