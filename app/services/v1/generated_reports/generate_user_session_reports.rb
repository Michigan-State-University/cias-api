# frozen_string_literal: true

class V1::GeneratedReports::GenerateUserSessionReports
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
  end

  def call
    return if session_preview?

    dentaku_service.store_and_transform_values

    report_templates.each do |report_template|
      V1::GeneratedReports::Create.call(report_template, user_session, dentaku_service)
    end

    user_session.reload

    V1::GeneratedReports::ShareToParticipant.call(user_session)
    V1::GeneratedReports::ShareToThirdParty.call(user_session)
  end

  private

  attr_reader :user_session

  def dentaku_service
    @dentaku_service ||= Calculations::DentakuService.new(all_var_values)
  end

  def session_preview?
    user.role?('preview_session')
  end

  def user
    user_session.user
  end

  def session
    user_session.session
  end

  def answers
    user_session.answers
  end

  def report_templates
    session.report_templates.includes(:logo_blob, :logo_attachment, :variants, sections: [variants: [image_attachment: :blob]])
  end

  def all_var_values
    V1::UserInterventionService.new(user.id, user_session.session.intervention_id, user_session.id).var_values
  end
end
