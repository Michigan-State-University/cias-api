# frozen_string_literal: true

class GenerateUserSessionReportsJob < ApplicationJob
  queue_as :reports

  def perform(user_session_id)
    V1::GeneratedReports::GenerateUserSessionReports.call(
      UserSession.includes(session: { report_templates: %i[sections variants logo_blob logo_attachment] }).find(user_session_id)
    )
  end
end
