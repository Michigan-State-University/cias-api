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

    dentaku_calculator.store(**all_var_values) if all_var_values.present?

    report_templates.each do |report_template|
      V1::GeneratedReports::Create.call(
        report_template,
        user_session,
        dentaku_calculator
      )
    end
  end

  private

  attr_reader :user_session

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

  def dentaku_calculator
    @dentaku_calculator ||= Dentaku::Calculator.new
  end

  def report_templates
    session.report_templates.includes(sections: [variants: [image_attachment: :blob]])
  end

  def all_var_values
    user_session.all_var_values
  end
end
