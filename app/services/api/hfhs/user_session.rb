# frozen_string_literal: true

class Api::Hfhs::UserSession
  include Api::Hfhs::TlsErrorReporter

  ENDPOINT = ENV.fetch('HFHS_URL')

  def self.call(user_session_id)
    new(user_session_id).call
  end

  def initialize(user_session_id)
    @user_session_id = user_session_id
  end

  def call
    return if no_data_to_hfhs?

    token = Api::Hfhs::Authentication.call
    if token.nil?
      report_skipped_delivery("no token issued - skipping answers send for user_session #{user_session_id}")
      return
    end

    post_answers("#{token[:token_type]} #{token[:access_token]}")
  end

  attr_reader :user_session_id

  private

  def post_answers(bearer_token)
    connection = Faraday.new ENDPOINT, ssl: Api::Hfhs::SslOptions.call

    response = connection.post do |request|
      request.headers['Content-Type'] = 'application/json'
      request.headers['Authorization'] = bearer_token
      request.body = body
    end

    report_delivery_status(ENDPOINT, response.status, label: "answers user_session #{user_session_id}")
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

  def user_session
    @user_session ||= UserSession.find(user_session_id)
  end

  def patient_id
    user_session.user.hfhs_patient_detail.patient_id
  end

  def hl7_data
    Hl7::UserSessionMapper.call(user_session_id)
  end

  def no_data_to_hfhs?
    user_session.answers.where(type: 'Answer::HenryFord').blank?
  end
end
