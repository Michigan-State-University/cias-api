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
      @@intervention_types ||= %w[Single Multiple]
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
      @@subclass_types ||= begin
        subklasses = Dir.entries(Rails.root.join('app/models/question/')) - %w[. ..]
        subklasses.each { |file| file.gsub!(/\.rb/, '') }.map(&:classify)
      end
    end

    def create_questions
      (60..80).to_a.sample.times do
        sample_type = subclass_types.sample
        Question.create(
          intervention_id: intervention_ids.sample,
          order: nil,
          title: sample_type,
          subtitle: Faker::Job.position,
          type: "Question::#{sample_type}",
          body: { data: [
            {
              payload: 'question data',
              target: 'point to another question',
              variable: 'var for payload'
            }
          ] }
        )
      end
    end

    def create_answers
      (100..140).to_a.sample.times do
        question = Question.order('RANDOM()').first
        Answer.create(
          user_id: user_ids.sample,
          question: question,
          type: "Answer::#{question.subclass_name}",
          body: { data: [
            {
              payload: 'answer data',
              target: 'shadow copy of answer',
              variable: 'shadow copy of question'
            }
          ] }
        )
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength, Style/ClassVars, ThreadSafety/ClassAndModuleAttributes

Fake.exploit
