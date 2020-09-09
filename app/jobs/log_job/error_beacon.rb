# frozen_string_literal: true

class LogJob::ErrorBeacon < LogJob
  def perform(event)
    Raven.send_event(event)
  end
end
