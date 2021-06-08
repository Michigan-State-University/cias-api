# frozen_string_literal: true

class LogJobs::UserRequest < LogJob
  def perform(request)
    UserLogRequest.create!(request)
  end
end
