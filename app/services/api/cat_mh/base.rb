# frozen_string_literal: true

class Api::CatMh::Base
  include Api::Request

  attr_reader :jsession_id, :awselb, :http_method

  def self.call(jsession_id, awselb)
    new(jsession_id, awselb).call
  end

  def initialize(jsession_id, awselb)
    @jsession_id = jsession_id
    @awselb = awselb
    @http_method = :get
  end

  private

  def cookie
    "JSESSIONID=#{jsession_id}; AWSELB=#{awselb}"
  end

  def params
    {}
  end

  def client
    @client = Faraday.new(self.class::ENDPOINT) do |client|
      client.request :url_encoded
      client.adapter Faraday.default_adapter
      client.headers['Cookie'] = cookie
      client.headers['Content-Type'] = 'application/json'
    end
  end
end
