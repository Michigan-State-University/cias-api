# frozen_string_literal: true

class V1::FlowService::ReflectionService
  REFLECTION_MISS_MATCH = 'ReflectionMissMatch'

  def initialize(user_session)
    @user_session = user_session
    @additional_information = {}
  end

  attr_accessor :user_session, :additional_information

  def call(question)
    return question if question.is_a?(Hash) || question.nil?

    question = question.swap_name_mp3(name_audio, name_answer)

    question.narrator['blocks']&.each_with_index do |block, index|
      next unless %w[Reflection ReflectionFormula].include?(block['type'])

      question.narrator['blocks'][index]['target_value'] = prepare_block_target_value(question, block)
    end
    question
  end

  private

  def name_audio
    user_session.name_audio
  end

  def name_answer
    user_session.search_var('.:name:.')
  end

  def prepare_block_target_value(question, block)
    return question.exploit_formula(all_var_values, block['payload'], block['reflections']) if block['type'].eql?('ReflectionFormula')

    matched_reflections = []
    block['reflections'].each do |reflection|
      if reflection['variable'].eql?('') || reflection['value'].eql?('')
        additional_information[:warning] = REFLECTION_MISS_MATCH
        return []
      end
      current_variable = reflection_variable(block, reflection['variable'])
      matched_reflections.push(reflection) if all_var_values.key?(current_variable) && all_var_values[current_variable].eql?(reflection['value'])
    end
    matched_reflections
  end

  def reflection_variable(block, variable)
    block['session_id'].present? ? "#{Session.find(block['session_id']).variable}.#{variable}" : variable
  end

  def all_var_values
    @all_var_values ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values
  end
end
