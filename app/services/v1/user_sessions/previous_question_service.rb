# frozen_string_literal: true

class V1::UserSessions::PreviousQuestionService
  def self.call(user_session, current_question_id)
    new(user_session, current_question_id).call
  end

  def initialize(user_session, current_question_id)
    @user_session = user_session
    @question_id = current_question_id
    @answer = user_session.answers.find_by(question_id: current_question_id)
  end

  attr_reader :user_session, :answer, :question_id
  attr_accessor :previous_answer

  def call
    raise CatMh::ActionNotAvailable, I18n.t('user_sessions.errors.previous_question') if user_session.type == 'UserSession::CatMh'

    @previous_answer = user_session.answers.where('created_at < ?', (answer&.created_at || DateTime.now))&.last
    previous_answer&.update!(draft: true)

    {
      question: previous_question,
      answer: previous_answer
    }
  end

  private

  def all_var_values
    @all_var_values ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values
  end

  def previous_question
    if user_session.session.intervention.draft? && previous_answer.nil?
      Question.find(question_id).position_lower.last&.prepare_to_display(all_var_values)
    else
      previous_answer&.question&.prepare_to_display(all_var_values)
    end
  end
end
