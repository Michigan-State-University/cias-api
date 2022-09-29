# frozen_string_literal: true

class Api::Hfhs::Reports
  ENDPOINT = ENV.fetch('HFHS_URL')

  def self.call(user_session_id)
    new(user_session_id).call
  end

  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
  end

  def call
    return if generated_reports.blank?

    token  = Api::Hfhs::Authentication.call
    return if token.nil?

    baerer_token = "#{token[:token_type]}  #{token[:access_token]}"

    generated_reports.each do |generate_report|
      @hl7_data = Hl7::GeneratedReportMapper.call(user_session_id, generate_report.id)
      send_data!(baerer_token)
    end
  end

  attr_accessor :user_session, :hl7_data

  private

  def generated_reports
    @generated_reports ||= user_session.generated_reports.where(report_for: 'henry_ford_hospital')
  end

  def send_data!(token)
    Faraday.post(ENDPOINT) do |request|
      request.headers['Content-Type'] = 'application/json'
      request.headers['Authorization'] = token
      request.body = body
    end
  end

  def body
    {
      'patient_id' => patient_id,
      'data' => hl7_data
    }
  end

  def patient_id
    user_session.user.hfhs_patient_detail.patient_id
  end
end
