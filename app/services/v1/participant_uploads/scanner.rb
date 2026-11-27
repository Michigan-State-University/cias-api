# frozen_string_literal: true

class V1::ParticipantUploads::Scanner
  class UnknownScannerError < StandardError; end
  class InsecureScannerError < StandardError; end

  GUARD_DUTY = 'guard_duty'

  ADAPTERS = {
    GUARD_DUTY => 'V1::ParticipantUploads::GuardDutyS3Adapter',
    'accept_all' => 'V1::ParticipantUploads::AcceptAllAdapter'
  }.freeze

  def self.build
    name = Settings.participant_uploads.scanner.to_s
    raise UnknownScannerError, "unknown participant upload scanner: #{name}" unless ADAPTERS.key?(name)

    raise InsecureScannerError, "#{name} must never run in production" if name != GUARD_DUTY && Rails.env.production?

    ADAPTERS.fetch(name).constantize.new
  end
end
