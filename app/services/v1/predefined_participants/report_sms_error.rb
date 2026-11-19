# frozen_string_literal: true

class V1::PredefinedParticipants::ReportSmsError
  def self.call(error_class, label, extra:, backtrace: nil)
    error = error_class.new(label)
    error.set_backtrace(backtrace) if backtrace
    Sentry.capture_exception(error, extra: extra)
  end
end
