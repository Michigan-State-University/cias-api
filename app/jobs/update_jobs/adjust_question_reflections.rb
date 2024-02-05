# frozen_string_literal: true

class UpdateJobs::AdjustQuestionReflections < CloneJob
  def perform(question, prev_variable_name)
    reflectable_questions(question, prev_variable_name).each do |q|
      q.narrator['blocks'].each do |block|
        next if block['reflections'].nil?

        block['reflections'].each do |reflection|
          reflection['variable'] = question.body['variable']['name']
        end

        q.save!
      end
    end
  end

  def reflectable_questions(question, variable_name)
    Question
       .within_intervention(question.session.intervention_id)
       .where.not(id: question.id)
       .joins("CROSS JOIN jsonb_array_elements(narrator->'blocks') AS narrator_block")
       .where('narrator_block @> ?', { type: 'Reflection', question_id: question.id }.to_json)
       .where("narrator_block->>'reflections' IS NOT NULL")
       .where(
         "EXISTS (
           SELECT 1
           FROM jsonb_array_elements(narrator_block->'reflections')
           AS reflection
           WHERE reflection->>'variable' = ?
         )",
         variable_name
       )
  end
end
