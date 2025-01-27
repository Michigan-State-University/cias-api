# frozen_string_literal: true

class Api::CatMh::TerminateSession < Api::CatMh::Base
  ENDPOINT = "#{ENV.fetch('BASE_CAT_URL', nil)}/interview/signout".freeze

  def call
    result = request(:post, ENDPOINT, params)
    {
      'status' => result.status
    }
  end

  private

  def params
    {}.to_json
  end
end
