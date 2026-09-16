# frozen_string_literal: true

class Api::Hfhs::Reports
  include Api::Hfhs::TlsErrorReporter

  ENDPOINT = ENV.fetch('HFHS_URL')

  def self.call(user_session_id)
    new(user_session_id).call
  end

  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
  end

  def call
    return if generated_reports.blank?

    token = Api::Hfhs::Authentication.call
    if token.nil?
      report_skipped_delivery("no token issued - skipping reports send for user_session #{user_session.id}")
      return
    end

    bearer_token = "#{token[:token_type]} #{token[:access_token]}"

    generated_reports.each do |generated_report|
      @hl7_data = Hl7::GeneratedReportMapper.call(user_session.id, generated_report.id)
      send_data!(bearer_token)
    end
  end

  attr_accessor :user_session, :hl7_data

  private

  def generated_reports
    @generated_reports ||= user_session.generated_reports.where(report_for: 'henry_ford_health')
  end

  def send_data!(token)
    connection = Faraday.new ENDPOINT, ssl: Api::Hfhs::SslOptions.call

    response = connection.post do |request|
      request.headers['Content-Type'] = 'application/json'
      request.headers['Authorization'] = token
      request.body = body
    end

    report_delivery_status(ENDPOINT, response.status, label: "report user_session #{user_session.id}")
    response
  rescue Faraday::SSLError => e
    report_tls_error(e, ENDPOINT)
    raise
  end

  def body
    {
      'patient_id' => patient_id,
      'data' => hl7_data
    }.to_json
  end

  def patient_id
    user_session.user.hfhs_patient_detail.patient_id
  end
end
