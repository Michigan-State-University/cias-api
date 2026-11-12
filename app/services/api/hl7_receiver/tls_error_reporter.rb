# frozen_string_literal: true

# Shared observability for outbound calls to the site's HL7 receiver (Cloverleaf for Henry
# Ford). Three concerns:
#
# * report_tls_error - when HL7_RECEIVER_SSL_VERIFY is on, a wrong/expired/missing CA surfaces
#   as Faraday::SSLError. These calls run in background jobs that retry (ApplicationJob:
#   StandardError, 10x1h), so without this the failure is invisible. Log loudly + Sentry
#   so the cutover rollback (HL7_RECEIVER_SSL_VERIFY=false) bites fast. Callers re-raise.
# * report_delivery_status - the services otherwise discard the Faraday response, so a
#   gateway 4xx/5xx neither raises, logs, nor retries: a job can go green with zero
#   delivery. A 2xx stays silent (happy path); only a non-2xx (rejected) is logged
#   warn + Sentry.
# * report_skipped_delivery - a nil auth token makes a sender skip silently; warn +
#   Sentry once so the missed delivery is visible.
#
# All lines are PHI-free: endpoint, HTTP status and the user_session UUID only - never
# answer body or PID content.
module Api::Hl7Receiver::TlsErrorReporter
  LOG_PREFIX = '[HL7 receiver]'

  def report_tls_error(error, endpoint)
    Rails.logger.error(
      "#{LOG_PREFIX} TLS verification failed calling #{endpoint}: #{error.message}. " \
      'Check HL7_RECEIVER_CA_CERT (or HFHS_CA_CERT), or set HL7_RECEIVER_SSL_VERIFY=false to roll back.'
    )

    Sentry.capture_exception(error) do |scope|
      scope.set_context('hl7_receiver_request', { endpoint: endpoint })
    end
  end

  def report_delivery_status(endpoint, status, label: nil)
    return if status.to_i.between?(200, 299)

    line = "#{LOG_PREFIX} POST #{endpoint}#{" (#{label})" if label} -> #{status} - delivery not accepted"
    Rails.logger.warn(line)
    Sentry.capture_message(line)
  end

  def report_skipped_delivery(reason)
    message = "#{LOG_PREFIX} #{reason}"
    Rails.logger.warn(message)
    Sentry.capture_message(message)
  end
end
