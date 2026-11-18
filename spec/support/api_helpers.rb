# frozen_string_literal: true

module ApiHelpers
  def json_response
    Oj.load(response.body)
  end

  def served_file(url)
    get URI(url).path
    follow_redirect!
    response.body.b
  end
end
