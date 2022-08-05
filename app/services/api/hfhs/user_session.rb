# frozen_string_literal: true

class Api::Hfhs::UserSession
  ENDPOINT = ENV.fetch('HFHS_URL')

  def self.call(user_session_id)
    new(user_session_id)
  end

  def initialize(user_session_id)
    @user_session_id = user_session_id
  end

  def call
    token  = Api::Hfhs::Authentication.call
    return if token.nil?

    baerer_token = "#{token[:token_type]}  #{token[:access_token]}"
    @hl7_data = Hl7::UserSessionMapper.call(user_session_id)

    Faraday.post(ENDPOINT) do |request|
      request.headers['Content-Type'] = 'application/json'
      request.headers['Authorization'] = baerer_token
      request.body = body
    end
  end

  attr_reader :user_session_id
  attr_accessor :hl7_data

  private

  def body
    {
      'patient_id' => patient_id,
      'data' => hl7_data
    }
  end

  def patient_id
    UserSession.find(user_session_id).user.hfhs_patient_id
  end
end
