# frozen_string_literal: true

return if Rails.env.production?

# rubocop:disable Metrics/ClassLength, Style/ClassVars, ThreadSafety/ClassAndModuleAttributes
class Fake
  class << self
    mattr_accessor :intervention_types
    mattr_accessor :user_ids
    mattr_accessor :intervention_ids
    mattr_accessor :subclass_types

    def exploit
      create_users
      create_interventions
      create_questions
      create_answers
    end

    private

    def define_subclasses(path)
      subclasses = Dir.entries(Rails.root.join(path)) - %w[. ..]
      subclasses.each { |file| file.gsub!(/\.rb/, '') }.map(&:classify)
    end

    def create_users
      User::APP_ROLES.each do |role|
        u = User.new(
          first_name: role,
          last_name: Faker::GreekPhilosophers.name,
          username: role,
          email: "#{role}@#{ENV['DOMAIN_NAME']}",
          password: 'qwerty1234',
          roles: [role]
        )
        u.confirm
        u.save
      end

      u = User.new(
        first_name: 'all',
        last_name: 'roles',
        username: 'all',
        email: "all_roles@#{ENV['DOMAIN_NAME']}",
        password: 'qwerty1234',
        roles: User::APP_ROLES
      )
      u.confirm
      u.save
    end

    def intervention_types
      @@intervention_types ||= define_subclasses('app/models/intervention/')
    end

    def user_ids
      @@user_ids ||= User.ids
    end

    def create_interventions
      user_ids
      (20..40).to_a.sample.times do
        Intervention.create(
          type: "Intervention::#{intervention_types.sample}",
          user_id: user_ids.sample,
          name: Faker::Name.name,
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

    def intervention_ids
      @@intervention_ids ||= Intervention.ids
    end

    def subclass_types
      @@subclass_types ||= define_subclasses('app/models/question/')
    end

    def create_questions
      (60..80).to_a.sample.times do
        sample_type = subclass_types.sample
        image_sample = images_files.sample
        question = Question.new(
          type: "Question::#{sample_type}",
          intervention_id: intervention_ids.sample,
          order: rand(1..100),
          title: sample_type,
          subtitle: Faker::Job.position,
          video_url: Faker::Internet.url(host: 'youtube.com'),
          formula: formula_data_base,
          body: body_data_by_type(sample_type)
        )
        question.image.attach(io: File.open(image_sample), filename: image_sample.split('/').last)
        question.save
      end
    end

    def create_answers
      (100..140).to_a.sample.times do
        question = Question.order('RANDOM()').first
        Answer.create(
          user_id: user_ids.sample,
          question: question,
          type: "Answer::#{question.subclass_name}",
          body: body_data_base
        )
      end
    end

    def body_data_by_type(type)
      case type
      in 'AnalogueScale'
        {
          data: [
            {
              payload: {
                start_value: 'start',
                end_value: 'end'
              }
            }
          ],
          "variable": {
            "name": 'var_1'
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
      in 'TextBox'
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
      in 'Url'
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

    def formula_data_base
      patterns = []
      (2..5).to_a.sample.times do
        patterns.push(
          {
            match: "#{comparison.sample} #{rand(1..20)}",
            target: rand(1..10).to_s
          }
        )
      end
      {
        payload: Faker::Alphanumeric.alpha(number: 4),
        patterns: patterns
      }
    end

    def images_files
      @@images_files ||= Dir[Rails.root.join('spec/factories/images/*.jpg')]
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
  end
end
# rubocop:enable Metrics/ClassLength, Style/ClassVars, ThreadSafety/ClassAndModuleAttributes

Fake.exploit
