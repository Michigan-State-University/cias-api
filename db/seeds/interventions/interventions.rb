# frozen_string_literal: true

require 'factory_bot_rails'
require 'faker'
require 'json'

require_relative './/db_handler'
require_relative './/question_data_handler'

NUM_OF_USERS = 3
INTERVENTIONS_PER_USER = 3
SESSIONS_PER_INTERVENTION = 3
QUESTION_GROUPS_PER_SESSION = 3
QUESTIONS_PER_QUESTION_GROUP = 3
ANSWERS_PER_QUESTION = 3

INTERVENTION_STATUS = %w[draft published closed archived].freeze
INTERVENTION_NAMES = ['Drugs intervention', 'Smoking intervention', 'Alcohol intervention'].freeze
INTERVENTION_NAMES_DIRECTED = ['Husbands', 'Pregnant women', 'Underage teenagers'].freeze

QUESTIONS = [single, number].freeze

CURRENT_TIME = Time.zone.now

intervention_columns = %w[id name user_id status shared_to created_at updated_at google_language_id sessions_count]

session_columns = %w[id intervention_id name variable created_at updated_at position settings schedule formulas type
                     google_tts_voice_id schedule_payload schedule_at estimated_time]

question_group_columns = %w[id session_id title position created_at updated_at type questions_count]

question_columns = %w[id type question_group_id settings position title subtitle narrator formulas body
                      created_at updated_at original_text]

file = Rails.root.join('tmp', 'csv', 'test.csv')
intervention_handler = DBHandler.new(file, intervention_columns)
session_handler = DBHandler.new(file, session_columns)
question_group_handler = DBHandler.new(file, question_group_columns)
question_handler = DBHandler.new(file, question_columns)

NUM_OF_USERS.times do
  include FactoryBot::Syntax::Methods
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
end

user_ids = User.ids
intervention_handler.clear_file
user_ids.each do |user_id|
  INTERVENTIONS_PER_USER.times do
    fake_uuid = Faker::Internet.unique.uuid
    intervention_name = INTERVENTION_NAMES.sample + " for #{INTERVENTION_NAMES_DIRECTED.sample}"
    data = [
      fake_uuid, intervention_name, user_id, INTERVENTION_STATUS.sample,
      'anyone', CURRENT_TIME.to_s, CURRENT_TIME.to_s, 27, SESSIONS_PER_INTERVENTION
    ]

    intervention_handler.add_data(data)
  end
end
intervention_handler.save_to_db('interventions')



intervention_ids = Intervention.ids
session_settings = { 'narrator' => { 'voice' => true, 'animation' => true } }.to_json

session_handler.clear_file
intervention_ids.each do |intervention_id|
  index = 0
  SESSIONS_PER_INTERVENTION.times do
    fake_uuid = Faker::Internet.unique.uuid

    data = [
      fake_uuid, intervention_id, 'Pregnancy 1st Trimester', 's123', CURRENT_TIME.to_s, CURRENT_TIME.to_s, index,
      session_settings, 'after_fill', [{ 'payload' => '', 'patterns' => [] }.to_json], 'Session::Classic',
      144, 1, CURRENT_TIME.to_s, 3000
    ]

    session_handler.add_data(data)
    index += 1
  end
end
session_handler.save_to_db('sessions')


question_group_handler.clear_file
session_ids = Session.ids
session_ids.each do |session_id|
  index = 0
  QUESTION_GROUPS_PER_SESSION.times do
    fake_uuid = Faker::Internet.unique.uuid

    data = [
      fake_uuid, session_id, "Group #{index + 1}", index, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
      'QuestionGroup::Plain', QUESTIONS_PER_QUESTION_GROUP
      ]

    question_group_handler.add_data(data)
    index += 1
  end
  finish_group = [
    Faker::Internet.unique.uuid, session_id, 'Finish Group', 999_999, CURRENT_TIME.to_s, CURRENT_TIME.to_s,
    'QuestionGroup::Finish', 1
  ]
  question_group_handler.add_data(finish_group)
end
question_group_handler.save_to_db('question_groups')


question_handler.clear_file
question_group_ids = QuestionGroup.ids
question_group_ids.each do |question_group_id|
  position = 0
  QUESTIONS_PER_QUESTION_GROUP.times do
    fake_uuid = Faker::Internet.unique.uuid
    question = QUESTIONS.sample

    data = [
      fake_uuid, question.type, question_group_id, question.settings, position, 'Good title', 'Good subtitle',
      question.narrator, question.formulas, question.body, CURRENT_TIME.to_s, CURRENT_TIME.to_s, question.original_text
    ]
    question_handler.add_data(data)
    position += 1
  end
  next unless position == QUESTIONS_PER_QUESTION_GROUP

  final_question = [
    Faker::Internet.unique.uuid, final.type, question_group_id, final.settings, position, 'Final title', 'Final subtitle',
    final.narrator, final.formulas, final.body, CURRENT_TIME.to_s, CURRENT_TIME.to_s, final.original_text
  ]
  question_handler.add_data(final_question)
end
question_handler.save_to_db('questions')



=begin
  interventions_number = rand(8..MAX_INTERVENTIONS_PER_USER)

  (1..interventions_number).each do
    intervention_name = INTERVENTION_NAMES.sample
    intervention_name += " for #{INTERVENTION_NAMES_DIRECTED.sample}" if rand(0..1) == 1
    intervention = create(
      :intervention,
      user: @user,
      name: intervention_name,
      status: INTERVENTION_STATUS.sample
    )
=end

=begin
    session_number = rand(8..MAX_SESSIONS_PER_INTERVENTION)

    (1..session_number).each do
      @intervention_session = create(
        :session,
        name: 'Pregnancy 1st Trimester',
        variable: Faker::Company.unique.name,
        intervention: intervention
      )

      question_group_number = rand(2..MAX_QUESTION_GROUPS_PER_SESSION)

      (1..question_group_number).each do
        question_group = create(
          :question_group,
          session: @intervention_session
        )

        question_number = rand(2..MAX_QUESTIONS_PER_QUESTION_GROUP)

        (1..question_number).each do
          generate_question.question_group = question_group
          question = generate_question.random
          answer_number = rand(2..MAX_ANSWERS_PER_QUESTION)

          (1..answer_number).each do
            create(
              :answer,
              question: question,
              type: "Answer::#{question.class.name.to_s.demodulize}",
              user_session: UserSession.offset(rand(UserSession.count)).first,
              body:
                {
                  data: [
                    {
                      var: Faker::Lorem.word,
                      value: '1'
                    }
                  ]
                }
            )
          end
        end
      end
    end
=end

  #   rand_session = Session.offset(rand(Session.count)).first
  #   user_intervention = create(
  #     :user_intervention,
  #     user: @user,
  #     intervention: rand_session.intervention
  #   )
  #
  #   create(
  #     :user_session,
  #     user: @user,
  #     session: rand_session,
  #     user_intervention: user_intervention
  #   )

puts "Example user email: #{@user.email}"
puts 'Example user password: Qwerty!@#456'
puts "Example user verification code: verification_code_#{@user.uid}"
