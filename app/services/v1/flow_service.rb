# frozen_string_literal: true

class V1::FlowService
  def initialize(user, answer_id)
    @user = user
    @answer = Answer.find(answer_id)
    @question = @answer.question
  end

  attr_reader :user
  attr_accessor :answer, :question

  def answer_branching_flow
    perform_branching_to_question
    # zaakonczenie sesjii czyli scheduling
    # session_finished(answer) if question.type == 'Question::Finish'
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
    return nil if question.id.eql?(question.position_equal_or_higher.last.id)

    next_question = question.position_equal_or_higher[1]
    if question.formula['payload'].present?
      obj_src = question.exploit_formula(answers_var_values)

      next_question = branching_source_to_question(obj_src) if obj_src.is_a?(Hash)
    end
    next_question.perform_narrator_reflection(answers_var_values)
    question.another_or_feedback(next_question, answers_var_values)
  end

  def branching_source_to_question(source)
    branching_type = source['target']['type']
    question_or_session = branching_type.safe_constantize.find(source['target']['id'])
    # check if question_or_session is question
    return question_or_session if branching_type.include? 'Question'

    # question_or_session is session
    # sesja zakonczona i dalej patrzymy czy zworic pytanie czy wrzucic jakos do schedulingu

    return question_or_session.first_question if question_or_session.schedule == 'after_fill'

    question.question_group.session.finish_screen
  end
end
