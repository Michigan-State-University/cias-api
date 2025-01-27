# frozen_string_literal: true

class Api::CatMh::Result < Api::CatMh::Base
  ENDPOINT = "#{ENV.fetch('BASE_CAT_URL', nil)}/interview/rest/interview/results".freeze

  def call
    result = request(http_method, ENDPOINT, params)
    response(result)
  end
end
