# frozen_string_literal: true

class V1::FlowService
  REFLECTION_MISS_MATCH = 'ReflectionMissMatch'

  def initialize(user_session)
    @user_session = user_session
    @user = @user_session.user
    @warning = ''
    @next_session_id = ''
  end

  attr_reader :user
  attr_accessor :user_session, :warning, :next_session_id

  def user_session_question(preview_question_id)
    answers_var_values = user_session.all_var_values

    question = question_to_display(answers_var_values, preview_question_id)
    question = perform_narrator_reflections(question, answers_var_values)
    question = prepare_questions_with_answer_values(question, answers_var_values)
    question.another_or_feedback(question, answers_var_values)

    user_session.finish if question.type == 'Question::Finish'

    { question: question, warning: warning, next_session_id: next_session_id }
  end

  def question_to_display(answers_var_values, preview_question_id)
    return user_session.session.questions.find(preview_question_id) if preview_question_id.present? && user_session.session.draft?

    last_answered_question = user_session.last_answer&.question
    return user_session.session.first_question if last_answered_question.nil?

    perform_branching_to_next_question(last_answered_question, answers_var_values)
  end

  def perform_branching_to_next_question(last_question, answers_var_values)
    return nil if last_question.id.eql?(last_question.position_equal_or_higher.last.id)

    next_question = last_question.position_equal_or_higher[1]
    if last_question.formula['payload'].present?
      obj_src = last_question.exploit_formula(answers_var_values)
      self.warning = obj_src if obj_src.is_a?(String)
      next_question = branching_source_to_question(obj_src) if obj_src.is_a?(Hash)
    end

    next_question
  end

  def branching_source_to_question(source)
    branching_type = source['target']['type']
    question_or_session = branching_type.safe_constantize.find(source['target']['id'])
    return question_or_session if branching_type.include? 'Question'

    session_available_now = question_or_session.available_now

    user_session.finish(send_email: !session_available_now)

    self.next_session_id = question_or_session.id if session_available_now

    user_session.session.finish_screen
  end

  def swap_name_mp3(question)
    blocks = question.narrator['blocks']
    blocks.map do |block|
      next block unless %w[Speech ReflectionFormula Reflection].include?(block['type'])
      next block if user_session.name_audio.nil?

      block = question.send("swap_name_into_#{block['type'].downcase}_block", block, user_session.name_audio.url)
      block
    end
    question
  end

  def perform_narrator_reflections(question, answers_var_values)
    question = swap_name_mp3(question)
    question.narrator['blocks']&.each_with_index do |block, index|
      next unless %w[Reflection ReflectionFormula].include?(block['type'])

      question.narrator['blocks'][index]['target_value'] = prepare_block_target_value(question, answers_var_values, block)
    end
    question
  end

  def prepare_block_target_value(question, answers_var_values, block)
    return question.exploit_formula(answers_var_values, block['payload'], block['reflections']) if block['type'].eql?('ReflectionFormula')

    matched_reflections = []
    block['reflections'].each do |reflection|
      if reflection['variable'].eql?('') || reflection['value'].eql?('')
        self.warning = REFLECTION_MISS_MATCH
        return []
      end

      matched_reflections.push(reflection) if answers_var_values.key?(reflection['variable']) && answers_var_values[reflection['variable']].eql?(reflection['value'])
    end
    matched_reflections
  end

  def prepare_questions_with_answer_values(question, answers_var_values)
    question.another_or_feedback(question, answers_var_values)
  end
end
