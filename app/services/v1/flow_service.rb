# frozen_string_literal: true

class V1::FlowService
  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
    @user = @user_session.user
    @question = @user_session.last_answer.question
  end

  attr_reader :user
  attr_accessor :question, :user_session

  def next_question
    response_question_with_warning = perform_branching_to_question
    response_question_with_warning = swap_name_mp3(response_question_with_warning)
    user_session.finish if response_question_with_warning[:question].type == 'Question::Finish'
    response_question_with_warning
  end

  def retrieve_previous_and_current_answers
    previous_sessions_ids = question.session.intervention.sessions.where('sessions.position < ?', question.session.position).ids
    previous_answers = Answer.user_answers(user.id, previous_sessions_ids)
    current_answers = Answer.joins(:user_session, question: :question_group).where(questions: { position: ..question.position }).user_answers(user.id, [question.session.id])

    previous_answers + current_answers
  end

  def collect_var_values
    retrieve_previous_and_current_answers.each_with_object({}) do |collection, hash|
      collection.body_data.each do |obj|
        hash[obj['var']] = obj['value']
      end
    end
  end

  def perform_branching_to_question
    answers_var_values = collect_var_values
    warning = ''
    return nil if question.id.eql?(question.position_equal_or_higher.last.id)

    next_question = question.position_equal_or_higher[1]
    if question.formula['payload'].present?
      obj_src = question.exploit_formula(answers_var_values)
      warning = obj_src if obj_src.is_a?(String)
      next_question = branching_source_to_question(obj_src) if obj_src.is_a?(Hash)
    end
    next_question.perform_narrator_reflection(answers_var_values)
    question_another_or_feedback = question.another_or_feedback(next_question, answers_var_values)
    { question: question_another_or_feedback, warning: warning }
  end

  def branching_source_to_question(source)
    branching_type = source['target']['type']
    question_or_session = branching_type.safe_constantize.find(source['target']['id'])
    return question_or_session if branching_type.include? 'Question'

    session_available_now = question_or_session.available_now

    user_session.finish(send_email: !session_available_now)

    return question_or_session.first_question if session_available_now

    question.question_group.session.finish_screen
  end

  def swap_name_mp3(question_with_warning)
    question = question_with_warning[:question]
    blocks = question.narrator['blocks']
    blocks.map do |block|
      next block unless %w[Speech ReflectionFormula Reflection].include?(block['type'])
      next block if user_session.name_audio.nil?

      block = question.send("swap_name_into_#{block['type'].downcase}_block", block, user_session.name_audio.url)
      block
    end
    question_with_warning
  end
end
