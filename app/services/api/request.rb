# frozen_string_literal: true

module Api::Request
  def request(http_method, endpoint, params = {}.to_json)
    client.public_send(http_method, endpoint, params)
  end

  def response(result)
    {
      'status' => result.status,
      'body' => JSON.parse(result.body)
    }
  end
end
