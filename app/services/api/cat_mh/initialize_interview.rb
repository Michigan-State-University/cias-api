# frozen_string_literal: true

class Api::CatMh::InitializeInterview < Api::CatMh::Base
  ENDPOINT = "#{ENV['BASE_CAT_URL']}/interview/rest/interview".freeze

  def call
    result = request(http_method, ENDPOINT, params)
    response(result)
  end
end
