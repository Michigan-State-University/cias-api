# frozen_string_literal: true

class LogJob::UserRequest < LogJob
  def perform(request)
    UserLogRequest.create!(request)
  end
end
