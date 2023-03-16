# frozen_string_literal: true

class V1::FlowService::ScheduleService
  include FlowServiceHelper

  def initialize(user_session)
    @user_session = user_session
    @additional_information = {}
  end

  attr_accessor :user_session, :additional_information

  def call(question)
    return question unless question.is_a?(Question::Finish) || (question.is_a?(Hash) && question.dig('data', 'attributes', 'type').eql?('Question::Finish'))
    return question unless next_session.present? && next_session.schedule_immediately?

    next_user_session = next_user_session!(next_session)
    user_session.finish(send_email: false)
    additional_information[:next_user_session_id] = next_user_session.id
    additional_information[:next_session_id] = next_user_session.session.id

    next_user_session.first_question
  end

  private

  def next_session
    @next_session ||= user_session.session.next_session
  end
end
