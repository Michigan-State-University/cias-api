# frozen_string_literal: true

class Api::Hl7Receiver::UserSession
  include Api::Hl7Receiver::TlsErrorReporter

  def self.call(user_session_id)
    new(user_session_id).call
  end

  def initialize(user_session_id)
    @user_session_id = user_session_id
  end

  def call
    return if no_ehr_answers?

    token = Api::Hl7Receiver::Authentication.call
    if token.nil?
      report_skipped_delivery("no token issued - skipping answers send for user_session #{user_session_id}")
      return
    end

    post_answers("#{token[:token_type]} #{token[:access_token]}")
  end

  attr_reader :user_session_id

  private

  def endpoint
    Ehr::Settings.fetch!('HL7_RECEIVER_URL')
  end

  def post_answers(bearer_token)
    connection = Faraday.new endpoint, ssl: Api::Hl7Receiver::SslOptions.call

    response = connection.post do |request|
      request.headers['Content-Type'] = 'application/json'
      request.headers['Authorization'] = bearer_token
      request.body = body
    end

    report_delivery_status(endpoint, response.status, label: "answers user_session #{user_session_id}")
    response
  rescue Faraday::SSLError => e
    report_tls_error(e, endpoint)
    raise
  end

  def body
    {
      'patient_id' => patient_id,
      'data' => hl7_data
    }.to_json
  end

  def user_session
    @user_session ||= UserSession.find(user_session_id)
  end

  def patient_id
    user_session.user.hfhs_patient_detail.patient_id
  end

  def hl7_data
    Hl7::UserSessionMapper.call(user_session_id)
  end

  def no_ehr_answers?
    user_session.answers.ehr.none?
  end
end
