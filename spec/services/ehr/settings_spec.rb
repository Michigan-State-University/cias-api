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

  describe '.fetch' do
    subject(:value) { described_class.fetch('HL7_RECEIVER_URL', legacy: 'HFHS_URL') }

    context 'when only the new name is set' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => 'https://new.test', 'HFHS_URL' => nil }

      it { expect(value).to eq('https://new.test') }
    end

    context 'when only the old name is set' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => nil, 'HFHS_URL' => 'https://old.test' }

      it 'falls back to the old name' do
        expect(value).to eq('https://old.test')
      end
    end

    context 'when both names are set' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => 'https://new.test', 'HFHS_URL' => 'https://old.test' }

      it 'prefers the new name' do
        expect(value).to eq('https://new.test')
      end
    end

    ['', ' '].each do |blank|
      context "when the new name is #{blank.inspect} and the old name is set" do
        include_context 'with environment variables', { 'HL7_RECEIVER_URL' => blank, 'HFHS_URL' => 'https://old.test' }

        it 'treats the blank as absent and falls back to the old name' do
          expect(value).to eq('https://old.test')
        end
      end
    end

    context 'when both names are blank' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => '', 'HFHS_URL' => '' }

      it { expect(value).to be_nil }
    end

    context 'when neither name is defined' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => nil, 'HFHS_URL' => nil }

      it { expect(value).to be_nil }
    end
  end

  describe '.fetch!' do
    subject(:value) { described_class.fetch!('HL7_RECEIVER_URL', legacy: 'HFHS_URL') }

    before do
      allow(Sentry).to receive(:capture_message)
      allow(Rails.logger).to receive(:error)
    end

    context 'when only the old name is set' do
      include_context 'with environment variables', { 'HL7_RECEIVER_URL' => '', 'HFHS_URL' => 'https://old.test' }

      it 'returns it without reporting' do
        expect(value).to eq('https://old.test')
        expect(Sentry).not_to have_received(:capture_message)
      end
    end

    [nil, '', ' '].each do |blank|
      context "when both names are #{blank.inspect}" do
        include_context 'with environment variables', { 'HL7_RECEIVER_URL' => blank, 'HFHS_URL' => blank }

        let(:expected_message) { '[Ehr::Settings] HL7 send stopped, HL7_RECEIVER_URL (or HFHS_URL) is not set' }

        it 'raises naming both settings' do
          expect { value }.to raise_error(Ehr::Settings::MissingSettingError, 'HL7_RECEIVER_URL (or HFHS_URL) is not set')
        end

        it 'reports both setting names to Sentry and the log on the first attempt' do
          expect { value }.to raise_error(Ehr::Settings::MissingSettingError)
          expect(Sentry).to have_received(:capture_message).with(expected_message).once
          expect(Rails.logger).to have_received(:error).with(expected_message)
        end
      end
    end
  end

  describe '.hl7_processing_id' do
    subject(:processing_id) { described_class.hl7_processing_id }

    context 'when HL7_PROCESSING_ID is set' do
      include_context 'with environment variables', { 'HL7_PROCESSING_ID' => 'P', 'PROCESSING' => 'T' }

      it 'prefers it over the old name' do
        expect(processing_id).to eq('P')
      end
    end

    context 'when only the old PROCESSING is set' do
      include_context 'with environment variables', { 'HL7_PROCESSING_ID' => '', 'PROCESSING' => 'T' }

      it 'falls back to it' do
        expect(processing_id).to eq('T')
      end
    end

    [['', ''], [nil, nil], ['', nil]].each do |new_value, old_value|
      context "when HL7_PROCESSING_ID is #{new_value.inspect} and PROCESSING is #{old_value.inspect}" do
        include_context 'with environment variables', { 'HL7_PROCESSING_ID' => new_value, 'PROCESSING' => old_value }

        it 'raises an error naming both settings instead of sending an empty MSH-11' do
          expect { processing_id }.to raise_error(Ehr::Settings::MissingSettingError, 'HL7_PROCESSING_ID (or PROCESSING) is not set')
        end
      end
    end

    context 'when the old PROCESSING would break the message' do
      include_context 'with environment variables', { 'HL7_PROCESSING_ID' => nil, 'PROCESSING' => 'P|' }

      it 'raises an error naming the settings, never the value' do
        expect { processing_id }.to raise_error(
          Ehr::Settings::InvalidSettingError, 'HL7_PROCESSING_ID (or PROCESSING) contains HL7 delimiters, quotes or surrounding whitespace'
        )
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

    context 'when HL7_PROCESSING_ID and the old PROCESSING are both blank' do
      include_context 'with HL7 settings configured'
      include_context 'with environment variables', { 'HL7_PROCESSING_ID' => '', 'PROCESSING' => '' }

      let(:expected_message) do
        '[Ehr::Settings] HL7 send stopped, required settings are blank: HL7_PROCESSING_ID (or PROCESSING)'
      end

      it 'reports both setting names to Sentry and the log, then raises' do
        expect { described_class.ensure_hl7_values! }
          .to raise_error(Ehr::Settings::MissingSettingError, expected_message)
        expect(Sentry).to have_received(:capture_message).with(expected_message).once
        expect(Rails.logger).to have_received(:error).with(expected_message)
      end
    end

    context 'when only the old PROCESSING is set' do
      include_context 'with HL7 settings configured'
      include_context 'with environment variables', { 'HL7_PROCESSING_ID' => '', 'PROCESSING' => 'P' }

      it 'accepts it: neither raises nor reports' do
        expect { described_class.ensure_hl7_values! }.not_to raise_error
        expect(Sentry).not_to have_received(:capture_message)
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
