# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ehr::Settings do
  describe '.site_name' do
    context 'when EHR_SITE_NAME is set' do
      include_context 'with environment variables', { 'EHR_SITE_NAME' => 'Example Health' }

      it { expect(described_class.site_name).to eq('Example Health') }
    end

    context 'when EHR_SITE_NAME is blank' do
      include_context 'with environment variables', { 'EHR_SITE_NAME' => '' }

      it 'falls back to the generic name' do
        expect(described_class.site_name).to eq('EHR')
      end
    end

    context 'when EHR_SITE_NAME is not set at all' do
      include_context 'with environment variables', { 'EHR_SITE_NAME' => nil }

      it 'falls back to the generic name' do
        expect(described_class.site_name).to eq('EHR')
      end
    end
  end

  describe '.csv_prefix' do
    context 'when EHR_CSV_PREFIX is set' do
      include_context 'with environment variables', { 'EHR_CSV_PREFIX' => 'example_health' }

      it { expect(described_class.csv_prefix).to eq('example_health') }
    end

    context 'when EHR_CSV_PREFIX is blank' do
      include_context 'with environment variables', { 'EHR_CSV_PREFIX' => ' ' }

      it 'falls back to the generic prefix' do
        expect(described_class.csv_prefix).to eq('ehr_patient')
      end
    end

    context 'when EHR_CSV_PREFIX is not set at all' do
      include_context 'with environment variables', { 'EHR_CSV_PREFIX' => nil }

      it 'falls back to the generic prefix' do
        expect(described_class.csv_prefix).to eq('ehr_patient')
      end
    end
  end

  {
    hl7_sending_facility: 'HL7_SENDING_FACILITY',
    hl7_receiving_facility: 'HL7_RECEIVING_FACILITY',
    hl7_processing_id: 'HL7_PROCESSING_ID',
    hl7_document_type: 'HL7_DOCUMENT_TYPE',
    hl7_observation_value_prefix: 'HL7_OBSERVATION_VALUE_PREFIX'
  }.each do |reader, setting|
    describe ".#{reader}" do
      context "when #{setting} is set" do
        include_context 'with environment variables', { setting => 'SITE^VALUE' }

        it { expect(described_class.public_send(reader)).to eq('SITE^VALUE') }
      end

      context "when #{setting} is blank" do
        include_context 'with environment variables', { setting => '' }

        it 'raises an error naming the setting' do
          expect { described_class.public_send(reader) }
            .to raise_error(Ehr::Settings::MissingSettingError, "#{setting} is not set")
        end
      end

      context "when #{setting} is not set at all" do
        include_context 'with environment variables', { setting => nil }

        it 'raises an error naming the setting' do
          expect { described_class.public_send(reader) }
            .to raise_error(Ehr::Settings::MissingSettingError, "#{setting} is not set")
        end
      end
    end
  end

  describe '.fetch' do
    subject(:value) { described_class.fetch('HL7_RECEIVER_URL') }

    context 'when the setting is set' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => 'https://receiver.test' }

      it { expect(value).to eq('https://receiver.test') }
    end

    [nil, '', ' '].each do |blank|
      context "when the setting is #{blank.inspect}" do
        include_context 'with environment variables', { 'HL7_RECEIVER_URL' => blank }

        it { expect(value).to be_nil }
      end
    end
  end

  describe '.fetch!' do
    subject(:value) { described_class.fetch!('HL7_RECEIVER_URL') }

    before do
      allow(Sentry).to receive(:capture_message)
      allow(Rails.logger).to receive(:error)
    end

    context 'when the setting is set' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => 'https://receiver.test' }

      it 'returns it without reporting' do
        expect(value).to eq('https://receiver.test')
        expect(Sentry).not_to have_received(:capture_message)
      end
    end

    [nil, '', ' '].each do |blank|
      context "when the setting is #{blank.inspect}" do
        include_context 'with environment variables', { 'HL7_RECEIVER_URL' => blank }

        let(:expected_message) { '[Ehr::Settings] HL7 send stopped, HL7_RECEIVER_URL is not set' }

        it 'raises naming the setting' do
          expect { value }.to raise_error(Ehr::Settings::MissingSettingError, 'HL7_RECEIVER_URL is not set')
        end

        it 'reports the setting name to Sentry and the log on the first attempt' do
          expect { value }.to raise_error(Ehr::Settings::MissingSettingError)
          expect(Sentry).to have_received(:capture_message).with(expected_message).once
          expect(Rails.logger).to have_received(:error).with(expected_message)
        end
      end
    end
  end

  describe 'HL7 values that would break the message' do
    ['HFH ', ' HFH', '"HFH"', '""', 'HF|H', 'HF~H', "HFH\r", "HF\nH"].each do |value|
      context "when HL7_RECEIVING_FACILITY is #{value.inspect}" do
        include_context 'with environment variables', { 'HL7_RECEIVING_FACILITY' => value }

        it 'raises an error naming the setting, never the value' do
          expect { described_class.hl7_receiving_facility }.to raise_error(
            Ehr::Settings::InvalidSettingError, 'HL7_RECEIVING_FACILITY contains HL7 delimiters, quotes or surrounding whitespace'
          )
        end
      end
    end

    ['CIAS&2.16.840.1&ISO^AP^PDF^Base64', 'A\T\B', 'Example Health'].each do |value|
      context "when HL7_OBSERVATION_VALUE_PREFIX is #{value.inspect}" do
        include_context 'with environment variables', { 'HL7_OBSERVATION_VALUE_PREFIX' => value }

        it 'keeps it: components, subcomponents, escapes and inner spaces are valid HL7' do
          expect(described_class.hl7_observation_value_prefix).to eq(value)
        end
      end
    end
  end

  describe '.hl7_report_timezone' do
    subject(:zone) { described_class.hl7_report_timezone }

    ['Eastern Time (US & Canada)', 'America/Chicago'].each do |value|
      context "when HL7_REPORT_TIMEZONE is #{value.inspect}" do
        include_context 'with environment variables', { 'HL7_REPORT_TIMEZONE' => value }

        it { expect(zone).to eq(value) }
      end
    end

    [nil, ''].each do |blank|
      context "when HL7_REPORT_TIMEZONE is #{blank.inspect}" do
        include_context 'with environment variables', { 'HL7_REPORT_TIMEZONE' => blank }

        it { expect { zone }.to raise_error(Ehr::Settings::MissingSettingError, 'HL7_REPORT_TIMEZONE is not set') }
      end
    end

    context 'when HL7_REPORT_TIMEZONE is not a time zone' do
      include_context 'with environment variables', { 'HL7_REPORT_TIMEZONE' => 'Eastern' }

      it 'raises an error naming the setting, never its value' do
        expect { zone }.to raise_error(Ehr::Settings::InvalidSettingError, 'HL7_REPORT_TIMEZONE is not a known time zone')
      end
    end
  end

  describe '.ensure_hl7_values!' do
    before do
      allow(Sentry).to receive(:capture_message)
      allow(Rails.logger).to receive(:error)
    end

    context 'when every HL7 setting is set' do
      include_context 'with HL7 settings configured'

      it 'neither raises nor reports' do
        expect { described_class.ensure_hl7_values! }.not_to raise_error
        expect(Sentry).not_to have_received(:capture_message)
      end
    end

    context 'when some HL7 settings are blank' do
      include_context 'with HL7 settings configured'
      include_context 'with environment variables', { 'HL7_DOCUMENT_TYPE' => '', 'HL7_SENDING_FACILITY' => nil }

      let(:expected_message) do
        '[Ehr::Settings] HL7 send stopped, required settings are blank: HL7_SENDING_FACILITY, HL7_DOCUMENT_TYPE'
      end

      it 'reports the missing setting names to Sentry and the log, then raises' do
        expect { described_class.ensure_hl7_values! }
          .to raise_error(Ehr::Settings::MissingSettingError, expected_message)
        expect(Sentry).to have_received(:capture_message).with(expected_message).once
        expect(Rails.logger).to have_received(:error).with(expected_message)
      end
    end

    context 'when HL7_REPORT_TIMEZONE is not a time zone' do
      include_context 'with HL7 settings configured'
      include_context 'with environment variables', { 'HL7_REPORT_TIMEZONE' => 'Eastern' }

      let(:expected_message) { '[Ehr::Settings] HL7 send stopped, HL7_REPORT_TIMEZONE is not a known time zone' }

      it 'reports the setting name to Sentry and the log, never its value, then raises' do
        expect { described_class.ensure_hl7_values! }
          .to raise_error(Ehr::Settings::InvalidSettingError, expected_message)
        expect(Sentry).to have_received(:capture_message).with(expected_message).once
        expect(Rails.logger).to have_received(:error).with(expected_message)
      end
    end

    context 'when an HL7 setting would break the message' do
      include_context 'with HL7 settings configured'
      include_context 'with environment variables', { 'HL7_RECEIVING_FACILITY' => 'HFH|X' }

      let(:expected_message) do
        '[Ehr::Settings] HL7 send stopped, settings contain HL7 delimiters, quotes or surrounding whitespace: HL7_RECEIVING_FACILITY'
      end

      it 'reports the setting name to Sentry and the log, never its value, then raises' do
        expect { described_class.ensure_hl7_values! }
          .to raise_error(Ehr::Settings::InvalidSettingError, expected_message)
        expect(Sentry).to have_received(:capture_message).with(expected_message).once
        expect(Rails.logger).to have_received(:error).with(expected_message)
      end
    end
  end

  describe '.barcode_scan_enabled?' do
    ['1', ' 1 ', "1\n"].each do |value|
      context "when EHR_BARCODE_SCAN_FEATURE_ENABLED is #{value.inspect}" do
        include_context 'with environment variables', { 'EHR_BARCODE_SCAN_FEATURE_ENABLED' => value }

        it { expect(described_class.barcode_scan_enabled?).to be(true) }
      end
    end

    [nil, '', '0', 'true', 'yes', '2', '01', 'on'].each do |value|
      context "when EHR_BARCODE_SCAN_FEATURE_ENABLED is #{value.inspect}" do
        include_context 'with environment variables', { 'EHR_BARCODE_SCAN_FEATURE_ENABLED' => value }

        it { expect(described_class.barcode_scan_enabled?).to be(false) }
      end
    end
  end

  describe '.missing_barcode_scan_settings' do
    include_context 'with barcode settings configured'

    [nil, '', ' '].each do |blank|
      context "when both are #{blank.inspect}" do
        include_context 'with environment variables',
                        { 'EHR_BARCODE_PATIENT_ID_PATTERN' => blank, 'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => blank }

        it 'names both' do
          expect(described_class.missing_barcode_scan_settings)
            .to eq(%w[EHR_BARCODE_PATIENT_ID_PATTERN EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM])
        end
      end
    end
  end

  describe '.barcode_scan_available?' do
    subject(:available) { described_class.barcode_scan_available? }

    include_context 'with barcode settings configured'

    before do
      allow(Sentry).to receive(:capture_message)
      allow(Rails.logger).to receive(:error)
    end

    it 'is true with the flag on and the required settings set, and reports nothing' do
      expect(available).to be(true)
      expect(Sentry).not_to have_received(:capture_message)
    end

    [nil, '0', 'true'].each do |flag|
      context "when the flag is #{flag.inspect}" do
        include_context 'with environment variables', {
          'EHR_BARCODE_SCAN_FEATURE_ENABLED' => flag, 'EHR_BARCODE_PATIENT_ID_PATTERN' => nil
        }

        it 'is false and reports nothing, even with a required setting blank' do
          expect(available).to be(false)
          expect(Sentry).not_to have_received(:capture_message)
          expect(Rails.logger).not_to have_received(:error)
        end
      end
    end

    {
      'EHR_BARCODE_PATIENT_ID_PATTERN' => { 'EHR_BARCODE_PATIENT_ID_PATTERN' => '' },
      'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => { 'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => nil },
      'EHR_BARCODE_PATIENT_ID_PATTERN, EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => {
        'EHR_BARCODE_PATIENT_ID_PATTERN' => ' ', 'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => ''
      }
    }.each do |names, blanks|
      context "when the flag is on and #{names} is blank" do
        include_context 'with environment variables', blanks.merge('EHR_BARCODE_SCAN_FEATURE_ENABLED' => ' 1 ')

        let(:expected_message) { "[Ehr::Settings] code scanning is on but required settings are blank: #{names}" }

        it 'is false and reports the setting names to Sentry and the log' do
          expect(available).to be(false)
          expect(Sentry).to have_received(:capture_message).with(expected_message).once
          expect(Rails.logger).to have_received(:error).with(expected_message)
        end
      end
    end
  end

  # A stray space or line break would make every scan fail quietly (422), so it fails loudly instead.
  shared_examples 'a barcode setting with surrounding whitespace' do |setting, value|
    ["#{value} ", "#{value}\n", " #{value}"].each do |padded|
      context "when it is #{padded.inspect}" do
        include_context 'with environment variables', { setting => padded }

        it 'raises an error naming the setting, never its value' do
          expect { subject }.to raise_error(Ehr::Settings::InvalidSettingError, "#{setting} starts or ends with whitespace")
        end
      end
    end
  end

  describe '.barcode_patient_id_pattern' do
    subject(:pattern) { described_class.barcode_patient_id_pattern }

    context 'when set' do
      include_context 'with environment variables', { 'EHR_BARCODE_PATIENT_ID_PATTERN' => 'ID:(?<patient_id>\\d+)' }

      it 'compiles it with a timeout' do
        expect(pattern.match('ID:123')[:patient_id]).to eq('123')
        expect(pattern.timeout).to eq(described_class::BARCODE_REGEXP_TIMEOUT)
      end
    end

    [nil, '', ' '].each do |blank|
      context "when #{blank.inspect}" do
        include_context 'with environment variables', { 'EHR_BARCODE_PATIENT_ID_PATTERN' => blank }

        it 'raises an error naming the setting' do
          expect { pattern }.to raise_error(Ehr::Settings::MissingSettingError, 'EHR_BARCODE_PATIENT_ID_PATTERN is not set')
        end
      end
    end

    it_behaves_like 'a barcode setting with surrounding whitespace', 'EHR_BARCODE_PATIENT_ID_PATTERN',
                    '<PtID>(?<patient_id>.*?)</PtID>'

    context 'when it has no named group patient_id' do
      include_context 'with environment variables', { 'EHR_BARCODE_PATIENT_ID_PATTERN' => 'SECRET(?<id>\\d+)' }

      it 'raises an error naming the setting, never its value' do
        expect { pattern }.to raise_error(Ehr::Settings::InvalidSettingError, 'EHR_BARCODE_PATIENT_ID_PATTERN has no named group patient_id')
      end
    end

    context 'when it does not compile' do
      include_context 'with environment variables', { 'EHR_BARCODE_PATIENT_ID_PATTERN' => 'SECRET(?<patient_id>[' }

      it 'raises an error naming the setting, never its value, also not through the cause' do
        expect { pattern }.to raise_error(Ehr::Settings::InvalidSettingError) { |error|
          expect(error.message).to eq('EHR_BARCODE_PATIENT_ID_PATTERN is not a valid regular expression')
          expect(error.cause).to be_nil
        }
      end
    end
  end
end
