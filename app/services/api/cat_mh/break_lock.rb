# frozen_string_literal: true

class Api::CatMh::BreakLock < Api::CatMh::Base
  ENDPOINT = "#{ENV['BASE_CAT_URL']}/interview/secure/breakLock"

  def initialize(jsession_id, awselb)
    super(jsession_id, awselb)
    @http_method = :post
  end

  def call
    result = request(http_method, ENDPOINT, params.to_json)
    response(result)
  end

  private

  def client
    @client ||= Faraday.new(ENDPOINT) do |client|
      client.request :url_encoded
      client.adapter Faraday.default_adapter
      client.headers['Cookie'] = cookie
      client.headers['Content-Type'] = 'application/json'
    end
  end
end
