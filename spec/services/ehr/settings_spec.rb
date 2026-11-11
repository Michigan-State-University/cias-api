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
end
