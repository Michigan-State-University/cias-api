# frozen_string_literal: true

# Site-specific EHR settings, read when used so a site without an EHR integration still boots.
# What each one means: docs/ehr-integration-settings.md
class Ehr::Settings
  MissingSettingError = Class.new(StandardError)
  InvalidSettingError = Class.new(StandardError)

  HL7_REQUIRED_SETTINGS = %w[
    HL7_SENDING_FACILITY
    HL7_RECEIVING_FACILITY
    HL7_PROCESSING_ID
    HL7_DOCUMENT_TYPE
    HL7_OBSERVATION_VALUE_PREFIX
  ].freeze

  # " is HL7's null marker (usually a value pasted with its quotes); ^, & and \ stay allowed: HD/CWE
  # values and the OBX-5 prefix use them.
  UNSAFE_HL7_VALUE = /[|~\r\n"]|\A[[:space:]]|[[:space:]]\z/

  DEFAULT_SITE_NAME = 'EHR'
  DEFAULT_CSV_PREFIX = 'ehr_patient'

  BARCODE_PATIENT_ID_PATTERN = 'EHR_BARCODE_PATIENT_ID_PATTERN'
  BARCODE_IDENTIFIER_SYSTEM = 'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM'
  BARCODE_SCAN_FEATURE_FLAG = 'EHR_BARCODE_SCAN_FEATURE_ENABLED'
  BARCODE_SCAN_REQUIRED_SETTINGS = [BARCODE_PATIENT_ID_PATTERN, BARCODE_IDENTIFIER_SYSTEM].freeze
  BARCODE_PATIENT_ID_GROUP = 'patient_id'
  # Seconds; the barcode regexes run on participant input (ReDoS).
  BARCODE_REGEXP_TIMEOUT = 0.1
  SURROUNDING_WHITESPACE = /\A[[:space:]]|[[:space:]]\z/

  class << self
    def fetch(name)
      ENV.fetch(name, nil).presence
    end

    # Reported explicitly: the sending job retries, and sentry-rails skips retried job errors.
    def fetch!(name)
      value = fetch(name)
      return value if value

      error = "#{name} is not set"
      message = "[Ehr::Settings] HL7 send stopped, #{error}"
      Rails.logger.error(message)
      Sentry.capture_message(message)
      raise MissingSettingError, error
    end

    def hl7_sending_facility
      required('HL7_SENDING_FACILITY')
    end

    def hl7_receiving_facility
      required('HL7_RECEIVING_FACILITY')
    end

    def hl7_processing_id
      required('HL7_PROCESSING_ID')
    end

    def hl7_document_type
      required('HL7_DOCUMENT_TYPE')
    end

    def hl7_observation_value_prefix
      required('HL7_OBSERVATION_VALUE_PREFIX')
    end

    def site_name
      ENV.fetch('EHR_SITE_NAME', nil).presence || DEFAULT_SITE_NAME
    end

    def csv_prefix
      ENV.fetch('EHR_CSV_PREFIX', nil).presence || DEFAULT_CSV_PREFIX
    end

    def barcode_scan_enabled?
      ENV.fetch(BARCODE_SCAN_FEATURE_FLAG, nil).to_s.strip == '1'
    end

    def missing_barcode_scan_settings
      BARCODE_SCAN_REQUIRED_SETTINGS.select { |name| ENV.fetch(name, nil).blank? }
    end

    def barcode_scan_available?
      return false unless barcode_scan_enabled?

      missing = missing_barcode_scan_settings
      return true if missing.empty?

      message = "[Ehr::Settings] code scanning is on but required settings are blank: #{missing.join(', ')}"
      Rails.logger.error(message)
      Sentry.capture_message(message)
      false
    end

    def barcode_patient_id_pattern
      pattern = barcode_regexp(BARCODE_PATIENT_ID_PATTERN)
      raise MissingSettingError, "#{BARCODE_PATIENT_ID_PATTERN} is not set" if pattern.nil?
      unless pattern.names.include?(BARCODE_PATIENT_ID_GROUP)
        raise InvalidSettingError, "#{BARCODE_PATIENT_ID_PATTERN} has no named group #{BARCODE_PATIENT_ID_GROUP}"
      end

      pattern
    end

    def missing_hl7_settings
      HL7_REQUIRED_SETTINGS.select { |name| fetch(name).nil? }
    end

    def invalid_hl7_settings
      HL7_REQUIRED_SETTINGS.select { |name| fetch(name)&.match?(UNSAFE_HL7_VALUE) }
    end

    # Checked before the answers (PHI) go out, so a report-only value can't fail halfway; reported like fetch!.
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
      value = fetch(name)
      raise MissingSettingError, "#{name} is not set" if value.nil?
      raise InvalidSettingError, "#{name} contains HL7 delimiters, quotes or surrounding whitespace" if value.match?(UNSAFE_HL7_VALUE)

      value
    end

    # cause: nil keeps RegexpError, whose message quotes the value, out of Sentry.
    def barcode_regexp(name)
      value = ENV.fetch(name, nil)
      return if value.blank?

      regexp = Regexp.new(value, timeout: BARCODE_REGEXP_TIMEOUT)
      raise InvalidSettingError, "#{name} starts or ends with whitespace" if value.match?(SURROUNDING_WHITESPACE)

      regexp
    rescue RegexpError
      raise InvalidSettingError, "#{name} is not a valid regular expression", cause: nil
    end
  end
end
