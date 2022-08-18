# frozen_string_literal: true

namespace :narrator do
  desc 'Get animations count from researcher accounts interventions'
  task get_animations_count: :environment do
    researcher_ids = User.limit_to_roles(%w[researcher team_admin e_intervention_admin]).pluck(:id)
    intervention_ids = Intervention.where(user_id: researcher_ids).where.not('lower(name) like ?', 'copy of%').pluck(:id)
    questions = Question.includes(question_group: { session: :intervention }).where(question_group: { sessions: { intervention_id: intervention_ids } })
    questions_count = questions.count

    animations_hash = Hash.new(0)

    questions.each_with_index do |question, index|
      p "Calculating animations for #{index + 1} / #{questions_count} questions"
      question.narrator['blocks'].each do |block|
        animation_name = block['animation']
        animations_hash[animation_name] += 1
      end
    end

    p 'Animations count'
    PP.pp(animations_hash, $DEFAULT_OUTPUT, 25)
  end
end
