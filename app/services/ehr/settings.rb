# frozen_string_literal: true

# Site-specific EHR values, read from the environment where they are used (never at boot or class
# load, so a site without an EHR integration still boots).
#
# * HL7 values (MSH-4, MSH-6, TXA-2, the OBX-5 prefix) are required and have no defaults: each site's
#   receiving system assigns its own. A blank value counts as missing, because CI's .env.template sets
#   blanks. Reading a missing one raises MissingSettingError naming the setting; one that would break the
#   message structure (see UNSAFE_HL7_VALUE) raises InvalidSettingError.
# * Site identity (EHR_SITE_NAME, EHR_CSV_PREFIX) falls back to a generic value, never a site's own.
class Ehr::Settings
  MissingSettingError = Class.new(StandardError)
  InvalidSettingError = Class.new(StandardError)

  HL7_REQUIRED_SETTINGS = %w[
    HL7_SENDING_FACILITY
    HL7_RECEIVING_FACILITY
    HL7_DOCUMENT_TYPE
    HL7_OBSERVATION_VALUE_PREFIX
  ].freeze

  # An HL7 value must not contain the field (|) or repetition (~) separator, a line break (the segment
  # separator) or a double quote (HL7's null marker; usually a value pasted with its quotes), and must not
  # start or end with whitespace. The component (^), subcomponent (&) and escape (\) characters stay
  # allowed: HD/CWE values and the OBX-5 prefix (ED source application) use them.
  UNSAFE_HL7_VALUE = /[|~\r\n"]|\A[[:space:]]|[[:space:]]\z/

  DEFAULT_SITE_NAME = 'EHR'
  # Distinct from a likely session variable: CSV columns are "<session variable>.<question variable>".
  DEFAULT_CSV_PREFIX = 'ehr_patient'

  class << self
    # MSH-4
    def hl7_sending_facility
      required('HL7_SENDING_FACILITY')
    end

    # MSH-6
    def hl7_receiving_facility
      required('HL7_RECEIVING_FACILITY')
    end

    # TXA-2
    def hl7_document_type
      required('HL7_DOCUMENT_TYPE')
    end

    # OBX-5 prefix of the encapsulated PDF report
    def hl7_observation_value_prefix
      required('HL7_OBSERVATION_VALUE_PREFIX')
    end

    def site_name
      ENV.fetch('EHR_SITE_NAME', nil).presence || DEFAULT_SITE_NAME
    end

    def csv_prefix
      ENV.fetch('EHR_CSV_PREFIX', nil).presence || DEFAULT_CSV_PREFIX
    end

    def missing_hl7_settings
      HL7_REQUIRED_SETTINGS.select { |name| ENV.fetch(name, nil).blank? }
    end

    def invalid_hl7_settings
      HL7_REQUIRED_SETTINGS.select do |name|
        value = ENV.fetch(name, nil)
        value.present? && value.match?(UNSAFE_HL7_VALUE)
      end
    end

    # Called once before anything is sent. The sending job retries (ApplicationJob: StandardError,
    # 10 attempts 1 h apart) and sentry-rails does not report retried job errors, so without the explicit
    # Sentry message a missing value stays invisible for about 9 hours; checking all values up front also
    # stops a report-only value from failing after the answers message (PHI) has already gone out.
    # Setting names only, never their values or message content.
    def ensure_hl7_values!
      missing = missing_hl7_settings
      invalid = invalid_hl7_settings
      return if missing.empty? && invalid.empty?

      problems = []
      problems << "required settings are blank: #{missing.join(', ')}" if missing.any?
      problems << "settings contain HL7 delimiters, quotes or surrounding whitespace: #{invalid.join(', ')}" if invalid.any?
      message = "[Ehr::Settings] HL7 send stopped, #{problems.join('; ')}"
      Rails.logger.error(message)
      Sentry.capture_message(message)
      raise(missing.any? ? MissingSettingError : InvalidSettingError, message)
    end

    private

    def required(name)
      value = ENV.fetch(name, nil)
      raise MissingSettingError, "#{name} is not set" if value.blank?
      raise InvalidSettingError, "#{name} contains HL7 delimiters, quotes or surrounding whitespace" if value.match?(UNSAFE_HL7_VALUE)

      value
    end
  end
end
