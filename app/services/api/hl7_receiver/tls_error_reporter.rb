# frozen_string_literal: true

# Reports HL7 receiver failures that would otherwise stay silent (retried TLS errors, rejected or skipped
# deliveries). Endpoint, status and IDs only, never PHI.
module Api::Hl7Receiver::TlsErrorReporter
  LOG_PREFIX = '[HL7 receiver]'

  def report_tls_error(error, endpoint)
    Rails.logger.error(
      "#{LOG_PREFIX} TLS verification failed calling #{endpoint}: #{error.message}. " \
      'Check HL7_RECEIVER_CA_CERT, or set HL7_RECEIVER_SSL_VERIFY=false to roll back.'
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
