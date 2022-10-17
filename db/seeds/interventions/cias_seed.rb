# frozen_string_literal: true

require 'factory_bot_rails'
require 'faker'

require_relative './seed_helpers'

NUM_OF_RESEARCHERS = 1
NUM_OF_PARTICIPANTS = 1
INTERVENTIONS_PER_RESEARCHER = 6
SESSIONS_PER_INTERVENTION = 8
REPORT_TEMPLATES_PER_SESSION = 4
QUESTION_GROUPS_PER_SESSION = 10
QUESTIONS_PER_QUESTION_GROUP = 6
MAX_BRANCHES_FOR_QUESTION = 2
ANSWERS_PER_QUESTION = 2
REPORTS_PER_SESSION = 6 # Limited by number of participants.

INTERVENTION_STATUS = Intervention.statuses.to_a.map(&:first)
INTERVENTION_TYPES = %w[Intervention::FixedOrder Intervention::FlexibleOrder Intervention].freeze
INTERVENTION_NAMES = ['Drugs intervention', 'Smoking intervention', 'Alcohol intervention', 'Gambling intervention'].freeze
INTERVENTION_NAMES_DIRECTED = ['Husbands', 'Pregnant women', 'Underage teenagers', 'homeless people'].freeze

QUESTION_TYPES = %i[question_feedback question_grid question_information question_multiple question_number question_single
                    question_free_response question_date question_currency].freeze

QUESTIONS_WITHOUT_ANSWERS = %w[Question::Finish Question::HenryFordInitial]
# rubocop:disable Lint/TopLevelReturnWithArgument, Rails/Output
return puts '# Will not pollute database. Generator is disabled on this environment' unless ENV['GENERATOR_ENABLED'] == '1'
# rubocop:enable Lint/TopLevelReturnWithArgument

class DBSeed
  extend FactoryBot::Syntax::Methods
  create_participants_and_researchers(NUM_OF_PARTICIPANTS, NUM_OF_RESEARCHERS)

  admin_email = "cias-team+admin_#{ENV.fetch('APP_HOSTNAME')}@htdevelopers.com".gsub(/[^0-9A-Za-z_\-@.+]/, '')
  admin_password = ENV['CIAS_ADMIN_PASSWORD']
  unless User.find_by(email: admin_email)
    example_user = create_user('admin', admin_email, admin_password)
    example_user.confirm
    p 'Admin created'
  end

  researcher_index = 0
  researcher_index_max = User.limit_to_roles('researcher').size * INTERVENTIONS_PER_RESEARCHER * SESSIONS_PER_INTERVENTION *
    QUESTION_GROUPS_PER_SESSION * QUESTIONS_PER_QUESTION_GROUP

  User.limit_to_roles('researcher').ids.each do |researcher_id|
    create_list(:intervention, INTERVENTIONS_PER_RESEARCHER, user_id: researcher_id) do |intervention|
      intervention.status = INTERVENTION_STATUS.sample
      intervention.name = "#{INTERVENTION_NAMES.sample} for #{INTERVENTION_NAMES_DIRECTED.sample}"
      intervention.type = INTERVENTION_TYPES.sample
      intervention.shared_to = 'registered'
      intervention.save!
      session_position = 1
      create_list(:session, SESSIONS_PER_INTERVENTION, intervention_id: intervention.id) do |session|
        session.position = session_position
        session_position += 1
        session.name = Faker::Movies::HarryPotter.quote.capitalize
        session.save!

        create_list(:report_template, REPORT_TEMPLATES_PER_SESSION, :participant, :with_logo,
                    summary: Faker::Movies::HowToTrainYourDragon.character, session_id: session.id) do |report_template|
          report_template.save!
          section = create(:report_template_section, report_template: report_template, formula: '1')
          create(:report_template_section_variant, :with_image, report_template_section: section, formula_match: '=1')
          create(:report_template_section_variant, :with_image, report_template_section: section, formula_match: '=2')
        end

        create_list(:question_group, QUESTION_GROUPS_PER_SESSION, session_id: session.id) do |question_group|
          question_group.title = Faker::Movie.title
          question_group.save!

          QUESTIONS_PER_QUESTION_GROUP.times do
            question = create(
              QUESTION_TYPES.sample,
              title: "<h2>#{Faker::TvShows::Simpsons.quote.capitalize}</h2>",
              subtitle: "<p>#{Faker::Company.buzzword} ##{rand(1..100)}</p>",
              question_group_id: question_group.id
            )
            question.settings['required'] = false
            question.narrator['settings']['voice'] = false
            question.narrator['settings']['animation'] = false
            assign_variable!(question)

            p "#{researcher_index += 1}/#{researcher_index_max} researcher data created"
          end
        end
      end
    end
  end

  branching_index = 0
  branching_index_max = 0
  q_groups_from_intervention.each do |question_group|
    branching_index_max += question_group.questions.size
  end


        Intervention.includes({ sessions: { question_groups: :questions } }).find_each do |intervention|
          session_paths = []
          question_paths = []
          intervention.sessions.each do |session|
            if intervention.type != 'Intervention::FlexibleOrder'
              intervention.sessions.each do |branch_session|
                session_paths << { 'type' => 'Session', 'id' => branch_session.id } if session.position < branch_session.position
              end
            end

            session.question_groups.each do |question_group|
              question_group.questions.each do |question|
                question_group.questions.each do |branch_question|
                  question_paths << { 'type' => branch_question.type, 'id' => branch_question.id } if branchable_question?(question, branch_question)
                end

                mixed_paths = session_paths + question_paths
                session_paths = []
                question_paths = []
                create_branching(question, mixed_paths, MAX_BRANCHES_FOR_QUESTION)
                p "#{branching_index += 1}/#{branching_index_max} branching data created"
              end
            end
          end
        end

      question_count = 0
      q_groups_from_intervention(status: 'draft').each do |question_group|
        question_count += question_group.questions.size
      end
      participant_index = 0
      participant_index_max = User.limit_to_roles('participant').size * question_count

      User.limit_to_roles('participant').ids.each do |participant_id|
        Intervention.includes({ sessions: { question_groups: :questions } }).where.not(status: 'draft').find_each do |intervention|
          user_intervention = create(:user_intervention, :completed, user_id: participant_id, intervention_id: intervention.id)

          intervention.sessions.each do |session|
            create(:user_session, user_id: participant_id, session_id: session.id, user_intervention_id: user_intervention.id) do |user_session|
              user_session.save!

              session.question_groups.each do |question_group|
                question_group.questions.each do |question|
                  p "#{participant_index += 1}/#{participant_index_max} participants data created"
                  next if QUESTIONS_WITHOUT_ANSWERS.include?(question.type)

                  create_list(:answer, ANSWERS_PER_QUESTION, type: "Answer::#{question.type.demodulize}",
                              question_id: question.id, user_session_id: user_session.id) do |answer|
                    assign_data_to_answer(answer, question)
                  end
                end
              end
            end
          end
        end
      end

      report_index = 0
      report_index_max = 0
      Session.find_each { |session| report_index_max += [session.user_sessions.size, REPORTS_PER_SESSION].min }
      Session.includes(:report_templates, user_sessions: :user).find_each do |session|
        report_template_id = session.report_templates.sample&.id
        next unless report_template_id.present?

        session.user_sessions.limit(REPORTS_PER_SESSION).each do |user_session|
          create(
            :generated_report,
            :participant,
            name: "#{user_session.user.full_name} report",
            user_session_id: user_session.id,
            participant_id: user_session.user.id,
            report_template_id: report_template_id
          )

          p "#{report_index += 1}/#{report_index_max} reports created"
        end
      end

      if example_user
        p "Example user email: #{example_user.email}"
        p 'Example user password: You know it ;)'
      end
      # rubocop:enable Rails/Output
    end
