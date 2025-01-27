# frozen_string_literal: true

class Api::CatMh::Question < Api::CatMh::Base
  ENDPOINT = "#{ENV.fetch('BASE_CAT_URL', nil)}/interview/rest/interview/test/question".freeze

  def call
    result = request(http_method, ENDPOINT, params)
    response(result)
  end
end
