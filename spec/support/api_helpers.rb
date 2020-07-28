# frozen_string_literal: true

module ApiHelpers
  def json_response
    Oj.load(response.body)
  end
end
