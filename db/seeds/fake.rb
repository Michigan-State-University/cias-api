# frozen_string_literal: true

require 'faker'

# rubocop:disable Lint/TopLevelReturnWithArgument, Rails/Output
msg_template = 'Will not pollute database by fake data'
return puts "\n#{msg_template} in production environment" if Rails.env.production?
return puts "\n#{msg_template} where there are no created users" if User.none?

# rubocop:enable Lint/TopLevelReturnWithArgument, Rails/Output

# rubocop:disable Metrics/ClassLength, Style/ClassVars, ThreadSafety/ClassAndModuleAttributes
class Fake
  class << self
    mattr_accessor :session_types
    mattr_accessor :user_ids
    mattr_accessor :session_ids
    mattr_accessor :subclass_types

    def exploit
      create_interventions
      create_sessions
      create_session_invitations
      create_questions
      create_user_sessions
      create_answers
    end

    private

    def user_ids
      @@user_ids ||= User.ids
    end

    def define_subclasses(path)
      subclasses = Rails.root.join(path).entries - %w[. ..]
      subclasses.each { |file| file.gsub!('.rb', '') }.map(&:classify)
    end

    def create_interventions
      user_ids
      (4..14).to_a.sample.times do
        Intervention.create(
          name: Faker::University.name,
          user_id: user_ids.sample,
          shared_to: Intervention.shared_tos.keys.sample
        )
      end
    end

    def intervention_ids
      @@intervention_ids ||= Intervention.ids
    end

    def create_sessions
      intervention_ids
      (40..60).to_a.sample.times do
        Session.create(
          intervention_id: intervention_ids.sample,
          name: Faker::Name.name,
          position: rand(1..100),
          body: { data: [
            {
              payload: 'question_key1_test',
              target: '',
              variable: 'question_value2_test'
            }
          ] }
        )
      end
    end

    def session_ids
      @@session_ids ||= Session.ids
    end

    def create_session_invitations
      Session.find_each do |session|
        (1..4).to_a.sample.times do
          session.session_invitations.create(email: Faker::Internet.email)
        end
      end
    end

    def subclass_types
      @@subclass_types ||= define_subclasses('app/models/question/') - %w[Csv Finish Narrator]
    end

    def quotas
      [Faker::Games::Fallout, Faker::Games::WorldOfWarcraft, Faker::Games::WarhammerFantasy]
    end

    def narrator_blocks_text
      text = []
      (1..5).to_a.sample.times do
        text.push(quotas.sample.quote)
      end
      text
    end

    def create_questions
      (80..100).to_a.sample.times do
        sample_type = subclass_types.sample
        image_sample = images_files.sample
        session = Session.find(session_ids.sample)

        question = Question.new(
          type: "Question::#{sample_type}",
          question_group: session.question_group_plains.first,
          position: rand(1..100),
          title: sample_type,
          subtitle: Faker::Job.position,
          video_url: Faker::Internet.url(host: 'youtube.com'),
          formula: formula_data_base,
          body: body_data_by_type(sample_type)
        )
        question.narrator = {}
        question.narrator['settings'] = {
          voice: true,
          animation: true
        }
        question.narrator['blocks'] = [
          {
            type: 'Speech',
            text: narrator_blocks_text,
            sha256: [],
            audio_urls: [],
            animation: ''
          },
          {
            type: 'Speech',
            text: narrator_blocks_text,
            sha256: [],
            audio_urls: [],
            animation: ''
          },
          {
            type: 'Reflection',
            reflections: [
              {
                text: narrator_blocks_text,
                sha256: [],
                audio_urls: [],
                animation: '',
                variable: '',
                value: '',
                question_id: ''
              },
              {
                text: narrator_blocks_text,
                sha256: [],
                audio_urls: [],
                animation: '',
                variable: '',
                value: '',
                question_id: ''
              }
            ]
          },
          {
            type: 'Speech',
            text: narrator_blocks_text,
            sha256: [],
            audio_urls: [],
            animation: ''
          }
        ]
        question.image.attach(io: File.open(image_sample), filename: image_sample.split('/').last)
        question.save
      end
      session_question_type_id = Session.pluck(:id).map { |i| ['Session', i] } + Question.pluck(:type, :id)
      Question.find_each do |question|
        question.formula['patterns'].each do |pattern|
          target = session_question_type_id.sample
          pattern['target']['type'] = target.first.deconstantize
          pattern['target']['id'] = target.last
        end
        question.save
      end
    end

    def create_user_sessions
      interventions = Intervention.order('RANDOM()').limit(4)
      interventions.each(&:broadcast)
      Session.where(intervention_id: interventions.ids).find_each do |session|
        session.user_sessions.create(user_id: user_ids.sample)
      end
    end

    def create_answers
      (100..140).to_a.sample.times do
        question = Question.where.not(type: 'Question::Finish').order('RANDOM()').first
        answer = Answer.new(
          user_id: user_ids.sample,
          question: question,
          type: "Answer::#{question.subclass_name}"
        )
        answer.save
        var_name = answer.question.csv_header_names&.sample
        answer.body = answer_body_data(var_name)
        answer.save
      end
    end

    def body_data_by_type(type)
      case type
      in 'Slider'
        {
          data: [
            {
              payload: {
                start_value: 'start',
                end_value: 'end'
              }
            }
          ],
          variable: {
            name: 'var_1'
          }
        }
      in 'Grid'
        {
          data: [
            {
              payload: {
                rows: [
                  {
                    payload: 'test',
                    variable: {
                      name: 'test'
                    }
                  }
                ],
                columns: [
                  {
                    payload: 'col1',
                    variable: {
                      value: 'val1'
                    }
                  },
                  {
                    payload: 'col2',
                    variable: {
                      value: 'val2'
                    }
                  }
                ]
              }
            }
          ]
        }
      in 'Information'
        {
          data: []
        }
      in 'Multiple'
        {
          data: [
            {
              payload: Faker::Games::Fallout.character,
              variable: {
                name: Faker::Alphanumeric.alpha(number: 6),
                value: rand(1..10).to_s
              }
            },
            {
              payload: Faker::Games::Witcher.character,
              variable: {
                name: Faker::Alphanumeric.alpha(number: 6),
                value: rand(1..10).to_s
              }
            },
            {
              payload: Faker::Games::WorldOfWarcraft.hero,
              variable: {
                name: Faker::Alphanumeric.alpha(number: 6),
                value: rand(1..10).to_s
              }
            },
            {
              payload: Faker::TvShows::BreakingBad.character,
              variable: {
                name: Faker::Alphanumeric.alpha(number: 6),
                value: rand(1..10).to_s
              }
            }
          ]
        }
      in 'Number'
        {
          data: [
            {
              payload: Faker::Creature::Dog.name
            }
          ],
          variable: {
            name: Faker::Alphanumeric.alpha(number: 6)
          }
        }
      in 'FreeResponse'
        {
          data: [
            {
              payload: Faker::Creature::Cat.name
            }
          ],
          variable: {
            name: Faker::Alphanumeric.alpha(number: 6)
          }
        }
      in 'ExternalLink'
        {
          data: [
            {
              payload: Faker::Creature::Dog.name
            }
          ],
          variable: {
            name: Faker::Alphanumeric.alpha(number: 4)
          }
        }
      else
        body_data_base
      end
    end

    def body_data_base
      {
        data: [
          {
            payload: Faker::Creature::Dog.name,
            value: rand(1..10).to_s
          },
          {
            payload: 'example2',
            value: rand(1..10).to_s
          }
        ],
        variable: {
          name: Faker::Alphanumeric.alpha(number: 6)
        }
      }
    end

    def answer_body_data(var_name)
      {
        data: [
          {
            var: var_name,
            value: rand(1..10).to_s
          }
        ]

      }
    end

    def formula_data_base
      patterns = []
      (2..5).to_a.sample.times do
        patterns.push(
          {
            match: "#{comparison.sample} #{rand(1..20)}",
            target: {
              type: '',
              id: ''
            }
          }
        )
      end
      {
        payload: Faker::Alphanumeric.alpha(number: 4),
        patterns: patterns
      }
    end

    def images_files
      @@images_files ||= Rails.root.glob('spec/factories/images/*.jpg')
    end

    def arithmetic
      @@arithmetic ||= %w[+ - * /]
    end

    def assignment
      @@assignment ||= %w[=]
    end

    def comparison
      @@comparison ||= %w[< <= > >= == !=]
    end

    def logical
      @@logical ||= %w[AND OR NOT]
    end

    def true_or_false
      @@true_or_false ||= [true, false]
    end
  end
end
# rubocop:enable Metrics/ClassLength, Style/ClassVars, ThreadSafety/ClassAndModuleAttributes

Fake.exploit
