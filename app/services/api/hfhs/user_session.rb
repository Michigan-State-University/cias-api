# frozen_string_literal: true

class Api::Hfhs::UserSession
  ENDPOINT = ENV.fetch('HFHS_URL')

  def self.call(user_session_id)
    new(user_session_id).call
  end

  def initialize(user_session_id)
    @user_session_id = user_session_id
  end

  def call
    return if no_data_to_hfhs?

    token  = Api::Hfhs::Authentication.call
    return if token.nil?

    baerer_token = "#{token[:token_type]} #{token[:access_token]}"

    connection = Faraday.new ENDPOINT, ssl: { verify: false }

    connection.post do |request|
      request.headers['Content-Type'] = 'application/json'
      request.headers['Authorization'] = baerer_token
      request.body = body
    end
  end

  attr_reader :user_session_id

  private

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
