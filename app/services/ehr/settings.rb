# frozen_string_literal: true

# Site-specific EHR values, read from the environment where they are used (never at boot or class
# load, so a site without an EHR integration still boots).
#
# * HL7 values (MSH-4, MSH-6, MSH-11, TXA-2, the OBX-5 prefix) are required and have no defaults: each
#   site's receiving system assigns its own. A blank value counts as missing, because CI's .env.template
#   sets blanks. Reading a missing one raises MissingSettingError naming the setting; one that would break
#   the message structure (see UNSAFE_HL7_VALUE) raises InvalidSettingError.
# * Site identity (EHR_SITE_NAME, EHR_CSV_PREFIX) falls back to a generic value, never a site's own.
# * Code scanning is off unless the feature flag EHR_BARCODE_SCAN_FEATURE_ENABLED is 1
#   (barcode_scan_available?). The barcode values (where the patient ID sits in a scanned code and what a
#   valid one looks like) have no defaults. A value that isn't a usable regular expression, or starts or
#   ends with whitespace (it would silently match nothing), raises InvalidSettingError naming the setting,
#   never its value.
# * Settings that were renamed from Henry Ford-specific names are read with .fetch(new, legacy:): the old
#   name still works while the new one is blank (expand and contract).
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

  # Required settings that replaced an older name; the old name is read while the new one is blank.
  HL7_LEGACY_NAMES = {
    'HL7_PROCESSING_ID' => 'PROCESSING'
  }.freeze

  # An HL7 value must not contain the field (|) or repetition (~) separator, a line break (the segment
  # separator) or a double quote (HL7's null marker; usually a value pasted with its quotes), and must not
  # start or end with whitespace. The component (^), subcomponent (&) and escape (\) characters stay
  # allowed: HD/CWE values and the OBX-5 prefix (ED source application) use them.
  UNSAFE_HL7_VALUE = /[|~\r\n"]|\A[[:space:]]|[[:space:]]\z/

  DEFAULT_SITE_NAME = 'EHR'
  # Distinct from a likely session variable: CSV columns are "<session variable>.<question variable>".
  DEFAULT_CSV_PREFIX = 'ehr_patient'

  BARCODE_PATIENT_ID_PATTERN = 'EHR_BARCODE_PATIENT_ID_PATTERN'
  BARCODE_PATIENT_ID_FORMAT = 'EHR_BARCODE_PATIENT_ID_FORMAT'
  BARCODE_IDENTIFIER_SYSTEM = 'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM'
  BARCODE_SCAN_FEATURE_FLAG = 'EHR_BARCODE_SCAN_FEATURE_ENABLED'
  BARCODE_SCAN_REQUIRED_SETTINGS = [BARCODE_PATIENT_ID_PATTERN, BARCODE_IDENTIFIER_SYSTEM].freeze
  BARCODE_PATIENT_ID_GROUP = 'patient_id'
  # Seconds; the barcode regexes run on participant input.
  BARCODE_REGEXP_TIMEOUT = 0.1
  # Like the HL7 values: a pasted value with a stray space or line break would quietly reject every scan.
  SURROUNDING_WHITESPACE = /\A[[:space:]]|[[:space:]]\z/

  class << self
    # The first non-blank value of the setting or its legacy name; nil when both are blank or unset.
    def fetch(name, legacy:)
      ENV.fetch(name, nil).presence || (legacy && ENV.fetch(legacy, nil).presence)
    end

    # Like fetch, for a setting a send can't do without (the receiver URLs): reports to Sentry and the log,
    # then raises MissingSettingError naming both settings instead of returning nil. A nil URL would
    # otherwise reach Faraday, which connects to localhost and fails with an error that names no setting.
    # The report is explicit for the same reason as in ensure_hl7_values!: the sending job retries and
    # sentry-rails does not report retried job errors. Setting names only, never their values.
    def fetch!(name, legacy:)
      value = fetch(name, legacy: legacy)
      return value if value

      error = "#{label(name, legacy)} is not set"
      message = "[Ehr::Settings] HL7 send stopped, #{error}"
      Rails.logger.error(message)
      Sentry.capture_message(message)
      raise MissingSettingError, error
    end

    # MSH-4
    def hl7_sending_facility
      required('HL7_SENDING_FACILITY')
    end

    # MSH-6
    def hl7_receiving_facility
      required('HL7_RECEIVING_FACILITY')
    end

    # MSH-11 (P production, T training/test)
    def hl7_processing_id
      required('HL7_PROCESSING_ID')
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

    # On only at exactly 1; surrounding whitespace is ignored, like the web build's flags.
    def barcode_scan_enabled?
      ENV.fetch(BARCODE_SCAN_FEATURE_FLAG, nil).to_s.strip == '1'
    end

    def missing_barcode_scan_settings
      BARCODE_SCAN_REQUIRED_SETTINGS.select { |name| ENV.fetch(name, nil).blank? }
    end

    # Flag off is a normal state and stays silent. Flag on with a required setting blank is a misconfiguration:
    # logged and reported to Sentry by setting name, never value. Non-blank values are checked when read.
    def barcode_scan_available?
      return false unless barcode_scan_enabled?

      missing = missing_barcode_scan_settings
      return true if missing.empty?

      message = "[Ehr::Settings] code scanning is on but required settings are blank: #{missing.join(', ')}"
      Rails.logger.error(message)
      Sentry.capture_message(message)
      false
    end

    # Where the patient ID sits in the scanned text: a regex with the named group patient_id.
    def barcode_patient_id_pattern
      pattern = barcode_regexp(BARCODE_PATIENT_ID_PATTERN)
      raise MissingSettingError, "#{BARCODE_PATIENT_ID_PATTERN} is not set" if pattern.nil?
      unless pattern.names.include?(BARCODE_PATIENT_ID_GROUP)
        raise InvalidSettingError, "#{BARCODE_PATIENT_ID_PATTERN} has no named group #{BARCODE_PATIENT_ID_GROUP}"
      end

      pattern
    end

    # What a valid patient ID looks like; nil when blank.
    def barcode_patient_id_format
      barcode_regexp(BARCODE_PATIENT_ID_FORMAT)
    end

    def missing_hl7_settings
      HL7_REQUIRED_SETTINGS.select { |name| hl7_value(name).blank? }.map { |name| label(name) }
    end

    def invalid_hl7_settings
      HL7_REQUIRED_SETTINGS.select { |name| hl7_value(name)&.match?(UNSAFE_HL7_VALUE) }.map { |name| label(name) }
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
      value = hl7_value(name)
      raise MissingSettingError, "#{label(name)} is not set" if value.blank?
      raise InvalidSettingError, "#{label(name)} contains HL7 delimiters, quotes or surrounding whitespace" if value.match?(UNSAFE_HL7_VALUE)

      value
    end

    def hl7_value(name)
      fetch(name, legacy: HL7_LEGACY_NAMES[name])
    end

    # cause: nil keeps RegexpError, whose message quotes the value, out of Sentry's exception chain.
    def barcode_regexp(name)
      value = ENV.fetch(name, nil)
      return if value.blank?

      regexp = Regexp.new(value, timeout: BARCODE_REGEXP_TIMEOUT)
      raise InvalidSettingError, "#{name} starts or ends with whitespace" if value.match?(SURROUNDING_WHITESPACE)

      regexp
    rescue RegexpError
      raise InvalidSettingError, "#{name} is not a valid regular expression", cause: nil
    end

    # "HL7_PROCESSING_ID (or PROCESSING)": names the legacy setting too, so either can be fixed.
    def label(name, legacy = HL7_LEGACY_NAMES[name])
      legacy ? "#{name} (or #{legacy})" : name
    end
  end
end
