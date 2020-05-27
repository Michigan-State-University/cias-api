# frozen_string_literal: true

return if Rails.env.production?

# rubocop:disable Style/ClassVars, ThreadSafety/ClassAndModuleAttributes
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
      @@subclass_types ||= %w[AnalogueScale BarGraph Blank Feedback FollowUpContact Grid Multiple Name Number Single TextBox Url Video]
    end

    def create_questions
      (60..80).to_a.sample.times do
        sample_type = subclass_types.sample
        Question.create(
          previous_id: nil,
          intervention_id: intervention_ids.sample,
          title: sample_type,
          subtitle: Faker::Job.position,
          type: "Question::#{sample_type}",
          body: { data: [
            {
              payload: 'question_key1_test',
              variable: 'question_value2_test'
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
              payload: 'question_key1_test',
              variable: 'question_value2_test'
            }
          ] }
        )
      end
    end
  end
end
# rubocop:enable Style/ClassVars, ThreadSafety/ClassAndModuleAttributes

Fake.exploit
