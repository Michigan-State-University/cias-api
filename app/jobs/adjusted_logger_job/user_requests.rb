# frozen_string_literal: true

class AdjustedLoggerJob::UserRequests < AdjustedLoggerJob
  def perform(request)
    UserLogRequest.create!(request)
  end
end
