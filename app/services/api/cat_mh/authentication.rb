# frozen_string_literal: true

class Api::CatMh::Authentication
  attr_reader :signature, :identifier

  ENDPOINT = "#{ENV['BASE_CAT_URL']}/interview/signin"

  def self.call(identifier, signature)
    new(identifier, signature).call
  end

  def initialize(identifier, signature)
    @identifier = identifier
    @signature = signature
  end

  def call
    result = Faraday.post(ENDPOINT) do |request|
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(params)
    end

    {
      'status' => result.status,
      'cookies' => cookie(result)
    }
  end

  private

  def params
    {
      'j_username' => identifier,
      'j_password' => signature
    }
  end

  def cookie(result)
    return unless result.status.eql?(302)

    cookies = result.headers['set-cookie']
    {
      'JSESSIONID' => cookies[/JSESSIONID=(.*?);/m, 1],
      'AWSELB' => cookies[/AWSELB=(.*?);/m, 1]
    }
  end
end
