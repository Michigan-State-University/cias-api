# frozen_string_literal: true

# Shared observability for outbound HFHS Cloverleaf calls. Three concerns:
#
# * report_tls_error - when HFHS_SSL_VERIFY is on, a wrong/expired/missing CA surfaces
#   as Faraday::SSLError. These calls run in background jobs that retry (ApplicationJob:
#   StandardError, 10x1h), so without this the failure is invisible. Log loudly + Sentry
#   so the cutover rollback (flip HFHS_SSL_VERIFY off) bites fast. Callers re-raise.
# * report_delivery_status - the services otherwise discard the Faraday response, so a
#   gateway 4xx/5xx neither raises, logs, nor retries: a job can go green with zero
#   delivery. A 2xx stays silent (happy path); only a non-2xx (rejected) is logged
#   warn + Sentry.
# * report_skipped_delivery - a nil auth token makes a sender skip silently; warn +
#   Sentry once so the missed delivery is visible.
#
# All lines are PHI-free: endpoint, HTTP status and the user_session UUID only - never
# answer body or PID content.
module Api::Hfhs::TlsErrorReporter
  def report_tls_error(error, endpoint)
    Rails.logger.error(
      "[Api::Hfhs] TLS verification failed calling #{endpoint}: #{error.message}. " \
      'Check HFHS_CA_CERT, or flip HFHS_SSL_VERIFY off to roll back.'
    )

    Sentry.capture_exception(error) do |scope|
      scope.set_context('hfhs_request', { endpoint: endpoint })
    end
  end

  def report_delivery_status(endpoint, status, label: nil)
    return if status.to_i.between?(200, 299)

    line = "[Api::Hfhs] POST #{endpoint}#{" (#{label})" if label} -> #{status} - delivery not accepted"
    Rails.logger.warn(line)
    Sentry.capture_message(line)
  end

  def report_skipped_delivery(reason)
    message = "[Api::Hfhs] #{reason}"
    Rails.logger.warn(message)
    Sentry.capture_message(message)
  end
end
