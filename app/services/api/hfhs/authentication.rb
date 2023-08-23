# frozen_string_literal: true

class Api::Hfhs::Authentication
  ENDPOINT = ENV.fetch('HFHS_TOKEN_URL')

  def self.call
    new.call
  end

  def call
    response = Faraday.post(ENDPOINT) do |request|
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(params)
    end

    JSON.parse(response.body).symbolize_keys if response.status == 200
  end

  private

  def params
    {
      grant_type: 'password',
      username: ENV.fetch('HFHS_USERNAME'),
      client_id: ENV.fetch('HFHS_CLIENT_ID'),
      client_secret: ENV.fetch('HFHS_CLIENT_SECRET'),
      password: ENV.fetch('HFHS_PASSWORD')
    }
  end
end
