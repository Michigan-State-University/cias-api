# frozen_string_literal: true

class Api::CatMh::Answer < Api::CatMh::Base
  include Api::Request

  attr_reader :question_id, :response, :duration

  ENDPOINT = "#{ENV.fetch('BASE_CAT_URL', nil)}/interview/rest/interview/test/question".freeze

  def self.call(jsession_id, awselb, question_id, response, duration)
    new(jsession_id, awselb, question_id, response, duration).call
  end

  def initialize(jsession_id, awselb, question_id, response, duration)
    super(jsession_id, awselb)
    @question_id = question_id
    @response = response
    @duration = duration
    @http_method = :post
  end

  def call
    result = request(http_method, ENDPOINT, params)

    return bad_request(result) if result.headers['location'].present?

    {
      'status' => result.status
    }
  end

  private

  def params
    {
      'questionID' => question_id,
      'response' => response,
      'duration' => duration,
      'curT1' => 0,
      'curT2' => 0,
      'curT3' => 0
    }.to_json
  end
end
