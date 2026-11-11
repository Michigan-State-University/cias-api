# frozen_string_literal: true

# Site-specific EHR values, read from the environment where they are used (never at boot or class
# load, so a site without an EHR integration still boots).
#
# * HL7 values (MSH-4, MSH-6, MSH-11, TXA-2, the OBX-5 prefix) are required and have no defaults: each
#   site's receiving system assigns its own. A blank value counts as missing, because CI's .env.template
#   sets blanks. Reading a missing one raises MissingSettingError naming the setting; one that would break
#   the message structure (see UNSAFE_HL7_VALUE) raises InvalidSettingError.
# * Site identity (EHR_SITE_NAME, EHR_CSV_PREFIX) falls back to a generic value, never a site's own.
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

    # "HL7_PROCESSING_ID (or PROCESSING)": names the legacy setting too, so either can be fixed.
    def label(name, legacy = HL7_LEGACY_NAMES[name])
      legacy ? "#{name} (or #{legacy})" : name
    end
  end
end
