# frozen_string_literal: true

class Hfhs::SendAnswersJob < ApplicationJob
  queue_as :hfhs

  def perform(user_session_id)
    api = Api::Hfhs.new
    api.send_answers(user_session_id)
    api.send_reports(user_session_id)
  end
end
