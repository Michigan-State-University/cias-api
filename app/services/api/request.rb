# frozen_string_literal: true

module Api::Request
  def request(http_method, endpoint, params = {}.to_json)
    client.public_send(http_method, endpoint, params)
  end

  def response(result)
    return bad_request(result) if result.headers['location'].present? || result.reason_phrase.eql?('Request Time-out')

    {
      'status' => result.status,
      'body' => JSON.parse(result.body)
    }
  end

  def bad_request(result)
    {
      'status' => 400,
      'error' => result.headers['location'].presence || 'Request Time-out'
    }
  end
end
