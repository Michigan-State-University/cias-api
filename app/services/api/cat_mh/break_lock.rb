# frozen_string_literal: true

class Api::CatMh::BreakLock < Api::CatMh::Base
  ENDPOINT = "#{ENV.fetch('BASE_CAT_URL', nil)}/interview/secure/breakLock".freeze

  def initialize(jsession_id, awselb)
    super
    @http_method = :post
  end

  def call
    result = request(http_method, ENDPOINT, params.to_json)
    response(result)
  end
end
