# frozen_string_literal: true

require 'faker'

return if Rails.env.production?
return if User.count.zero?

# rubocop:disable Metrics/ClassLength, Style/ClassVars, ThreadSafety/ClassAndModuleAttributes, ThreadSafety/InstanceVariableInClassMethod
class Fake
  class << self
    mattr_accessor :intervention_types
    mattr_accessor :user_ids
    mattr_accessor :intervention_ids
    mattr_accessor :subclass_types

    def exploit
      create_problems
      create_interventions
      create_questions
      create_answers
    end

    private

    def user_ids
      @@user_ids ||= User.ids
    end

    def define_subclasses(path)
      subclasses = Dir.entries(Rails.root.join(path)) - %w[. ..]
      subclasses.each { |file| file.gsub!(/\.rb/, '') }.map(&:classify)
    end

    def create_problems
      user_ids
      (4..14).to_a.sample.times do
        Problem.create(
          name: Faker::University.name,
          user_id: user_ids.sample,
          allow_guests: true_or_false.sample
        )
      end
    end

    def problem_ids
      @@problem_ids ||= Problem.ids
    end

    def create_interventions
      problem_ids
      (40..60).to_a.sample.times do
        Intervention.create(
          user_id: user_ids.sample,
          problem_id: problem_ids.sample,
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
      intervention_published_ids = Intervention.published.ids
      (5..10).to_a.sample.times do
        intervention_id = intervention_published_ids.sample
        intervention = Intervention.find(intervention_id)
        intervention.update(allow_guests: true)
        intervention_published_ids.delete(intervention_id)
      end
    end

    def intervention_ids
      @@intervention_ids ||= Intervention.ids
    end

    def subclass_types
      @@subclass_types ||= define_subclasses('app/models/question/') - %w[Narrator Csv]
    end

    def quotas
      @quotas ||= [Faker::Games::Fallout, Faker::Games::WorldOfWarcraft, Faker::Games::WarhammerFantasy]
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
        question = Question.new(
          type: "Question::#{sample_type}",
          intervention_id: intervention_ids.sample,
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
      intervention_question_type_id = Intervention.pluck(:id).map { |i| ['Intervention', i] } + Question.pluck(:type, :id)
      Question.all.each do |question|
        question.formula['patterns'].each do |pattern|
          target = intervention_question_type_id.sample
          pattern['target']['type'] = target.first.deconstantize
          pattern['target']['id'] = target.last
        end
        question.save
      end
    end

    def create_answers
      (100..140).to_a.sample.times do
        question = Question.order('RANDOM()').first
        answer = Answer.new(
          user_id: user_ids.sample,
          question: question,
          type: "Answer::#{question.subclass_name}"
        )
        answer.save
        var_name = answer.question.harvest_body_variables&.sample
        answer.body = answer_body_data(var_name)
        answer.save
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

    def true_or_false
      @@true_or_false ||= [true, false]
    end
  end
end
# rubocop:enable Metrics/ClassLength, Style/ClassVars, ThreadSafety/ClassAndModuleAttributes, ThreadSafety/InstanceVariableInClassMethod

Fake.exploit
