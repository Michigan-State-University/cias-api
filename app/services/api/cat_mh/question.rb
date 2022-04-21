# frozen_string_literal: true

class Api::CatMh::Question < Api::CatMh::Base
  ENDPOINT = "#{ENV['BASE_CAT_URL']}/interview/rest/interview/test/question"

  def call
    result = request(http_method, ENDPOINT, params)
    response(result)
  end

  private

  def client
    @client = Faraday.new(ENDPOINT) do |client|
      client.request :url_encoded
      client.adapter Faraday.default_adapter
      client.headers['Cookie'] = cookie
      client.headers['Content-Type'] = 'application/json'
    end
  end
end
