# frozen_string_literal: true

require 'factory_bot_rails'
require 'faker'

require_relative './/db_handler'

Dir[Rails.root.join('db/seeds/interventions/generators/*.rb').to_s].sort.each { |file| require file }

# rubocop:disable Lint/TopLevelReturnWithArgument, Rails/Output
return puts '# Will not pollute database by fake data in production environment' if Rails.env.production?
# rubocop:enable Lint/TopLevelReturnWithArgument

class SeedIntervention
  extend FactoryBot::Syntax::Methods
  NUM_OF_USERS = 10
  INTERVENTIONS_PER_USER = 100
  SESSIONS_PER_INTERVENTION = 10
  REPORTS_PER_SESSION = 20
  QUESTION_GROUPS_PER_SESSION = 5
  QUESTIONS_PER_QUESTION_GROUP = 5
  USER_INTER_PER_INTERVENTION = 50
  USER_SESSIONS_PER_USER_INTER = 50
  ANSWERS_PER_QUESTION = 50

  file = Rails.root.join('tmp/db_seed.csv')
  data_handler = DBHandler.new(file)

  # USER CREATION
  example_user = create_users(NUM_OF_USERS)
  # INTERVENTION CREATION
  create_interventions(data_handler, INTERVENTIONS_PER_USER, SESSIONS_PER_INTERVENTION)

  # SESSION CREATION
  create_sessions(data_handler, SESSIONS_PER_INTERVENTION)

  # REPORT TEMPLATE CREATION
  create_report_template(data_handler)

  # QUESTION GROUP CREATION
  create_question_group(data_handler, QUESTION_GROUPS_PER_SESSION)

  # QUESTION CREATION
  create_question(data_handler, QUESTION_GROUPS_PER_SESSION)

  # USER INTERVENTION CREATION
  create_user_interventions(data_handler, USER_INTER_PER_INTERVENTION)

  # USER SESSION CREATION
  create_user_sessions(data_handler, USER_SESSIONS_PER_USER_INTER)

  # GENERATED REPORT CREATION
  create_generated_reports(data_handler, REPORTS_PER_SESSION)

  # ANSWER CREATION
  create_answers(data_handler, ANSWERS_PER_QUESTION)

  p "Example user email: #{example_user.email}"
  p 'Example user password: Password1!'
  p "Example user verification code: verification_code_#{example_user.uid}"
end

# rubocop:enable Rails/Output
