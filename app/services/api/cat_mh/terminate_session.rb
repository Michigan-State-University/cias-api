# frozen_string_literal: true

class Api::CatMh::TerminateSession < Api::CatMh::Base
  ENDPOINT = "#{ENV['BASE_CAT_URL']}/interview/signout"

  def call
    result = request(:post, ENDPOINT, params)
    {
      'status' => result.status
    }
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

  def params
    {}.to_json
  end
end
