# frozen_string_literal: true

class UpdateJobs::AdjustQuestionReflections < CloneJob
  def perform(question, prev_variable_name)
    reflectable_questions(question).each do |q|
      q.narrator['blocks'].each do |block|
        next if block['reflections'].nil?

        block['reflections'].each do |reflection|
          next unless reflection['variable'] == prev_variable_name

          reflection['variable'] = question.body['variable']['name']
        end

        q.save!
      end
    end
  end

  def reflectable_questions(question)
    Question
       .within_intervention(question.session.intervention_id)
       .where.not(id: question.id)
       .joins("CROSS JOIN jsonb_array_elements(narrator->'blocks') AS narrator_block")
       .where('narrator_block @> ?', { type: 'Reflection', question_id: question.id }.to_json)
  end
end
