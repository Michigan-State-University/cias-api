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

  def params
    {}.to_json
  end
end
