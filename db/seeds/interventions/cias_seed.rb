# frozen_string_literal: true

require 'factory_bot_rails'
require 'faker'

NUM_OF_USERS = 10
INTERVENTIONS_PER_RESEARCHER = 10
SESSIONS_PER_INTERVENTION = 8
QUESTION_GROUPS_PER_SESSION = 20
QUESTIONS_PER_QUESTION_GROUP = 8
ANSWERS_PER_QUESTION = 10
REPORTS_PER_SESSION = 8 # Limited by number of participants.

INTERVENTION_STATUS = %w[draft published closed archived].freeze
INTERVENTION_NAMES = ['Drugs intervention', 'Smoking intervention', 'Alcohol intervention'].freeze
INTERVENTION_NAMES_DIRECTED = ['Husbands', 'Pregnant women', 'Underage teenagers'].freeze

QUESTION_TYPES = %i[question_feedback question_grid question_information question_multiple question_number question_single
                    question_free_response question_date question_currency question_name].freeze

CURRENT_TIME = Time.zone.now
# rubocop:disable Lint/TopLevelReturnWithArgument, Rails/Output
return puts '# Will not pollute database by fake data in production environment' if Rails.env.production?
# rubocop:enable Lint/TopLevelReturnWithArgument

class DBSeed
  extend FactoryBot::Syntax::Methods

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

  (NUM_OF_USERS - 1).times do |index|
    create_user(['participant'])
    p "#{index + 1}/#{NUM_OF_USERS} users created"
  end

  example_user = create_user(%w[researcher admin])
  p "#{NUM_OF_USERS}/#{NUM_OF_USERS} users created"

  researcher_index = 0
  researcher_index_max = INTERVENTIONS_PER_RESEARCHER * SESSIONS_PER_INTERVENTION * User.limit_to_roles('researcher').count *
                         QUESTION_GROUPS_PER_SESSION * QUESTIONS_PER_QUESTION_GROUP

  User.all.limit_to_roles('researcher').each do |researcher|
    create_list(:intervention, INTERVENTIONS_PER_RESEARCHER, user: researcher) do |intervention|
      intervention.status = INTERVENTION_STATUS.sample
      intervention.name = "#{INTERVENTION_NAMES.sample} for #{INTERVENTION_NAMES_DIRECTED.sample}"
      intervention.save!

      create_list(:session, SESSIONS_PER_INTERVENTION, intervention: intervention) do |session|
        session.name = Faker::Movies::HarryPotter.quote.capitalize
        session.save!

        create_list(:question_group, QUESTION_GROUPS_PER_SESSION, session_id: session.id) do |question_group|
          question_group.title = Faker::Music::Prince.song
          question_group.save!
          QUESTIONS_PER_QUESTION_GROUP.times do
            create(
              QUESTION_TYPES.sample,
              title: "<h1>#{Faker::TvShows::Simpsons.quote.capitalize}</h1>",
              subtitle: Faker::Marketing.buzzwords.capitalize,
              question_group_id: question_group.id
            )
            p "#{researcher_index += 1}/#{researcher_index_max} researcher data created"
          end
        end
        create(:report_template, :participant, session_id: session.id, summary: Faker::Movies::HowToTrainYourDragon.character)
      end
    end
  end

  participant_index = 0
  participant_index_max = User.limit_to_roles('participant').count * Question.count

  User.limit_to_roles('participant').pluck(:id).each do |participant_id|
    Intervention.includes({ sessions: { question_groups: :questions } }).find_each do |intervention|
      user_intervention = create(:user_intervention, :completed, user_id: participant_id, intervention_id: intervention.id)

      intervention.sessions.each do |session|
        create(:user_session, user_id: participant_id, session_id: session.id, user_intervention_id: user_intervention.id) do |user_session|
          user_session.save!

          session.question_groups.each do |question_group|
            question_group.questions.each do |question|
              p "#{participant_index += 1}/#{participant_index_max} participants data created"
              next if question.type == 'Question::Finish'

              create_list(
                :answer,
                ANSWERS_PER_QUESTION,
                question_id: question.id,
                user_session_id: user_session.id,
                type: "Answer::#{question.type.demodulize}"
              ) do |answer|
                unless question.body['variable'].nil?
                  answer.body = { data: [
                    {
                      var: question.body['variable']['name'],
                      value: Faker::Number.between(from: 0, to: 10)
                    }
                  ] }
                  answer.save!
                end
              end
            end
          end
        end
      end
    end
  end

  report_index = 0
  report_index_max = Session.count * [REPORTS_PER_SESSION, User.limit_to_roles('participant').count].min
  Session.find_each do |session|
    report_template = session.report_templates.last
    session.user_sessions.limit(REPORTS_PER_SESSION).each do |user_session|
      create(
        :generated_report,
        :participant,
        :with_pdf_report,
        name: "#{user_session.user.first_name} report",
        user_session_id: user_session.id,
        report_template_id: report_template.id
      )
      p "#{report_index += 1}/#{report_index_max} reports created"
    end
  end

  p "Example user email: #{example_user.email}"
  p 'Example user password: Password1!'
  p "Example user verification code: verification_code_#{example_user.uid}"
  # rubocop:enable Rails/Output
end
