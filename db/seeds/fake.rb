# frozen_string_literal: true

class Fake
  class << self
    def exploit
      create_users
      create_interventions
      create_questions
    end

    private

    def create_users
      User::APP_ROLES.each do |role|
        u = User.new(
          first_name: role,
          last_name: Faker::GreekPhilosophers.name,
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
        email: "all_roles@#{ENV['DOMAIN_NAME']}",
        password: 'qwerty1234',
        roles: User::APP_ROLES
      )
      u.confirm
      u.save
    end

    def intervention_types
      %w[Single Multiple]
    end

    def user_ids
      User.ids
    end

    def create_interventions
      intervention_types
      user_ids
      (20..40).to_a.sample.times do
        Intervention.create(
          type: "Intervention::#{intervention_types.sample}",
          user_id: user_ids.sample,
          name: Faker::Name.name,
          settings: { key1: 'intervention_key1_test', key2: 'intervention_value2_test' }
        )
      end
    end

    def intervention_ids
      Intervention.ids
    end

    def question_types
      %w[AnalogueScale BarGraph Blank Feedback FollowUpContact Grid Multiple Name Number Single TextBox Url Video]
    end

    def create_questions
      intervention_ids
      question_types
      (60..80).to_a.sample.times do
        sample_type = question_types.sample
        Question.create(
          previous_id: nil,
          intervention_id: intervention_ids.sample,
          title: sample_type,
          subtitle: Faker::Job.position,
          type: "Question::#{sample_type}",
          body: { key1: 'question_key1_test', key2: 'question_value2_test' }
        )
      end
    end
  end
end

Fake.exploit
